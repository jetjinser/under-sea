#!/usr/bin/env python3
"""Drive a local Chromium page over CDP using the browser-use runtime."""
import asyncio
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

import browser_use  # noqa: F401
import websockets


async def command(socket, serial, method, params=None, session_id=None):
    message = {"id": serial, "method": method, "params": params or {}}
    if session_id:
        message["sessionId"] = session_id
    await socket.send(json.dumps(message))
    while True:
        response = json.loads(await socket.recv())
        if response.get("id") == serial:
            if "error" in response:
                raise RuntimeError(f"CDP {method} failed: {response['error']}")
            return response.get("result", {})


async def smoke(chrome, directory):
    profile = Path(directory) / "chrome-profile"
    profile.mkdir()
    process = subprocess.Popen(
        [chrome, "--headless=new", "--no-sandbox", "--disable-gpu",
         "--disable-dev-shm-usage", "--remote-debugging-port=0",
         f"--user-data-dir={profile}", "about:blank"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        endpoint = None
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline and process.poll() is None:
            active_port = profile / "DevToolsActivePort"
            if active_port.exists():
                lines = active_port.read_text().splitlines()
                if lines:
                    try:
                        with urllib.request.urlopen(
                                f"http://127.0.0.1:{lines[0]}/json/version",
                                timeout=0.2) as response:
                            endpoint = json.load(response)["webSocketDebuggerUrl"]
                        break
                    except (OSError, KeyError, ValueError):
                        pass
            time.sleep(0.1)
        if not endpoint:
            raise RuntimeError("Chromium did not expose a CDP endpoint")

        async with websockets.connect(endpoint, open_timeout=5) as socket:
            serial = 0

            async def send(method, params=None, session_id=None):
                nonlocal serial
                serial += 1
                return await asyncio.wait_for(
                    command(socket, serial, method, params, session_id),
                    timeout=5)

            target = await send("Target.createTarget", {"url": "about:blank"})
            attached = await send(
                "Target.attachToTarget",
                {"targetId": target["targetId"], "flatten": True})
            session = attached["sessionId"]
            await send("Page.enable", session_id=session)
            await send("Page.navigate", {
                "url": "data:text/html," + urllib.parse.quote(
                    "<title>browser-use-cdp-smoke</title>")
            }, session)
            deadline = time.monotonic() + 10
            title = ""
            while time.monotonic() < deadline:
                result = await send("Runtime.evaluate", {
                    "expression": "document.title",
                    "returnByValue": True,
                }, session)
                title = result.get("result", {}).get("value", "")
                if title == "browser-use-cdp-smoke":
                    break
                await asyncio.sleep(0.1)
            if title != "browser-use-cdp-smoke":
                raise RuntimeError(f"unexpected page title: {title!r}")
            await send("Target.closeTarget", {"targetId": target["targetId"]})
            print(f"CDP smoke passed: {title}")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    asyncio.run(smoke(os.environ["CHROME_PATH"], tempfile.gettempdir()))

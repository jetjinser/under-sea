#!/usr/bin/env python3
"""Mock OpenAI-compatible model server for offline Hermes E2E tests.

Serves POST /v1/chat/completions on 127.0.0.1:30000 with a scripted
two-turn flow:

  turn 1: a tool_call asking Hermes to run `touch /tmp/hermes-e2e-marker`
  turn 2+: the final assistant text acknowledging the tool result

Stdlib only; runs under the hermes-python runtime in the test VM.
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

MARKER = "/tmp/hermes-e2e-marker"
state = {"requests": 0}


def completion_for(n):
    if n == 1:
        message = {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call-e2e-1",
                    "type": "function",
                    "function": {
                        "name": "terminal",
                        "arguments": '{"command": "touch %s"}' % MARKER,
                    },
                }
            ],
        }
        finish = "tool_calls"
    else:
        message = {
            "role": "assistant",
            "content": "E2E OK: the marker file was created by the terminal tool.",
        }
        finish = "stop"
    return {
        "id": "chatcmpl-e2e-%d" % n,
        "object": "chat.completion",
        "model": "mock-model",
        "choices": [{"index": 0, "message": message, "finish_reason": finish}],
        "usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20},
    }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if not self.path.startswith("/v1/chat/completions"):
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        state["requests"] += 1
        body = json.dumps(completion_for(state["requests"])).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/v1/models"):
            body = json.dumps(
                {"object": "list", "data": [{"id": "mock-model", "object": "model"}]}
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        pass  # keep the VM console quiet


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 30000), Handler).serve_forever()

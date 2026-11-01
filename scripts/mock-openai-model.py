#!/usr/bin/env python3
"""Mock OpenAI-compatible model server for offline Hermes E2E tests.

Serves POST /v1/chat/completions on 127.0.0.1:30000 with a scripted
two-turn flow:

  turn 1: a tool_call asking Hermes to run `touch /tmp/hermes-e2e-marker`
  turn 2+: the final assistant text acknowledging the tool result

Stdlib only; runs under the hermes-python runtime in the test VM.
"""
import json
import time
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
        request = json.loads(self.rfile.read(length) or b"{}")
        state["requests"] += 1
        response = completion_for(state["requests"])
        if request.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            message = response["choices"][0]["message"]
            events = [{"delta": {"role": "assistant"}, "finish_reason": None}]
            if message.get("tool_calls"):
                tool_call = message["tool_calls"][0]
                events.extend([
                    {"delta": {"tool_calls": [{
                        "index": 0, "id": tool_call["id"], "type": "function",
                        "function": {"name": tool_call["function"]["name"],
                                     "arguments": ""},
                    }]}, "finish_reason": None},
                    {"delta": {"tool_calls": [{
                        "index": 0,
                        "function": {"arguments": tool_call["function"]["arguments"]},
                    }]}, "finish_reason": None},
                ])
            elif message.get("content"):
                events.append({"delta": {"content": message["content"]},
                               "finish_reason": None})
            events.append({"delta": {}, "finish_reason": response["choices"][0]["finish_reason"]})
            for event in events:
                chunk = {
                    "id": response["id"], "object": "chat.completion.chunk",
                    "created": int(time.time()), "model": response["model"],
                    "choices": [{"index": 0, **event}],
                }
                self.wfile.write(("data: " + json.dumps(chunk) + "\n\n").encode())
                self.wfile.flush()
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
            return
        body = json.dumps(response).encode("utf-8")
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

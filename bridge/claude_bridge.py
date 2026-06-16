"""
Local bridge for the AI-Player mod <-> Anthropic.

The mod speaks the OpenAI-compatible dialect but does a connectivity check via
GET /models with Bearer auth, which Anthropic rejects. This bridge:
  - GET  /v1/models           -> returns a static OpenAI-style list of Claude models
  - POST /v1/chat/completions -> forwards to Anthropic's OpenAI-compatible endpoint
                                 (swapping in the real key), returns the response as-is
  - POST /v1/embeddings       -> routes to local Ollama (nomic-embed-text)

Listens on 127.0.0.1 only. The real Anthropic key lives in anthropic.key beside
this file (same folder the mod already stores it in).
"""
import json, os, sys, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ANTHROPIC_CHAT = "https://api.anthropic.com/v1/chat/completions"
OLLAMA_EMBED   = "http://127.0.0.1:11434/api/embed"
EMBED_MODEL    = "nomic-embed-text"

MODELS = [
    "claude-sonnet-4-6", "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6",
    "claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001",
    "claude-opus-4-5-20251101", "claude-opus-4-1-20250805", "claude-fable-5",
]

def read_key():
    with open(os.path.join(HERE, "anthropic.key"), "r", encoding="utf-8") as f:
        return f.read().strip()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # silence console spam
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _raw(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.rstrip("/").endswith("/models"):
            self._json(200, {"object": "list",
                             "data": [{"id": m, "object": "model", "owned_by": "anthropic"} for m in MODELS]})
        else:
            self._json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        if self.path.endswith("/chat/completions"):
            self._forward_chat(raw)
        elif self.path.endswith("/embeddings"):
            self._embeddings(raw)
        else:
            self._json(404, {"error": {"message": "not found"}})

    def _forward_chat(self, raw):
        try:
            # Repair the payload: the mod sometimes sends an empty/invalid model in
            # custom mode, and Anthropic requires max_tokens. Patch both if needed.
            try:
                body = json.loads(raw or b"{}")
            except Exception:
                body = {}
            m = body.get("model")
            if not isinstance(m, str) or not m.strip():
                body["model"] = "claude-sonnet-4-6"
            mt = body.get("max_tokens")
            if not isinstance(mt, int) or mt <= 0:
                body["max_tokens"] = 4096
            raw = json.dumps(body).encode("utf-8")

            req = urllib.request.Request(ANTHROPIC_CHAT, data=raw, method="POST")
            req.add_header("Content-Type", "application/json")
            req.add_header("Authorization", "Bearer " + read_key())
            with urllib.request.urlopen(req, timeout=180) as r:
                self._raw(r.getcode(), r.read())
        except urllib.error.HTTPError as e:
            self._raw(e.code, e.read())
        except Exception as e:
            self._json(502, {"error": {"message": "bridge->anthropic failed: " + str(e)}})

    def _embeddings(self, raw):
        try:
            try:
                body = json.loads(raw or b"{}")
            except Exception:
                body = {}
            inp = body.get("input", "")
            inputs = inp if isinstance(inp, list) else [inp]
            out = []
            for i, text in enumerate(inputs):
                oreq = urllib.request.Request(
                    OLLAMA_EMBED,
                    data=json.dumps({"model": EMBED_MODEL, "input": text}).encode("utf-8"),
                    method="POST")
                oreq.add_header("Content-Type", "application/json")
                with urllib.request.urlopen(oreq, timeout=60) as r:
                    od = json.loads(r.read())
                emb = (od.get("embeddings") or [od.get("embedding")])[0]
                out.append({"object": "embedding", "embedding": emb, "index": i})
            self._json(200, {"object": "list", "data": out, "model": EMBED_MODEL,
                             "usage": {"prompt_tokens": 0, "total_tokens": 0}})
        except Exception as e:
            self._json(502, {"error": {"message": "bridge->ollama failed: " + str(e)}})

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8788
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()

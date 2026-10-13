"""Development REST API for bilingual search and citation-grounded Gemini answers."""
from __future__ import annotations

import json
import os
import secrets
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

from .gemini import GeminiError, generate_grounded_answer
from .search import SearchIndex
from .semantic import rerank_semantically

MAX_REQUEST_BYTES = 64 * 1024


_URDU_HINTS = set("پچژگٹڈڑںہےھک")


def _has_arabic_script(question: str) -> bool:
    return any("\u0600" <= char <= "\u06ff" for char in question)


def _no_match_message(question: str) -> str:
    if any(char in _URDU_HINTS for char in question):
        return "مقامی ڈیٹا بیس میں اس سوال کے لیے متعلقہ روایت نہیں ملی۔ براہِ کرم سوال کو دوسرے الفاظ یا مختصر کلیدی لفظ کے ساتھ آزمائیں۔"
    if _has_arabic_script(question):
        return "لم أعثر على سجلٍّ مطابق في قواعد البيانات المرفقة. جرّب صياغة أخرى أو كلمة مفتاحية أقصر."
    return "I could not find a matching record in the supplied local databases. Please try another wording or a shorter keyword."


class ShiaAIService:
    def __init__(self, search_index: SearchIndex | None = None) -> None:
        self.search_index = search_index or SearchIndex()

    def search(self, query: str, limit: int = 8) -> list[dict]:
        passages = self.search_index.search(query, limit=limit)
        return [passage.as_dict() for passage in passages]

    def chat(
        self,
        question: str,
        history=None,
        limit: int = 8,
        session_id: str | None = None,
        reader_context: str | None = None,
        reader_target: dict | None = None,
    ) -> dict:
        question = question.strip()
        session_id = session_id or str(uuid.uuid4())
        result_limit = max(1, min(int(limit), 8))
        candidate_limit = min(30, max(result_limit * 3, 20))
        candidates = self.search_index.search(question, limit=candidate_limit)
        active_passage = None
        if isinstance(reader_target, dict):
            target_book = reader_target.get("book")
            target_record = reader_target.get("record_id")
            if isinstance(target_book, str) and isinstance(target_record, (str, int)):
                active_passage = self.search_index.get_passage(target_book, target_record)
                if active_passage is not None and all(
                    passage.source_id != active_passage.source_id for passage in candidates
                ):
                    candidates.insert(0, active_passage)
        if not candidates:
            return {
                "session_id": session_id,
                "answer": _no_match_message(question),
                "sources": [],
                "grounded": False,
                "retrieval_mode": "normalized_fts5",
            }

        retrieval_mode = "normalized_fts5"
        if os.environ.get("GEMINI_API_KEY", "").strip() and len(candidates) > 1:
            try:
                candidates = rerank_semantically(question, candidates)
                retrieval_mode = "hybrid_gemini_embedding"
            except (GeminiError, ValueError):
                # If the embeddings model is temporarily unavailable, retain
                # deterministic local FTS ordering and still generate grounded.
                pass
        passages = candidates[:result_limit]
        if active_passage is not None:
            passages = [active_passage] + [
                passage for passage in passages if passage.source_id != active_passage.source_id
            ]
            passages = passages[:result_limit]
        sources = []
        for index, passage in enumerate(passages, start=1):
            source = passage.as_dict()
            source["marker"] = f"[R{index}]"
            sources.append(source)

        answer = generate_grounded_answer(
            question,
            passages,
            history=history,
            reader_context=reader_context,
        )
        return {
            "session_id": session_id,
            "answer": answer,
            "sources": sources,
            "grounded": True,
            "retrieval_mode": retrieval_mode,
        }


class _ReusableThreadingHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class ShiaAIRequestHandler(BaseHTTPRequestHandler):
    service: ShiaAIService
    api_token: str | None = None
    cors_origins: set[str] = set()

    def _send_json(self, status: int, payload: dict) -> None:
        body = b"" if status == 204 else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        if status != 204:
            self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        origin = self.headers.get("Origin")
        if origin and ("*" in self.cors_origins or origin in self.cors_origins):
            self.send_header("Access-Control-Allow-Origin", "*" if "*" in self.cors_origins else origin)
            self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._send_json(204, {})

    def do_GET(self) -> None:  # noqa: N802
        route = urlparse(self.path).path
        if route == "/health":
            self._send_json(200, {"status": "ok", "service": "shia-ai"})
        else:
            self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        route = urlparse(self.path).path
        if route not in {"/api/search", "/api/chat"}:
            self._send_json(404, {"error": "not_found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._send_json(400, {"error": "invalid_content_length"})
            return
        if length <= 0 or length > MAX_REQUEST_BYTES:
            self._send_json(413 if length > MAX_REQUEST_BYTES else 400, {"error": "invalid_request_size"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._send_json(400, {"error": "invalid_json"})
            return
        if not isinstance(payload, dict):
            self._send_json(400, {"error": "invalid_request"})
            return

        if route == "/api/search":
            query = payload.get("query")
            if not isinstance(query, str) or not query.strip():
                self._send_json(400, {"error": "query_required"})
                return
            try:
                matches = self.service.search(query, limit=payload.get("limit", 8))
            except (TypeError, ValueError):
                self._send_json(400, {"error": "invalid_limit"})
                return
            self._send_json(200, {"query": query, "matches": matches})
            return

        if self.api_token:
            provided = self.headers.get("Authorization", "")
            expected = f"Bearer {self.api_token}"
            if not secrets.compare_digest(provided, expected):
                self._send_json(401, {"error": "unauthorized"})
                return
        question = payload.get("question")
        if not isinstance(question, str) or not question.strip():
            self._send_json(400, {"error": "question_required"})
            return
        history = payload.get("history", [])
        if not isinstance(history, list):
            self._send_json(400, {"error": "history_must_be_a_list"})
            return
        reader_context = payload.get("reader_context", "")
        if not isinstance(reader_context, str):
            self._send_json(400, {"error": "reader_context_must_be_a_string"})
            return
        reader_target = payload.get("reader_target")
        if reader_target is not None and not isinstance(reader_target, dict):
            self._send_json(400, {"error": "reader_target_must_be_an_object"})
            return
        try:
            response = self.service.chat(
                question,
                history=history,
                limit=payload.get("limit", 8),
                session_id=payload.get("session_id"),
                reader_context=reader_context[:8000] or None,
                reader_target=reader_target,
            )
        except (TypeError, ValueError):
            self._send_json(400, {"error": "invalid_limit"})
            return
        except GeminiError as exc:
            self._send_json(503, {"error": "gemini_unavailable", "message": str(exc)})
            return
        self._send_json(200, response)

    def log_message(self, fmt: str, *args) -> None:
        # Do not log request bodies, prompts, or API credentials.
        super().log_message(fmt, *args)


def create_server(host: str | None = None, port: int | None = None) -> _ReusableThreadingHTTPServer:
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    api_token = os.environ.get("SHIA_API_TOKEN", "").strip() or None
    if api_key and not api_token:
        raise RuntimeError(
            "Set SHIA_API_TOKEN when GEMINI_API_KEY is configured, so the development "
            "server cannot be used anonymously to spend your Gemini quota."
        )
    cors = {
        origin.strip()
        for origin in os.environ.get("SHIA_CORS_ORIGINS", "").split(",")
        if origin.strip()
    }
    handler = type(
        "ConfiguredShiaAIRequestHandler",
        (ShiaAIRequestHandler,),
        {
            "service": ShiaAIService(),
            "api_token": api_token,
            "cors_origins": cors,
        },
    )
    server_host = host if host is not None else os.environ.get("HOST", "0.0.0.0")
    server_port = port if port is not None else int(os.environ.get("PORT", "8000"))
    return _ReusableThreadingHTTPServer((server_host, server_port), handler)


def main() -> None:
    server = create_server()
    print(f"Shia AI API listening on http://{server.server_address[0]}:{server.server_address[1]}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        service = getattr(server.RequestHandlerClass, "service", None)
        if service:
            service.search_index.close()
        server.server_close()


if __name__ == "__main__":
    main()

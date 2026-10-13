from __future__ import annotations

import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from shia_ai.api import ShiaAIRequestHandler, ShiaAIService, _no_match_message
from shia_ai.search import Passage


class _StubService:
    def search(self, query: str, limit: int = 8):
        return [{"book": "alkafi", "paragraph_id": 9001, "query": query, "limit": limit}]

    def chat(self, question: str, history=None, limit: int = 8, session_id=None, reader_context=None, reader_target=None):
        return {
            "answer": f"Grounded answer [R1] for {question}",
            "session_id": session_id or "test-session",
            "sources": [{"marker": "[R1]", "book": "alkafi", "paragraph_id": 9001}],
            "grounded": True,
        }


class _ReaderTargetIndex:
    def __init__(self, passage: Passage):
        self.passage = passage

    def search(self, query: str, limit: int = 8):
        return []

    def get_passage(self, book: str, paragraph_id: int | str):
        if book == self.passage.book and str(paragraph_id) == str(self.passage.paragraph_id):
            return self.passage
        return None


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        handler = type(
            "TestShiaAIHandler",
            (ShiaAIRequestHandler,),
            {
                "service": _StubService(),
                "api_token": "test-token",
                "cors_origins": {"https://client.example"},
            },
        )
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def _post(self, path: str, payload: dict, *, token: str | None = None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = Request(
            self.base_url + path,
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        return urlopen(request, timeout=5)

    def test_health_endpoint(self) -> None:
        with urlopen(self.base_url + "/health", timeout=5) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(json.loads(response.read()), {"status": "ok", "service": "shia-ai"})

    def test_no_match_message_uses_question_language(self) -> None:
        self.assertIn("ڈیٹا بیس", _no_match_message("روایت کہاں ہے؟"))
        self.assertIn("قواعد البيانات", _no_match_message("أين الرواية؟"))
        self.assertIn("local databases", _no_match_message("where is the narration?"))

    def test_chat_uses_the_exact_active_reader_record_as_grounded_context(self) -> None:
        passage = Passage(
            source_id="alkafi:9001",
            database="alkafi.db",
            book="alkafi",
            paragraph_id=9001,
            section_id=7,
            page_no=12,
            chapter_title="باب فضائل العلم",
            section_title="ذكر أمير المؤمنين",
            arabic="قال الإمام",
            urdu="امام نے فرمایا",
            relevance=0.0,
        )
        service = ShiaAIService(search_index=_ReaderTargetIndex(passage))
        with patch("shia_ai.api.generate_grounded_answer", return_value="یہ روایت [R1] ہے۔") as generate:
            response = service.chat(
                "اس روایت کی وضاحت کریں",
                reader_context="کتاب الکافی، حدیث 9001",
                reader_target={"book": "alkafi", "record_id": 9001},
            )
        self.assertEqual(response["sources"][0]["reader_target"]["record_id"], 9001)
        self.assertEqual(response["sources"][0]["marker"], "[R1]")
        self.assertEqual(generate.call_args.kwargs["reader_context"], "کتاب الکافی، حدیث 9001")

    def test_search_endpoint_returns_citable_locator(self) -> None:
        with self._post("/api/search", {"query": "امیرالمومنین", "limit": 4}) as response:
            body = json.loads(response.read())
        self.assertEqual(body["matches"][0]["paragraph_id"], 9001)
        self.assertEqual(body["matches"][0]["limit"], 4)

    def test_chat_endpoint_requires_token_and_returns_sources(self) -> None:
        with self.assertRaises(HTTPError) as raised:
            self._post("/api/chat", {"question": "سوال"})
        self.assertEqual(raised.exception.code, 401)
        with self._post(
            "/api/chat",
            {
                "question": "سوال",
                "history": [],
                "session_id": "abc",
                "reader_context": "الکافی، باب فضائل",
                "reader_target": {"book": "alkafi", "record_id": 9001},
            },
            token="test-token",
        ) as response:
            body = json.loads(response.read())
        self.assertTrue(body["grounded"])
        self.assertEqual(body["sources"][0]["marker"], "[R1]")
        self.assertEqual(body["session_id"], "abc")

    def test_cors_is_allowlisted(self) -> None:
        request = Request(
            self.base_url + "/health",
            headers={"Origin": "https://client.example"},
        )
        with urlopen(request, timeout=5) as response:
            self.assertEqual(response.headers.get("Access-Control-Allow-Origin"), "https://client.example")


if __name__ == "__main__":
    unittest.main()

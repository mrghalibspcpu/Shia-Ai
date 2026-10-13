from __future__ import annotations

import unittest

from shia_ai.search import Passage
from shia_ai.semantic import rerank_semantically


class SemanticRerankingTests(unittest.TestCase):
    @staticmethod
    def _passage(source_id: str, text: str, score: float) -> Passage:
        return Passage(
            source_id=source_id,
            database="alkafi.db",
            book="alkafi",
            paragraph_id=source_id.split(":")[1],
            section_id=7,
            page_no=12,
            chapter_title="باب test",
            section_title="فصل test",
            arabic=text,
            urdu=text,
            relevance=score,
        )

    def test_embeddings_can_rerank_without_changing_record_locators(self) -> None:
        strong_semantic = self._passage("alkafi:1", "unique semantic fixture alpha", 1.0)
        strong_lexical = self._passage("alkafi:2", "unique semantic fixture beta", 9.0)

        def fake_embedder(texts: list[str]) -> list[list[float]]:
            self.assertEqual(len(texts), 3)
            return [[1.0, 0.0], [0.0, 1.0], [1.0, 0.0]]

        results = rerank_semantically(
            "semantic fixture query", [strong_lexical, strong_semantic], embedder=fake_embedder
        )
        self.assertEqual(results[0].source_id, "alkafi:1")
        self.assertEqual(results[0].paragraph_id, "1")
        self.assertEqual(results[1].source_id, "alkafi:2")

    def test_mismatched_embedding_count_fails_closed(self) -> None:
        passage = self._passage("alkafi:3", "another unique fixture gamma", 1.0)
        with self.assertRaises(ValueError):
            rerank_semantically("gamma", [passage, passage], embedder=lambda texts: [[1.0, 0.0]])


if __name__ == "__main__":
    unittest.main()

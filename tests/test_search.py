from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from shia_ai.search import SearchIndex, normalize_text


class SearchIndexTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.database_dir = self.root / "databases"
        self.database_dir.mkdir()
        self.index_path = self.root / "cache" / "index.sqlite3"
        self._create_database(self.database_dir / "alkafi.db")
        self.index = SearchIndex(self.database_dir, self.index_path)

    def tearDown(self) -> None:
        self.index.close()
        self.temp.cleanup()

    @staticmethod
    def _create_database(path: Path) -> None:
        with sqlite3.connect(path) as connection:
            connection.executescript(
                """
                CREATE TABLE Chaps (
                    ID INTEGER,
                    cid INTEGER,
                    title TEXT,
                    bookid INTEGER
                );
                CREATE TABLE Sections (
                    ID INTEGER,
                    title TEXT,
                    Chapid INTEGER,
                    Secid INTEGER
                );
                CREATE TABLE Parags (
                    ID INTEGER,
                    txt TEXT,
                    Secid INTEGER,
                    paganum INTEGER,
                    mean TEXT,
                    is_fav INTEGER,
                    fav_time TEXT
                );
                INSERT INTO Chaps VALUES (10, 2, 'باب فضائل العلم', 1);
                INSERT INTO Sections VALUES (20, 'ذكر أمير المؤمنين', 2, 7);
                INSERT INTO Parags VALUES (
                    9001,
                    'قَالَ الشَّيْخُ عَلِيٌّ عَلَيْهِ السَّلَامُ',
                    7,
                    12,
                    'حضرت امیرالمومنین علیہ السلام نے فرمایا',
                    0,
                    NULL
                );
                """
            )

    def test_normalizes_common_arabic_and_persian_variants(self) -> None:
        self.assertEqual(normalize_text("آلِ كَافِيٌّ"), "ال کافی")
        self.assertEqual(normalize_text("قَالَ الشَّيْخُ عَلِيٌّ"), "قال الشیخ علی")

    def test_exact_reader_lookup_preserves_database_record_identity(self) -> None:
        passage = self.index.get_passage("ALKAFI", 9001)
        self.assertIsNotNone(passage)
        self.assertEqual(passage.book, "alkafi")
        self.assertEqual(passage.paragraph_id, 9001)
        self.assertEqual(passage.section_id, 7)
        self.assertIsNone(self.index.get_passage("unknown", 9001))

    def test_arabic_query_matches_diacritic_database_text(self) -> None:
        results = self.index.search("الشيخ علي", limit=5)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].paragraph_id, 9001)
        self.assertEqual(results[0].arabic, "قَالَ الشَّيْخُ عَلِيٌّ عَلَيْهِ السَّلَامُ")

    def test_urdu_query_matches_and_returns_reader_locator(self) -> None:
        results = self.index.search("امیرالمومنین علیہ السلام", limit=5)
        self.assertEqual(len(results), 1)
        passage = results[0]
        self.assertEqual(passage.book, "alkafi")
        self.assertEqual(passage.section_id, 7)
        self.assertEqual(passage.page_no, 12)
        self.assertEqual(passage.reader_target["record_id"], 9001)
        self.assertIn("record_id=9001", passage.check_url)
        self.assertIn("alkafi.db", passage.citation)
        self.assertTrue(passage.urdu.startswith("حضرت امیرالمومنین"))

    def test_empty_or_punctuation_only_query_has_no_matches(self) -> None:
        self.assertEqual(self.index.search("   ؟؛،  "), [])

    def test_cache_is_reusable(self) -> None:
        self.index.close()
        rebuilt = SearchIndex(self.database_dir, self.index_path)
        try:
            self.assertEqual(len(rebuilt.search("الشيخ علي")), 1)
        finally:
            rebuilt.close()


if __name__ == "__main__":
    unittest.main()

"""The Nahj al-Balagha notes must stay attached the way the reader can vouch for.

`balaghatext_hawashi.ParaNo` is the note's place in the entry's footnote
sequence, **not** the paragraph it annotates: sermon 1 stores 74 notes numbered
1–75 above 30 paragraphs, and sermon 3 stores 151 notes numbered 1–152 above 20
paragraphs. Pairing a note with the paragraph of the same number is what made
the commentary read as if it belonged to another passage («متن کچھ، حاشیہ
کچھ»). Since 1.24 the reader

* shows every note after the matn, numbered the way the book numbers it,
* keeps a note under a paragraph only when the matn still carries its printed
  marker («الْوَالِدِ الْفَانِ٢»), and
* never groups notes by `ParaNo` again.
"""
from __future__ import annotations

import re
import sqlite3
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from prepare_databases import collect_databases  # noqa: E402

REPOSITORY = ROOT / "app" / "lib" / "library_repository.dart"


def _notes_database() -> Path:
    """The staged copy is deleted when the collector closes, so read inside it."""
    with collect_databases(include_bundle=False) as collected:
        for spec, path in collected:
            if spec.key == "nahjul_balagha":
                return Path(path)
    raise AssertionError("nahjul_balagha is missing from the corpus")


class NoteNumberingTests(unittest.TestCase):
    """The data proves why a number cannot be read as a paragraph id."""

    def setUp(self):
        self._collected = collect_databases(include_bundle=False)
        collected = self._collected.__enter__()
        path = next(path for spec, path in collected if spec.key == "nahjul_balagha")
        self.connection = sqlite3.connect(path)
        self.connection.row_factory = sqlite3.Row

    def tearDown(self):
        self.connection.close()
        self._collected.__exit__(None, None, None)

    def test_note_numbers_run_past_the_paragraph_count(self):
        """A number shared by two different things cannot pair them."""
        entries = self.connection.execute(
            "SELECT DISTINCT Type, TypeNo FROM balaghatext_hawashi WHERE Type < 5"
        ).fetchall()
        past = 0
        for type_, type_no in entries:
            notes = [
                row[0]
                for row in self.connection.execute(
                    "SELECT ParaNo FROM balaghatext_hawashi "
                    "WHERE Type = ? AND TypeNo = ? ORDER BY ID",
                    (type_, type_no),
                )
            ]
            paragraphs = self.connection.execute(
                "SELECT COUNT(*) FROM balaghatext WHERE Type = ? AND TypeNo = ?",
                (type_, type_no),
            ).fetchone()[0]
            if any(note is not None for note in notes) and max(
                note for note in notes if note is not None
            ) > paragraphs:
                past += 1
        self.assertGreater(past, 10, "many entries number their notes past their paragraphs")

    def test_sermon_three_is_the_case_that_was_wrong(self):
        notes = [
            row[0]
            for row in self.connection.execute(
                "SELECT ParaNo FROM balaghatext_hawashi "
                "WHERE Type = 1 AND TypeNo = 3 ORDER BY ID"
            )
        ]
        paragraphs = self.connection.execute(
            "SELECT COUNT(*) FROM balaghatext WHERE Type = 1 AND TypeNo = 3"
        ).fetchone()[0]
        self.assertEqual(paragraphs, 20)
        self.assertEqual(len(notes), 151)
        self.assertEqual(notes, sorted(notes))
        self.assertEqual(max(notes), 152)
        self.assertNotEqual(len(notes), paragraphs)

    def test_blank_notes_are_rare_and_skipped_by_the_reader(self):
        total = self.connection.execute("SELECT COUNT(*) FROM balaghatext_hawashi").fetchone()[0]
        blank = self.connection.execute(
            "SELECT COUNT(*) FROM balaghatext_hawashi WHERE trim(coalesce(hawashi, '')) = ''"
        ).fetchone()[0]
        self.assertLess(blank, total // 100)
        source = REPOSITORY.read_text(encoding="utf-8")
        self.assertIn("if (body.isEmpty) continue;", source)


class ReaderWiringTests(unittest.TestCase):
    """The Dart reader must not pair a note with the paragraph of the same number."""

    @classmethod
    def setUpClass(cls):
        cls.source = REPOSITORY.read_text(encoding="utf-8")

    def test_notes_are_grouped_by_paragraph_no_longer(self):
        self.assertNotIn(
            "_footnotesByParagraph",
            self.source,
            "grouping notes by ParaNo attaches each note to the wrong paragraph",
        )
        self.assertNotIn(
            "footnotes[passage.page]",
            self.source,
            "a note number is not a paragraph id",
        )

    def test_the_entry_ends_with_numbered_notes(self):
        self.assertIn("حواشی — ${notes.length} حاشیے", self.source)
        self.assertIn("locator: 'حاشیہ ${index + 1}'", self.source)

    def test_only_a_printed_marker_keeps_a_note_under_its_paragraph(self):
        self.assertIn("_markerNumbers(", self.source)
        marker = re.search(r"RegExp\(r'\[(.+?)\]\[(.+?)\]", self.source)
        self.assertIsNotNone(marker)
        self.assertIn("u0660", self.source, "Arabic-Indic digits carry the marker")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()

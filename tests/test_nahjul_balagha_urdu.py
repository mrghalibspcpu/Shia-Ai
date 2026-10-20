"""The Nahj al-Balagha Urdu repair: every damaged form is covered.

``assets/nahjul_balagha.db`` ships with a damaged Urdu column — sermons 4-10
were stored with each word's letters shuffled, and many single words elsewhere
are stored reversed ("ںیم" for "میں", "ےک" for "کے"). The database is
SHA-256-verified against the manifest and served from a release, so the repair
lives in the app (``app/lib/nahjul_balagha_urdu.dart``) and is applied when text
is read.

These tests read the Dart tables directly and replay them over the checked-in
database, so a future database refresh that reintroduces a known bad form — or a
new paragraph lost past repair — fails here instead of in a reader's hands.
"""
from __future__ import annotations

import re
import sqlite3
from pathlib import Path
from unittest import TestCase

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / "app" / "lib" / "nahjul_balagha_urdu.dart"
DATABASE = ROOT / "assets" / "nahjul_balagha.db"

#: Arabic-script letters and vowel marks only — the Arabic punctuation (، ؛ ؟ ۔)
#: lives inside the same Unicode block and must not be glued to a word.
WORD = re.compile(
    "[\u0621-\u063A\u0640-\u065F\u0670\u0671-\u06D3\u06D5"
    "\u06FA-\u06FF\u0750-\u077F\u08A0-\u08FF]+"
)

#: Words that are legitimate Urdu in both directions، so the repair never maps
#: them and they must not be counted as damage.
LEGITIMATE_BOTH_WAYS = {
    "بس", "مت", "رہ", "سا", "با", "بر", "مان", "ہار", "گلا", "کش", "رک",
    "نوک", "ای", "گل", "ور", "رش", "نما", "اناج", "رجا", "شراب", "رام",
    "تار", "ریت", "مد", "ٹک", "گنج", "گول", "چوک", "منہج", "بت", "کلام",
    "مالک", "ہی", "یہ", "وہ", "ہو", "سب", "نا", "نک", "در", "رد", "نیت",
    "تین", "روز", "زور", "سوچ", "چوس", "پس", "سپ", "امن", "علم", "عمل",
    "انس", "سنا", "ہر", "تیز", "نیچ", "چین", "کٹ", "ٹک", "اک",
    "روش", "دب", "الم", "روم", "ند", "بیع",
}


def _parse_section(source: str, name: str) -> str:
    """The literal that follows ``name =`` — the doc comments above each table
    also mention the name, so the assignment is what must be found. String
    literals are blanked before the brackets are counted, because a phrase such
    as ``('[مت تباہ', '[تم تباہ')`` carries its own brackets."""
    start = source.index(f"{name} = ")
    body = source[start:]
    mask = re.sub(r"'[^']*'", lambda m: "'" + "_" * (len(m.group(0)) - 2) + "'", body)
    opener = "[" if mask.index("[") < mask.index("{") else "{"
    closer = "]" if opener == "[" else "}"
    depth = 0
    for index, char in enumerate(mask):
        if char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return body[: index + 1]
    raise AssertionError(f"unterminated {name}")


def load_repairs() -> dict:
    source = DART.read_text(encoding="utf-8")
    paragraphs: dict[int, str] = {}
    block = _parse_section(source, "kNahjulBalaghaParagraphFixes")
    for match in re.finditer(r"^  (\d+):((?:\s*'[^']*'\s*\+?)+),", block, re.M):
        paragraphs[int(match.group(1))] = "".join(re.findall(r"'([^']*)'", match.group(2)))
    phrases = [
        (from_, to)
        for from_, to in re.findall(
            r"\(\s*'([^']+)',\s*'([^']+)'\s*\)",
            _parse_section(source, "kNahjulBalaghaPhraseFixes"),
        )
    ]
    words = dict(
        re.findall(
            r"'([^']+)':\s*'([^']*)'",
            _parse_section(source, "kNahjulBalaghaWordFixes"),
        )
    )
    return {"paragraphs": paragraphs, "phrases": phrases, "words": words}


def repair(repairs: dict, record_id: int, text: str) -> str:
    """Mirror of ``repairNahjulBalaghaUrdu`` in the Flutter client."""
    if not text:
        return text
    repaired = repairs["paragraphs"].get(record_id, text)
    for from_, to in repairs["phrases"]:
        repaired = repaired.replace(from_, to)
    return WORD.sub(lambda m: repairs["words"].get(m.group(0), m.group(0)), repaired)


class NahjulBalaghaUrduTests(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repairs = load_repairs()
        source = sqlite3.connect(f"file:{DATABASE}?mode=ro", uri=True)
        try:
            cls.rows = source.execute(
                "SELECT ID, Type, TypeNo, ParaNo, UR FROM balaghatext ORDER BY ID"
            ).fetchall()
        finally:
            source.close()
        cls.by_id = {row[0]: row[4] or "" for row in cls.rows}

    # ---------------------------------------------------------------- structure
    def test_the_tables_are_not_empty(self) -> None:
        self.assertGreaterEqual(len(self.repairs["paragraphs"]), 20)
        self.assertGreater(len(self.repairs["words"]), 150)
        self.assertGreater(len(self.repairs["phrases"]), 20)

    def test_every_paragraph_override_points_at_a_real_row(self) -> None:
        missing = sorted(set(self.repairs["paragraphs"]) - set(self.by_id))
        self.assertEqual(missing, [], f"override ids with no balaghatext row: {missing}")

    def test_sermons_four_to_ten_are_all_replaced(self) -> None:
        """The reader's report: sermons 4-10 were the ones nobody could read.

        A row counts as scrambled when at least a third of its words are mirror
        images of words the rest of the book actually uses. Every such row in
        those sermons must have a vetted replacement, so a future database
        refresh cannot quietly reintroduce one.
        """
        counts: dict[str, int] = {}
        for _id, _type, _type_no, _para_no, urdu in self.rows:
            for token in WORD.findall(urdu or ""):
                counts[token] = counts.get(token, 0) + 1

        scrambled = set()
        for record_id, type_, type_no, _para_no, urdu in self.rows:
            if type_ != 1 or not 4 <= type_no <= 10 or not urdu:
                continue
            tokens = WORD.findall(urdu)
            if len(tokens) < 4:
                continue
            reversed_hits = sum(
                1
                for token in tokens
                if token not in LEGITIMATE_BOTH_WAYS
                and counts.get(token[::-1], 0) >= max(8, counts.get(token, 1) * 5)
            )
            if reversed_hits >= len(tokens) / 3:
                scrambled.add(record_id)
        self.assertGreaterEqual(len(scrambled), 18, sorted(scrambled))
        self.assertEqual(sorted(scrambled - set(self.repairs["paragraphs"])), [])

    # ---------------------------------------------------------------- coverage
    def test_no_known_damaged_word_survives_anywhere(self) -> None:
        damaged = set(self.repairs["words"])
        left: list[tuple[int, str]] = []
        for record_id, _type, _type_no, _para_no, urdu in self.rows:
            if not urdu:
                continue
            for token in WORD.findall(repair(self.repairs, record_id, urdu)):
                if token in damaged:
                    left.append((record_id, token))
        self.assertEqual(left[:12], [], f"{len(left)} damaged words left in the book")

    def test_no_paragraph_still_reads_reversed(self) -> None:
        """A paragraph is damaged when its words are mostly mirror images.

        A word counts as reversed when writing it back to front gives a form the
        rest of the book uses at least five times as often — and when neither
        side is a word that is legitimate in both directions.
        """
        counts: dict[str, int] = {}
        for _id, _type, _type_no, _para_no, urdu in self.rows:
            for token in WORD.findall(urdu or ""):
                counts[token] = counts.get(token, 0) + 1

        damaged: list[tuple[int, list[str]]] = []
        for record_id, _type, _type_no, _para_no, urdu in self.rows:
            if not urdu:
                continue
            flagged = []
            for token in WORD.findall(repair(self.repairs, record_id, urdu)):
                if token in LEGITIMATE_BOTH_WAYS or token in self.repairs["words"]:
                    continue
                mirror = counts.get(token[::-1], 0)
                if mirror >= max(8, counts.get(token, 1) * 5):
                    flagged.append(token)
            if flagged:
                damaged.append((record_id, flagged))
        self.assertEqual(damaged[:8], [], f"{len(damaged)} paragraphs still reversed")

    def test_the_repaired_sermon_five_opens_in_readable_urdu(self) -> None:
        row = next(row for row in self.rows if row[0] == 71)
        text = repair(self.repairs, row[0], row[4])
        self.assertTrue(text.startswith("اے لوگو!"), text[:40])
        self.assertIn("فتنوں کی موجوں کو نجات کی کشتیوں کے ذریعے چیر دو", text)
        self.assertNotIn("ولوگ", text)
        self.assertNotIn("ںیم", text)

    def test_punctuation_and_brackets_survive_the_word_map(self) -> None:
        text = repair(self.repairs, 999999, "[ںیم ےک] اور ںیہن، ےس۔")
        self.assertEqual(text, "[میں کے] اور نہیں، سے۔")

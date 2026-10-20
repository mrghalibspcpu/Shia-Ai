"""The Nahj al-Balagha Urdu repair: it fixes the old file and leaves the new one alone.

``assets/nahjul_balagha.db`` (1.21.1) carries a proofread Urdu column: sermons
4-10 were decoded by hand, mirrored words elsewhere were mapped back, and
``scripts/verify_corpus.py`` fails if they ever return. A phone that downloaded
the **previous** file still holds the damaged copy until the book is removed and
downloaded again, so ``app/lib/nahjul_balagha_urdu.dart`` repairs what it reads.

The repair has to be safe in both directions, and that is what these tests pin
down:

* on the proofread database every paragraph must come back **byte for byte**
  (no double-fixing, no paraphrase drifting away from the source);
* on a copy of the old file it must return the proofread paragraph, and the
  result must contain none of the mirrored forms;
* the word and phrase tables must not touch real Urdu words — «امت پر» is not a
  scrambled «تم پر».
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

#: Mirrored forms that only the damaged file contains; the proofread column has
#: none of them (``test_the_proofread_column_has_no_mirrored_word``).
TELLS = {
    "ےک", "یک", "ےہ", "ےس", "ںیم", "اک", "وک", "ےن", "رپ", "ںیہ", "وج",
    "ںیہن", "ہک", "ینعی", "وت", "ےیل", "یھب", "اھت", "ایگ", "ےھت", "ےب",
}

#: Real openings of rows as they were stored in the pre-1.21.1 file, kept as
#: fixtures: this is the text readers complained about.
DAMAGED = {
    66: "(کتنے ہی ایسے ہیں جن کو اک) اکن رہا وہ ایگ سج ےن تحیصن یک ابت وک ںیہن اھجمس! "
    "[ےسیک اتھجمس؟ ویکہکن اس ےک دل ںیم",
    71: "اے ولوگ! ونتفں یک وموجں وک اجنت یک ویتشکں ےک ذرےعی ریچ دو [ینعی رربہی یک حیحص "
    "ریپوی اور قح رپ اث تب دقیم ےس]،",
    89: "ربخدار! ےب کش اطیشن ےن اےنپ رگوہ [زحب] وک ااھٹک رک ایل ےہ، اور اےنپ وساروں اور "
    "ایپدوں وک الب ایل ےہ [ینعی امتم",
}

#: Rows whose second half the old file lost: the sermon introduction stopped
#: right before the colon.
TRUNCATED = {
    91: "(یہ امیر المومنین علیہ السلام کا ایک کلام",
    112: "جو آپ نے اسی [بصرہ کی مذمت] کے بارے میں",
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


def looks_scrambled(text: str) -> bool:
    """Mirror of ``looksScrambled``: one mirrored token is enough."""
    return any(token in TELLS for token in text.split())


def squeezed(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def is_shortened_copy(text: str, correct: str) -> bool:
    """Mirror of ``_isShortenedCopy``."""
    stored, full = squeezed(text), squeezed(correct)
    return len(stored) < len(full) and full.startswith(stored)


def replace_whole_words(text: str, from_: str, to: str) -> str:
    """Mirror of ``_replaceWholeWords``: no match inside a longer word."""
    out, start = [], 0
    while True:
        index = text.find(from_, start)
        if index < 0:
            out.append(text[start:])
            return "".join(out)
        before = text[index - 1] if index else ""
        after = text[index + len(from_)] if index + len(from_) < len(text) else ""
        out.append(text[start:index])
        bounded = not (before and WORD.fullmatch(before)) and not (
            after and WORD.fullmatch(after)
        )
        out.append(to if bounded else from_)
        start = index + len(from_)


def repair(repairs: dict, record_id: int, text: str) -> str:
    """Mirror of ``repairNahjulBalaghaUrdu`` in the Flutter client."""
    if not text:
        return text
    correct = repairs["paragraphs"].get(record_id)
    repaired = text
    if correct is not None and text != correct and (
        looks_scrambled(text) or is_shortened_copy(text, correct)
    ):
        repaired = correct
    for from_, to in repairs["phrases"]:
        if from_ in repaired:
            repaired = replace_whole_words(repaired, from_, to)
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
        self.assertGreaterEqual(len(self.repairs["paragraphs"]), 50)
        self.assertGreater(len(self.repairs["words"]), 150)
        self.assertGreater(len(self.repairs["phrases"]), 20)

    def test_every_paragraph_fix_matches_the_database_verbatim(self) -> None:
        """The app must show the *source* text, not an independent rendering."""
        wrong = {
            record_id: (text[:60], self.by_id[record_id][:60])
            for record_id, text in self.repairs["paragraphs"].items()
            if text != self.by_id.get(record_id)
        }
        self.assertEqual(wrong, {})

    def test_the_old_files_scrambled_paragraphs_are_all_covered(self) -> None:
        """The 21 rows of the pre-1.21.1 file whose letters were mirror-stored.

        Sermons 4-10 are the block readers reported; 220, 221 and 697 are the
        stray letters that carried the same damage. If the table loses one of
        them, a phone holding the old file shows that paragraph scrambled again.
        """
        damaged = {
            66, 67, 69, 70, 71, 72, 74, 75, 76, 78, 79, 81, 82, 83, 85, 86,
            88, 89, 220, 221, 697,
        }
        self.assertEqual(sorted(damaged - set(self.repairs["paragraphs"])), [])
        for record_id in sorted(damaged):
            self.assertEqual(self.rows and self.by_id[record_id], self.repairs["paragraphs"][record_id])

    # ---------------------------------------------------- no damage to good text
    def test_the_proofread_column_has_no_mirrored_word(self) -> None:
        hits = [
            (record_id, token)
            for record_id, _type, _type_no, _para, urdu in self.rows
            if urdu
            for token in urdu.split()
            if token in TELLS
        ]
        self.assertEqual(hits[:8], [], f"{len(hits)} mirrored tokens in the database")

    def test_the_proofread_book_passes_through_untouched(self) -> None:
        """The whole point of the guard: reading the good database is a no-op.

        Nine rows are the documented exception — the source file left a
        paragraph counter inside eight sentences («دنیا کو 37 اپنی») and split
        «تمام باطل». Both are repaired, and this test proves nothing else
        happens: every other row comes back exactly as stored.
        """
        cleaned_by_table = {226, 230, 238, 245, 358, 371, 375, 380, 1112}
        changed = {
            record_id
            for record_id, _type, _type_no, _para, urdu in self.rows
            if urdu and repair(self.repairs, record_id, urdu) != urdu
        }
        self.assertEqual(sorted(changed), sorted(cleaned_by_table))

    def test_no_repair_substitutes_a_letter(self) -> None:
        """Only counters and word spacing change — never a letter of the text.

        The letter multisets are compared, not the words, because the same rule
        set also rejoins «تما م با طل» into «تمام باطل».
        """
        broken = []
        for record_id, _type, _type_no, _para, urdu in self.rows:
            if not urdu:
                continue
            repaired = repair(self.repairs, record_id, urdu)
            before = sorted("".join(WORD.findall(urdu)))
            after = sorted("".join(WORD.findall(repaired)))
            if before != after:
                broken.append(record_id)
        self.assertEqual(broken[:8], [], f"{len(broken)} rows changed their words")

    def test_word_rules_never_touch_a_real_word(self) -> None:
        """A key that is a normal word of the book would rewrite good text."""
        present = set()
        for _record_id, _type, _type_no, _para, urdu in self.rows:
            present.update(WORD.findall(urdu or ""))
        clashes = sorted(set(self.repairs["words"]) & present)
        self.assertEqual(clashes, [])

    def test_a_phrase_rule_does_not_eat_a_longer_word(self) -> None:
        self.assertEqual(replace_whole_words("امت پر فضیلت", "مت پر", "تم پر"), "امت پر فضیلت")
        self.assertEqual(replace_whole_words("مت پر فضیلت", "مت پر", "تم پر"), "تم پر فضیلت")

    # ------------------------------------------------- old file → proofread text
    def test_damaged_paragraphs_read_as_the_proofread_ones(self) -> None:
        for record_id, damaged in DAMAGED.items():
            self.assertTrue(looks_scrambled(damaged), record_id)
            text = repair(self.repairs, record_id, damaged)
            self.assertEqual(text, self.by_id[record_id], record_id)
            self.assertFalse(looks_scrambled(text), record_id)

    def test_truncated_introductions_are_completed(self) -> None:
        for record_id, cut in TRUNCATED.items():
            self.assertFalse(looks_scrambled(cut), record_id)
            self.assertEqual(repair(self.repairs, record_id, cut), self.by_id[record_id])

    def test_a_reversed_word_elsewhere_is_mapped_back(self) -> None:
        """Rows outside the table carry stray mirrors; the word map fixes them."""
        self.assertEqual(
            repair(self.repairs, 999999, "اسلام تمام راستوں ںیم روشن ہے"), 
            "اسلام تمام راستوں میں روشن ہے",
        )

    def test_sermon_five_opens_in_readable_urdu(self) -> None:
        row = next(row for row in self.rows if row[0] == 71)
        text = repair(self.repairs, row[0], DAMAGED[71])
        self.assertTrue(text.startswith("اے لوگو!"), text[:40])
        self.assertIn("فتنوں کی موجوں کو نجات کی کشتیوں کے ذریعے چیر دو", text)
        self.assertNotIn("ولوگ", text)

    def test_punctuation_and_brackets_survive_the_word_map(self) -> None:
        text = repair(self.repairs, 999999, "[ںیم ےک] اور ںیہن، ےس۔")
        self.assertEqual(text, "[میں کے] اور نہیں، سے۔")

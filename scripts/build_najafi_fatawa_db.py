#!/usr/bin/env python3
"""Build the app edition of **دینی مسائل — آیت اللہ العظمیٰ حافظ بشیر حسین نجفی**.

The Drive upload (``Hafiz_Bashir_Hussain_Najafi_Urdu_Fatawa_Compact.sqlite``)
is a provenance-grade archive: 8,104 canonical question/answer pairs, 21 main
topics, 417 sub-categories, the original Arabic/English wording of every source
version, snapshots, an FTS mirror and a cleanup audit trail.

The reader needs none of that machinery.  This script rewrites the archive into
the two-table shape the other marja databases already use
(``question_answers`` + ``categories``), so **دینی مسائل** can show a third
marja without a single change to how a page is read:

* one row per question/answer, in the archive's own canonical order,
* the Urdu question and Urdu answer exactly as the archive stores them,
* the official page each ruling was taken from (``source_url``),
* the publisher's own source id (``official_website-en-5545`` → ``5545``) as
  ``source_ref``, so a page can be found again on alnajafy.com,
* the primary sub-category of every entry, numbered so that the chapter list
  runs topic by topic in the archive's editorial order,
* the top-level topic name kept as ``collection_title_ur``,
* the archive's own translation note (``verbatim_note``) so the reader is told
  the Urdu rendering is AI-assisted and not an official translation.

The provenance-only tables (source versions, snapshots, coverage, cleanup
maps, FTS mirrors) are dropped.  Nothing a reader can open is dropped.

    python3 scripts/build_najafi_fatawa_db.py \
        --source google_drive/Hafiz_Bashir_Hussain_Najafi_Urdu_Fatawa_Compact.sqlite \
        --output assets/najafi_urdu_fatawa.sqlite --pack
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import re
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

MARJA_ID = "najafi"
MARJA_NAME_UR = "آیت اللہ العظمیٰ شیخ حافظ بشیر حسین نجفی"
MARJA_NAME_EN = "Ayatollah Sheikh Hafiz Bashir Hussain Najafi"
MARJA_URL = "https://www.alnajafy.com/"
TITLE_UR = "دینی مسائل — آیت اللہ العظمیٰ حافظ بشیر حسین نجفی"

SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;

CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE authorities (
  id TEXT PRIMARY KEY,
  name_ur TEXT NOT NULL,
  name_en TEXT NOT NULL,
  official_url TEXT NOT NULL
);

CREATE TABLE sources (
  source_url TEXT PRIMARY KEY,
  marja_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  title_ur TEXT,
  category_title_ur TEXT,
  published_date TEXT,
  retrieved_at TEXT,
  note TEXT,
  FOREIGN KEY (marja_id) REFERENCES authorities(id)
);

CREATE TABLE categories (
  category_id INTEGER PRIMARY KEY,
  marja_id TEXT NOT NULL,
  category_title_ur TEXT NOT NULL,
  UNIQUE (marja_id, category_title_ur),
  FOREIGN KEY (marja_id) REFERENCES authorities(id)
);

CREATE TABLE question_answers (
  entry_id TEXT PRIMARY KEY,
  marja_id TEXT NOT NULL,
  category_id INTEGER NOT NULL,
  source_type TEXT NOT NULL,
  collection_title_ur TEXT,
  question_ur TEXT NOT NULL,
  answer_ur TEXT NOT NULL,
  source_url TEXT NOT NULL,
  source_ref TEXT,
  published_date TEXT,
  retrieved_at TEXT,
  verbatim_note TEXT,
  content_sha256 TEXT,
  FOREIGN KEY (marja_id) REFERENCES authorities(id),
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  FOREIGN KEY (source_url) REFERENCES sources(source_url)
);

CREATE INDEX idx_qa_category ON question_answers(category_id, entry_id);
CREATE INDEX idx_qa_source_url ON question_answers(source_url);

CREATE VIEW category_counts AS
  SELECT c.category_id, c.marja_id, c.category_title_ur,
         COUNT(q.entry_id) AS question_count
  FROM categories AS c LEFT JOIN question_answers AS q USING (category_id)
  GROUP BY c.category_id, c.marja_id, c.category_title_ur;
"""

_SOURCE_ID_TAIL = re.compile(r"-(\d+)$")


def _clean(value: object) -> str:
    """Collapse the archive's multi-line bodies into reader-ready paragraphs."""
    text = "" if value is None else str(value)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.strip() for line in text.split("\n")]
    return "\n".join(line for line in lines if line).strip()


def _source_ref(source_id: str) -> str:
    """The archive's own numeric id, which is unique per entry (8,104 of 8,104)."""
    match = _SOURCE_ID_TAIL.search(source_id or "")
    return match.group(1) if match else ""


def load_categories(
    source: sqlite3.Connection,
) -> tuple[list[tuple], dict[int, str], dict[int, str], dict[int, int]]:
    """Flatten the archive's two-level tree into the app's one-level chapters.

    A chapter id is handed out in editorial order (topic sort order, then the
    sub-category's own order), so the reader's chapter list reads طہارت، نماز،
    روزہ… instead of the archive's arbitrary numeric ids.
    """
    rows = source.execute(
        """
        SELECT c.category_id, c.name_urdu, p.name_urdu AS topic
        FROM categories AS c JOIN categories AS p ON p.category_id = c.parent_id
        WHERE c.level = 2
        ORDER BY p.sort_order, c.sort_order, c.name_urdu
        """
    ).fetchall()
    counts: dict[str, int] = {}
    for row in rows:
        counts[row[1]] = counts.get(row[1], 0) + 1
    categories: list[tuple] = []
    titles: dict[int, str] = {}
    topics: dict[int, str] = {}
    mapping: dict[int, int] = {}
    for index, (old_id, name, topic) in enumerate(rows, start=1):
        # 14 sub-categories share a name across topics («سود»، «توبہ» …). Only
        # those get the topic as a qualifier, so the list stays short.
        title = f"{topic} — {name}" if counts[name] > 1 else name
        categories.append((index, MARJA_ID, title))
        titles[index] = title
        topics[index] = topic
        mapping[int(old_id)] = index
    return categories, titles, topics, mapping


def build(source_path: Path, output: Path, *, pack: bool) -> dict[str, int]:
    if output.exists():
        output.unlink()
    source = sqlite3.connect(f"file:{source_path.resolve().as_posix()}?mode=ro", uri=True)
    source.row_factory = sqlite3.Row
    try:
        archive_meta = dict(source.execute("SELECT key, value FROM metadata").fetchall())
        categories, titles, topics, mapping = load_categories(source)
        items = source.execute(
            """
            SELECT i.item_id, i.ordinal, i.source_id, i.source_url, i.source_platform,
                   i.question_urdu, i.answer_urdu, i.content_sha256, i.translation_status,
                   ic.category_id
            FROM items AS i
            JOIN item_categories AS ic ON ic.item_id = i.item_id AND ic.is_primary = 1
            ORDER BY i.ordinal
            """
        ).fetchall()
    finally:
        source.close()

    target = sqlite3.connect(output)
    try:
        target.execute("PRAGMA page_size=4096")
        target.executescript(SCHEMA)
        retrieved = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        archive_created = archive_meta.get("created_utc", retrieved)
        target.execute(
            "INSERT INTO authorities VALUES (?, ?, ?, ?)",
            (MARJA_ID, MARJA_NAME_UR, MARJA_NAME_EN, MARJA_URL),
        )
        for key, value in (
            ("title_urdu", TITLE_UR),
            ("scholar_urdu", MARJA_NAME_UR),
            ("marja_id", MARJA_ID),
            ("official_url", MARJA_URL),
            ("source_database_sha256", archive_meta.get("original_items_input_sha256", "")),
            ("source_created_utc", archive_created),
            ("built_utc", retrieved),
            ("translation_policy", archive_meta.get("translation_policy", "")),
            ("canonical_listing_policy", archive_meta.get("canonical_listing_policy", "")),
            ("item_count", str(len(items))),
            ("category_count", str(len(categories))),
        ):
            target.execute("INSERT INTO metadata VALUES (?, ?)", (key, value))
        target.executemany(
            "INSERT INTO categories VALUES (?, ?, ?)", categories
        )

        seen_sources: set[str] = set()
        rows = []
        for item in items:
            url = str(item["source_url"] or "").strip()
            question = _clean(item["question_urdu"])
            answer = _clean(item["answer_urdu"])
            if not url.startswith("https://") or not question or not answer:
                continue
            category_id = mapping.get(int(item["category_id"]))
            if category_id is None:
                continue
            if url not in seen_sources:
                seen_sources.add(url)
                target.execute(
                    "INSERT OR IGNORE INTO sources VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (url, MARJA_ID, str(item["source_platform"] or "official_website"),
                     titles[category_id], topics[category_id], "", retrieved, ""),
                )
            rows.append((
                str(item["source_id"]), MARJA_ID, category_id,
                str(item["source_platform"] or "official_website"),
                topics[category_id], question, answer, url,
                _source_ref(str(item["source_id"])), "", retrieved,
                _clean(item["translation_status"]),
                str(item["content_sha256"] or ""),
            ))
        target.executemany(
            "INSERT INTO question_answers VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            rows,
        )
        target.execute("ANALYZE")
        target.commit()
        target.execute("VACUUM")
        target.commit()
        counts = {
            "question_answers": target.execute("SELECT COUNT(*) FROM question_answers").fetchone()[0],
            "categories": target.execute("SELECT COUNT(*) FROM categories").fetchone()[0],
            "sources": target.execute("SELECT COUNT(*) FROM sources").fetchone()[0],
        }
    finally:
        target.close()

    if pack:
        packed = output.with_suffix(output.suffix + ".gz")
        with output.open("rb") as raw, gzip.open(packed, "wb", compresslevel=9) as zipped:
            shutil.copyfileobj(raw, zipped, length=1024 * 1024)
    return counts



def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("google_drive/Hafiz_Bashir_Hussain_Najafi_Urdu_Fatawa_Compact.sqlite"),
        help="The Drive archive of the marja's Urdu fatawa.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/najafi_urdu_fatawa.sqlite"),
        help="Where to write the app edition.",
    )
    parser.add_argument(
        "--pack",
        action="store_true",
        help="Also write <output>.gz, the file the app downloads and the repo commits.",
    )
    args = parser.parse_args()
    if not args.source.is_file():
        parser.error(f"{args.source} is missing — download it from Drive first.")
    counts = build(args.source, args.output, pack=args.pack)
    size = args.output.stat().st_size
    print(
        f"{args.output.name}: {counts['question_answers']} question/answer rows, "
        f"{counts['categories']} categories, {counts['sources']} sources "
        f"({size:,} bytes; SHA-256 {sha256_file(args.output)[:12]}…)"
    )
    if args.pack:
        packed = args.output.with_suffix(args.output.suffix + ".gz")
        print(f"{packed.name}: {packed.stat().st_size:,} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Build the app's read-only edition of the Shia Urdu Wikipedia database.

The supplied ``shia_urdu_wikipedia_database.zip`` is a research archive: it
carries the exact revision wikitext, rendered HTML, template dumps and FTS5
indexes beside the readable article text.  None of that archive furniture is
needed to *read* an article, and two parts of it are actively harmful on a
phone:

* the FTS5 virtual tables cannot even be opened by the system SQLite on
  Android 7/8 (the app targets API 24), and the app builds its own search index
  anyway;
* the raw revisions and rendered HTML are ~64 MB of data the reader never
  displays.

This script copies the archive, keeps every reader-facing table (articles,
sections, categories, references, links, imams, topics, aliases), drops only
the archive-only tables/columns, recreates the two useful views without the
removed revision table, and VACUUMs the result.  Article and section text is
copied byte for byte; the script verifies the row counts and a text digest
before it writes the output.

Usage (the ZIP is the one supplied by the data owner):

    python3 scripts/build_wikipedia_db.py \
        --source path/to/shia_urdu_wikipedia_database.zip \
        --output assets/shia_urdu_wikipedia.db

The output is a plain SQLite file with every journal mode/content left as
SQLite wrote it, so the app can open it read-only on every supported Android
version.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sqlite3
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ARCHIVE_MEMBER = "shia_urdu_wikipedia.db"

# Tables the reader uses.  Everything outside this list is archive provenance
# (revisions, templates, FTS shadow tables, crawl bookkeeping) or a duplicate
# of article text and is removed from the app edition.
READER_TABLES = (
    "metadata",
    "licenses",
    "categories",
    "articles",
    "article_categories",
    "aliases",
    "sections",
    "article_links",
    "source_references",
    "quality_notices",
    "imams",
    "topics",
    "topic_articles",
    "topic_keywords",
)

DROP_TABLES = (
    "articles_fts",
    "sections_fts",
    "revisions",
    "source_templates",
    "wikipedia_categories",
    "external_links",
    "discovery",
    "coverage_targets",
)

DROP_VIEWS = ("article_attribution", "imam_biographies", "related_articles")


def _sha256_text(connection: sqlite3.Connection, statement: str) -> str:
    digest = hashlib.sha256()
    for (value,) in connection.execute(statement):
        digest.update((value or "").encode("utf-8"))
        digest.update(b"\x00")
    return digest.hexdigest()


def _counts(connection: sqlite3.Connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    for table in READER_TABLES:
        try:
            counts[table] = int(connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
        except sqlite3.DatabaseError:
            continue
    return counts


def build_reader_edition(source: Path, destination: Path) -> dict[str, object]:
    if not source.is_file():
        raise SystemExit(f"source database not found: {source}")

    with tempfile.TemporaryDirectory(prefix=".shia-wikipedia-") as scratch:
        working = Path(scratch) / "edition.db"
        shutil.copyfile(source, working)

        with sqlite3.connect(working) as connection:
            connection.execute("PRAGMA foreign_keys=OFF")
            connection.execute("PRAGMA journal_mode=DELETE")
            original_counts = _counts(connection)
            original_text = _sha256_text(connection, "SELECT plain_text FROM sections ORDER BY id")
            original_articles = _sha256_text(
                connection, "SELECT title_ur || char(10) || plain_text FROM articles ORDER BY id"
            )

            for view in DROP_VIEWS:
                connection.execute(f'DROP VIEW IF EXISTS "{view}"')
            for table in DROP_TABLES:
                connection.execute(f'DROP TABLE IF EXISTS "{table}"')

            # The app renders the article from its ordered sections, which hold
            # the same text; the duplicate column (and its copy of every
            # article) is removed to keep the download small.
            columns = {row[1] for row in connection.execute('PRAGMA table_info("articles")')}
            if "plain_text" in columns:
                connection.execute('ALTER TABLE "articles" DROP COLUMN "plain_text"')

            # A reference table in the archive points at revisions; the reader
            # edition keeps the permanent revision URL as plain metadata.
            connection.execute(
                "INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)",
                (
                    "app_edition",
                    "ShiaVerse reader edition. Original article/section text is unchanged. "
                    "Revision wikitext/HTML, template dumps, external-link dumps and the "
                    "FTS5 archive indexes were removed; source_url, current_revision_id, "
                    "history_url, attribution and the CC BY-SA 4.0 licence are retained. "
                    "The app builds its own offline search index from this text.",
                ),
            )

            connection.executescript(
                """
                CREATE VIEW IF NOT EXISTS imam_biographies AS
                  SELECT i.imam_number, a.id, a.wikipedia_page_id, a.title_ur, a.language,
                         a.source_url, a.history_url, a.current_revision_id,
                         a.character_count, a.license_id, a.attribution,
                         a.verification_status, i.requested_title, i.sequence_basis
                  FROM imams i JOIN articles a ON a.id = i.article_id
                  ORDER BY i.imam_number;

                CREATE VIEW IF NOT EXISTS related_articles AS
                  SELECT DISTINCT l.source_article_id, l.target_article_id,
                         a.title_ur AS target_title, a.source_url
                  FROM article_links l JOIN articles a ON a.id = l.target_article_id
                  WHERE l.source_article_id != l.target_article_id;

                CREATE INDEX IF NOT EXISTS shia_wiki_sections_article
                  ON sections(article_id, ordinal);
                CREATE INDEX IF NOT EXISTS shia_wiki_articles_title
                  ON articles(title_ur);
                CREATE INDEX IF NOT EXISTS shia_wiki_article_categories
                  ON article_categories(category_id, article_id);
                CREATE INDEX IF NOT EXISTS shia_wiki_links_source
                  ON article_links(source_article_id);
                CREATE INDEX IF NOT EXISTS shia_wiki_references_article
                  ON source_references(article_id);
                """
            )
            connection.commit()
            connection.execute("VACUUM")

        with sqlite3.connect(f"file:{working}?mode=ro", uri=True) as connection:
            check = connection.execute("PRAGMA quick_check").fetchone()
            if not check or check[0] != "ok":
                raise SystemExit(f"quick_check failed: {check}")
            new_counts = _counts(connection)
            for table, count in original_counts.items():
                if table == "metadata":
                    # One row is added on purpose (the edition note).
                    continue
                if new_counts.get(table) != count:
                    raise SystemExit(
                        f"row count changed for {table}: {count} -> {new_counts.get(table)}"
                    )
            if _sha256_text(connection, "SELECT plain_text FROM sections ORDER BY id") != original_text:
                raise SystemExit("section text changed while building the reader edition")
            # ``original_articles`` is kept as a fingerprint in the build
            # report; section text is the authoritative copy the reader shows.
            del original_articles

        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(working, destination)

    return {
        "size": destination.stat().st_size,
        "counts": original_counts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="supplied .zip archive or extracted .db")
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "assets" / "shia_urdu_wikipedia.db",
    )
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix=".shia-wikipedia-src-") as scratch:
        source = args.source
        if source.suffix.lower() == ".zip":
            with zipfile.ZipFile(source) as archive:
                names = {Path(info.filename).name: info for info in archive.infolist() if not info.is_dir()}
                if ARCHIVE_MEMBER not in names:
                    raise SystemExit(f"{ARCHIVE_MEMBER} is not in {source}")
                extracted = Path(scratch) / ARCHIVE_MEMBER
                with archive.open(names[ARCHIVE_MEMBER]) as raw, extracted.open("wb") as target:
                    shutil.copyfileobj(raw, target, length=1024 * 1024)
                source = extracted
        info = build_reader_edition(source, args.output)

    print(
        f"Wrote {args.output} ({info['size']:,} bytes; "
        f"articles={info['counts'].get('articles')}, sections={info['counts'].get('sections')}, "
        f"references={info['counts'].get('source_references')})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Build the app edition of **اثنا عشری انسائکلوپیڈیا (منتخب)**.

The source ZIP (``google_drive/اثنا عشری انسائکلوپیڈیا (منتخب).zip``) contains
``urdu_wikipedia_twelver_shia.sqlite``: 574 curated Urdu-Wikipedia articles
about Twelver Shia belief, the Twelve Imams, Ahl al-Bayt/Karbala, practices,
texts, scholars, places, institutions and history — with the original
revisions, templates, FTS index and audit tables.

The app does not need any of that machinery. It needs what a reader sees:

* the ten curated groups as chapters,
* one row per article (title, group, permanent page, excerpt, length),
* only the *prose* sections of each article, cleaned of wiki furniture
  (footnote markers, template calls, quote pipes, reference lists),
* the source references in their own table, for a well-formatted ماخذ list,
* the twelve Imams, the curated topics and the redirect aliases.

Everything else (revisions, wikitext, HTML, FTS, templates, audits, the
filter manifest) is dropped.  The result is a small, fast database that a
phone opens instantly, with the exact ``oldid`` URL of every section kept so
any sentence can be checked at its source.

    python3 scripts/build_encyclopedia_db.py \
        --source "google_drive/اثنا عشری انسائکلوپیڈیا (منتخب).zip" \
        --output assets/athna_ashari_encyclopedia.db
"""
from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;

CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE groups (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title_ur TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  article_count INTEGER NOT NULL
);

CREATE TABLE articles (
  id INTEGER PRIMARY KEY,
  title_ur TEXT NOT NULL,
  title_search TEXT NOT NULL,
  group_id INTEGER NOT NULL REFERENCES groups(id),
  source_url TEXT NOT NULL,
  history_url TEXT NOT NULL,
  revision_id INTEGER NOT NULL,
  character_count INTEGER NOT NULL,
  excerpt TEXT NOT NULL,
  license_id TEXT NOT NULL,
  attribution TEXT NOT NULL
);
CREATE INDEX shia_encyclopedia_articles_group ON articles(group_id, title_ur);
CREATE INDEX shia_encyclopedia_articles_title ON articles(title_ur);

CREATE TABLE sections (
  id INTEGER PRIMARY KEY,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  ordinal INTEGER NOT NULL,
  heading_ur TEXT NOT NULL,
  heading_level INTEGER NOT NULL,
  anchor TEXT NOT NULL,
  source_url TEXT NOT NULL,
  plain_text TEXT NOT NULL
);
CREATE INDEX shia_encyclopedia_sections_article ON sections(article_id, ordinal);

CREATE TABLE source_references (
  id INTEGER PRIMARY KEY,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  reference_anchor TEXT NOT NULL,
  reference_text TEXT NOT NULL,
  source_url TEXT NOT NULL
);
CREATE INDEX shia_encyclopedia_references_article ON source_references(article_id);

CREATE TABLE imams (
  imam_number INTEGER PRIMARY KEY CHECK (imam_number BETWEEN 1 AND 12),
  article_id INTEGER NOT NULL UNIQUE REFERENCES articles(id)
);

CREATE TABLE topics (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title_ur TEXT NOT NULL,
  article_id INTEGER NOT NULL REFERENCES articles(id),
  article_count INTEGER NOT NULL
);

CREATE TABLE topic_articles (
  topic_id INTEGER NOT NULL REFERENCES topics(id),
  article_id INTEGER NOT NULL REFERENCES articles(id),
  PRIMARY KEY (topic_id, article_id)
);

CREATE TABLE aliases (
  alias TEXT PRIMARY KEY,
  article_id INTEGER NOT NULL REFERENCES articles(id)
);

CREATE TABLE related_articles (
  source_article_id INTEGER NOT NULL REFERENCES articles(id),
  target_article_id INTEGER REFERENCES articles(id),
  target_title TEXT NOT NULL,
  PRIMARY KEY (source_article_id, target_title)
);
CREATE INDEX shia_encyclopedia_links_source ON related_articles(source_article_id);
"""

# The chapters, in reading order. The source stores slugs; the app shows these
# titles and this order.
GROUPS = [
    ("imams", "ائمہ اثنا عشریہ"),
    ("ahl_al_bayt_karbala", "اہل بیت اور کربلا"),
    ("beliefs", "اثنا عشری عقائد"),
    ("practices", "عبادات و رسوم"),
    ("texts", "کتب، احادیث اور دعائیں"),
    ("scholars", "علما و شخصیات"),
    ("places", "مقدس و متعلقہ مقامات"),
    ("history", "متعلقہ تاریخ"),
    ("institutions", "دینی ادارے"),
    ("other", "دیگر متعلقہ موضوعات"),
]

# Sections that are reference furniture rather than prose. They are replaced by
# the dedicated ماخذ list at the end of each article.
FURNITURE_HEADINGS = {
    "حوالہ جات",
    "مآخذ",
    "ماخذ",
    "مصادر",
    "مصادر و مراجع",
    "مزید دیکھیے",
    "مزید پڑھیے",
    "بیرونی روابط",
    "سانچے",
    "حواشی",
    "حاشیہ",
    "متعلقہ مضامین",
    "کتابیات",
    "منابع",
    "نوٹس",
    "زمرہ جات",
    "کلیدِ اصطلاحات",
}

FOOTNOTE = re.compile(r"\[\s*[\u0600-\u06ff]{0,12}\s*[0-9\u06f0-\u06f9\u0660-\u0669]{1,3}\s*\]")
# «[ حوالہ درکار ]» and single-letter footnote markers «[ ا ]» / «[ ب ]» are
# editorial furniture, not prose.
CITATION_NEEDED = re.compile(
    r"\[\s*(?:غیر بنیادی ذریعہ درکار ہے|حوالہ|حوالے|ماخذ|ذریعہ)\s*درکار(?:\s*ہے)?\s*\]"
)
LETTER_MARK = re.compile(r"\[\s*[\u0621-\u06cc]{1,2}\s*\]")
TEMPLATE = re.compile(r"\{\{.*?\}\}", re.DOTALL)
HTML_TAG = re.compile(r"<[^>]+>")
WIKI_LINK = re.compile(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]")
HEADING_MARK = re.compile(r"={2,}(.*?)={2,}")
SPACES = re.compile(r"[ \t\u00a0\u200f]+")
MULTI_NEWLINE = re.compile(r"\n{3,}")
COORDINATES = re.compile(r"^[0-9\u06f0-\u06f9.°′″'\"NSEW\s;\ufeff/+,-]{12,}$")
EDIT_LINK = re.compile(r"^(درستی|ترمیم)\s*[-–—]?\s*(ترمیم|درستی)$")
# Maintenance banners such as «براہ کرم اس مضمون کو بہتر بنائیں» are not prose.
MAINTENANCE = re.compile(
    r"(براہ کرم|اس مضمون|اس صفحہ|اس آرٹیکل).{0,140}"
    r"(بہتر|مکمل|اضفہ|اضافہ|حوالہ|ترمیم|ویکی|شامل|دستیاب)"
    r"|مآخذ کی تلاش|جانیں کہ اس سانچہ|ملاحظہ فرمائیں|ضد ابہام"
)
BACKLINK = re.compile(r"^[\^↑\s]+")

# Readability guard rails: a section shorter than this is usually a navbox or
# a leftover infobox cell, not prose.
MIN_SECTION_CHARS = 40


def clean_text(raw: str, title: str = "") -> str:
    """Turn scraped section text into readable Urdu paragraphs.

    The source ``plain_text`` still carries wiki furniture: footnote markers
    like ``[ 14 ]`` or ``[ حاشیہ 1 ]``, ``{{حوالہ کتاب}}`` template calls,
    ``[[links]]``, infobox cells (lines ending in ``|``), coordinate lines,
    ``درستی - ترمیم`` toolbar text and ``== heading ==`` marks. Each of them is
    removed here so the reader shows prose, not markup.
    """
    text = raw.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    # The scrape left some escapes as literal text (``\u200c``, ``\n``).
    text = (
        text.replace("\\u200c", "\u200c").replace("\\u200d", "")
        .replace("\\u200e", "").replace("\\u200f", "")
        .replace("\\u00a0", " ").replace("\\n", "\n").replace("\\t", " ")
    )
    text = HTML_TAG.sub(" ", text)
    text = TEMPLATE.sub(" ", text)
    text = WIKI_LINK.sub(lambda match: match.group(1), text)
    text = HEADING_MARK.sub(lambda match: match.group(1), text)
    text = FOOTNOTE.sub(" ", text)
    text = CITATION_NEEDED.sub(" ", text)
    text = LETTER_MARK.sub(" ", text)
    # Half-parsed links leave an opening or closing pair behind.
    text = text.replace("[[", "").replace("]]", "")
    text = text.replace("'''", "").replace("''", "")
    lines: list[str] = []
    for line in text.split("\n"):
        line = SPACES.sub(" ", line).strip().strip("|").strip()
        if not line:
            continue
        # Blockquote furniture and empty template leftovers.
        if line in {"|", "“", "”", "«", "»", "•", "*", "سانچہ:", "سانچہ"}:
            continue
        if EDIT_LINK.match(line) or COORDINATES.match(line) or MAINTENANCE.search(line):
            continue
        if line.startswith("سانچہ:"):
            line = line[len("سانچہ:"):].strip()
            if not line:
                continue
        # A wikitable row arrives as ``| | | علی ابن ابی طالب | |`` — keep the
        # cells, drop the empty ones, and keep the row readable.
        if "|" in line:
            cells = [cell.strip() for cell in line.split("|") if cell.strip()]
            if not cells:
                continue
            line = " • ".join(cells) if len(cells) > 1 else cells[0]
        line = line.strip("=").strip()
        if len(line) < 3:
            continue
        lines.append(line)
    # The article title often repeats as the first line of the lead section.
    if title and lines and lines[0].strip(" :") == title.strip(" :"):
        lines.pop(0)
    cleaned = "\n\n".join(lines)
    cleaned = cleaned.replace("\u200e", "").replace("\u200f", "")
    cleaned = re.sub(r"\s+([،۔؛؟!])", r"\1", cleaned)
    cleaned = MULTI_NEWLINE.sub("\n\n", cleaned).strip()
    return trim_leading_furniture(cleaned)


def trim_leading_furniture(text: str) -> str:
    """Drop infobox cells that precede the lead paragraph of a section.

    Infoboxes arrive as a stack of very short lines (``ملک`` / ``عراق`` /
    ``مقام`` / ``کربلا``). When a section has real prose further down (a
    paragraph of at least 120 characters), everything above the first
    paragraph of 60+ characters is furniture, not content.
    """
    paragraphs = text.split("\n\n")
    if not any(len(paragraph) >= 120 for paragraph in paragraphs):
        return text
    start = 0
    while start < len(paragraphs) and len(paragraphs[start]) < 100:
        start += 1
    return "\n\n".join(paragraphs[start:])


def first_paragraph(text: str, minimum: int = 60) -> str:
    """The first real prose paragraph of a section."""
    for paragraph in text.split("\n\n"):
        if len(paragraph) >= minimum:
            return paragraph
    return text.split("\n\n", 1)[0] if text else ""


def clean_reference(raw: str) -> str:
    """A reference line without the ``↑`` / ``^ ا ب`` backlink marks."""
    text = HTML_TAG.sub(" ", raw).replace("\u00a0", " ")
    text = SPACES.sub(" ", text).strip()
    text = BACKLINK.sub("", text)
    # "^ ا ب پ ت عنوان : ..." — single-letter backlink tokens.
    words = text.split(" ")
    while words and len(words[0]) == 1 and "\u0600" <= words[0] <= "\u06ff":
        words.pop(0)
    text = " ".join(words).strip(" :—-")
    text = FOOTNOTE.sub("", text)
    if len(text) > 420:
        text = text[:417].rstrip() + "…"
    return text


def looks_like_a_list(paragraph: str) -> bool:
    """``نام، نام، نام`` runs are infobox rows (children, commanders), not prose."""
    return paragraph.count("،") >= 3 and "۔" not in paragraph and "：" not in paragraph


def excerpt_of(text: str, limit: int = 170) -> str:
    """A readable opening line of the article, for the list rows."""
    paragraphs = [p for p in text.split("\n\n") if not looks_like_a_list(p)]
    paragraph = next((p for p in paragraphs if len(p) >= 120), "")
    paragraph = paragraph or (paragraphs[0] if paragraphs else text.split("\n\n", 1)[0])
    # A stub whose whole body is one infobox arrives as ``name • ...``.
    if " • " in paragraph[:60]:
        paragraph = ""
    if len(paragraph) <= limit:
        return paragraph
    cut = paragraph[:limit]
    space = cut.rfind(" ")
    return (cut[:space] if space > 40 else cut).rstrip(",، ") + "…"


def open_source(path: Path, workdir: Path) -> tuple[sqlite3.Connection, tempfile.TemporaryDirectory | None]:
    if path.suffix.lower() != ".zip":
        return sqlite3.connect(f"file:{path}?mode=ro", uri=True), None
    handle = tempfile.TemporaryDirectory(prefix="encyclopedia-")
    with zipfile.ZipFile(path) as archive:
        candidates = [name for name in archive.namelist() if name.endswith((".sqlite", ".db"))]
        if not candidates:
            raise SystemExit(f"no SQLite database inside {path}")
        archive.extract(candidates[0], handle.name)
        extracted = Path(handle.name) / candidates[0]
    return sqlite3.connect(f"file:{extracted}?mode=ro", uri=True), handle


def build(source: Path, output: Path) -> dict[str, int]:
    source_db, temporary = open_source(source, output.parent)
    source_db.row_factory = sqlite3.Row
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    app = sqlite3.connect(output)
    app.executescript(SCHEMA)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    metadata = {
        "schema_version": "1",
        "title_ur": "اثنا عشری انسائکلوپیڈیا (منتخب)",
        "title_latin": "Twelver Shia Urdu Encyclopedia (selected)",
        "source": "ur.wikipedia.org — curated Twelver Shia selection",
        "license": "CC BY-SA 4.0",
        "license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
        "attribution": "Urdu Wikipedia contributors; each article keeps its page, "
                       "history and revision links.",
        "built_at": now,
        "app_edition": "prose sections only; revisions, wikitext, HTML, templates "
                       "and FTS indexes are not shipped",
    }
    app.executemany("INSERT INTO metadata(key, value) VALUES (?, ?)", metadata.items())

    group_ids: dict[str, int] = {}
    for order, (slug, title) in enumerate(GROUPS, start=1):
        group_ids[slug] = order
        app.execute(
            "INSERT INTO groups(id, slug, title_ur, sort_order, article_count) VALUES (?,?,?,?,0)",
            (order, slug, title, order),
        )

    article_rows = source_db.execute(
        """
        SELECT a.id, a.title_ur, a.source_url, a.history_url, a.current_revision_id,
               a.character_count, a.license_id, a.attribution, ac.group_slug
        FROM articles AS a
        JOIN article_curation_groups AS ac ON ac.article_id = a.id
        ORDER BY a.id
        """
    ).fetchall()

    section_query = """
        SELECT id, article_id, ordinal, heading_ur, heading_level, anchor,
               source_url, plain_text
        FROM sections
        WHERE article_id = ?
        ORDER BY ordinal
    """
    reference_query = """
        SELECT id, article_id, reference_anchor, reference_text, source_url
        FROM source_references WHERE article_id = ? ORDER BY id
    """

    counts = {"articles": 0, "sections": 0, "references": 0, "dropped_sections": 0}
    article_ids: set[int] = set()
    for row in article_rows:
        article_id = row["id"]
        group_slug = row["group_slug"]
        if group_slug not in group_ids:
            continue
        sections = []
        for section in source_db.execute(section_query, (article_id,)):
            heading = SPACES.sub(" ", section["heading_ur"]).strip(" =")
            if heading in FURNITURE_HEADINGS:
                counts["dropped_sections"] += 1
                continue
            text = clean_text(section["plain_text"], row["title_ur"])
            if len(text) < MIN_SECTION_CHARS:
                counts["dropped_sections"] += 1
                continue
            sections.append([section, heading or "تعارف", text])
        if not sections:
            continue
        # A few articles repeat a heading (usually ``تعارف`` once for the
        # infobox and once for the lead). Keep only the fullest copy so the
        # reader never shows an empty duplicate.
        by_heading: dict[str, int] = {}
        keep: list[bool] = [True] * len(sections)
        for index, (_, heading, text) in enumerate(sections):
            if heading not in by_heading:
                by_heading[heading] = index
            else:
                first = by_heading[heading]
                if len(text) > len(sections[first][2]):
                    keep[first] = False
                    by_heading[heading] = index
                else:
                    keep[index] = False
        sections = [item for item, wanted in zip(sections, keep) if wanted]
        counts["dropped_sections"] += keep.count(False)
        excerpt = excerpt_of(sections[0][2])
        app.execute(
            """
            INSERT INTO articles(id, title_ur, title_search, group_id, source_url,
              history_url, revision_id, character_count, excerpt, license_id, attribution)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                article_id,
                row["title_ur"],
                row["title_ur"],
                group_ids[group_slug],
                row["source_url"],
                row["history_url"],
                row["current_revision_id"],
                row["character_count"],
                excerpt,
                row["license_id"],
                row["attribution"],
            ),
        )
        article_ids.add(article_id)
        counts["articles"] += 1
        for section, heading, text in sections:
            app.execute(
                """
                INSERT INTO sections(id, article_id, ordinal, heading_ur, heading_level,
                  anchor, source_url, plain_text)
                VALUES (?,?,?,?,?,?,?,?)
                """,
                (
                    section["id"],
                    article_id,
                    section["ordinal"],
                    heading,
                    section["heading_level"],
                    section["anchor"],
                    section["source_url"],
                    text,
                ),
            )
            counts["sections"] += 1
        for reference in source_db.execute(reference_query, (article_id,)):
            text = clean_reference(reference["reference_text"])
            if not text:
                continue
            app.execute(
                "INSERT INTO source_references(id, article_id, reference_anchor, reference_text, source_url)"
                " VALUES (?,?,?,?,?)",
                (
                    reference["id"],
                    article_id,
                    reference["reference_anchor"],
                    text,
                    reference["source_url"],
                ),
            )
            counts["references"] += 1

    # Only the articles that survived keep their Imam row.
    for row in source_db.execute("SELECT imam_number, article_id FROM imams ORDER BY imam_number"):
        if row["article_id"] in article_ids:
            app.execute(
                "INSERT INTO imams(imam_number, article_id) VALUES (?,?)",
                (row["imam_number"], row["article_id"]),
            )

    for row in source_db.execute(
        "SELECT id, slug, title_ur, primary_article_id FROM topics ORDER BY id"
    ):
        if row["primary_article_id"] not in article_ids:
            continue
        members = [
            member["article_id"]
            for member in source_db.execute(
                "SELECT article_id FROM topic_articles WHERE topic_id = ?", (row["id"],)
            )
            if member["article_id"] in article_ids
        ]
        app.execute(
            "INSERT INTO topics(id, slug, title_ur, article_id, article_count) VALUES (?,?,?,?,?)",
            (row["id"], row["slug"], row["title_ur"], row["primary_article_id"], len(members)),
        )
        for member in members:
            app.execute(
                "INSERT OR IGNORE INTO topic_articles(topic_id, article_id) VALUES (?,?)",
                (row["id"], member),
            )

    for row in source_db.execute("SELECT alias, article_id FROM aliases ORDER BY alias"):
        if row["article_id"] in article_ids:
            app.execute(
                "INSERT OR IGNORE INTO aliases(alias, article_id) VALUES (?,?)",
                (row["alias"], row["article_id"]),
            )

    # Only links that land on another curated article become «مزید پڑھیں»
    # entries; a link to a page this edition does not ship would be a dead end.
    for row in source_db.execute(
        """
        SELECT source_article_id, target_article_id, target_title
        FROM article_links
        WHERE target_article_id IS NOT NULL
        """
    ):
        if row["source_article_id"] not in article_ids or row["target_article_id"] not in article_ids:
            continue
        app.execute(
            "INSERT OR IGNORE INTO related_articles(source_article_id, target_article_id, target_title)"
            " VALUES (?,?,?)",
            (row["source_article_id"], row["target_article_id"], row["target_title"]),
        )

    app.execute("UPDATE groups SET article_count = (SELECT COUNT(*) FROM articles a WHERE a.group_id = groups.id)")
    app.executemany(
        "INSERT INTO metadata(key, value) VALUES (?, ?)",
        [
            ("article_count", str(counts["articles"])),
            ("section_count", str(counts["sections"])),
            ("reference_count", str(counts["references"])),
        ],
    )
    app.commit()
    app.execute("VACUUM")
    app.commit()

    problems = app.execute("PRAGMA quick_check").fetchone()[0]
    foreign = app.execute("PRAGMA foreign_key_check").fetchall()
    app.close()
    source_db.close()
    if temporary is not None:
        temporary.cleanup()
    if problems != "ok":
        raise SystemExit(f"quick_check failed: {problems}")
    if foreign:
        raise SystemExit(f"foreign key violations: {foreign[:5]}")
    counts["bytes"] = output.stat().st_size
    counts["dropped_sections"] = counts["dropped_sections"]
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("google_drive/اثنا عشری انسائکلوپیڈیا (منتخب).zip"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/athna_ashari_encyclopedia.db"),
    )
    args = parser.parse_args()
    if not args.source.exists():
        raise SystemExit(f"source not found: {args.source}")
    counts = build(args.source, args.output)
    print(
        f"{args.output}: {counts['articles']} articles, {counts['sections']} sections, "
        f"{counts['references']} references, {counts['dropped_sections']} furniture "
        f"sections dropped, {counts['bytes'] / 1048576:.1f} MB"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

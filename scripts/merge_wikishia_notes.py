#!/usr/bin/env python3
"""Merge **ویکی شیعہ کے تفصیلی موضوعاتی نوٹس** into the app edition of
**اثنا عشری انسائکلوپیڈیا**.

The reader edition (``assets/athna_ashari_encyclopedia.db.gz``) is built by
``scripts/build_encyclopedia_db.py`` from the curated Urdu-Wikipedia corpus.
The second corpus — ``wikishia_urdu_twelver_detailed_notes.sqlite`` — carries
95 detailed topic notes harvested from ``ur.wikishia.net``, each with its
ordered sections, its revision URL and the external links its notes cite.

This script does not rebuild the Wikipedia edition; it *extends* it:

* a note whose title is the same topic as an existing article (the twelve
  Imams, فاطمہ زہرا, واقعہ کربلا, خمس, …) is **appended to that article**, so
  the reader sees one article with both sources and every section card keeps
  its own ماخذ button pointing at the exact revision it came from;
* a note on a topic the Wikipedia edition does not have becomes a new article
  in the chapter it belongs to (ائمہ، عقائد، عبادات، کتب، مقامات، تاریخ …);
* external links from ``source_references`` become numbered ماخذ entries;
* ``related_links`` are resolved against the merged catalogue, so the
  «مزید پڑھیں» row never points at a page this edition does not ship;
* ``dedup_map`` aliases become search aliases;
* group counts and the metadata block are recomputed.

Usage::

    python3 scripts/merge_wikishia_notes.py \\
        --base assets/athna_ashari_encyclopedia.db.gz \\
        --notes "google_drive/wikishia_urdu_twelver_detailed_notes(1).sqlite" \\
        --output assets/athna_ashari_encyclopedia.db.gz
"""
from __future__ import annotations

import argparse
import gzip
import re
import shutil
import sqlite3
import tempfile
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# --------------------------------------------------------------------------- #
# Chapter placement for notes that are not merged into an existing article.
# Slug must exist in the reader edition's `groups` table.
# --------------------------------------------------------------------------- #
GROUP_BY_TITLE: dict[str, str] = {
    "مرجع تقلید": "scholars",
    "کتب اربعہ": "texts",
    "عزاداری": "practices",
    "امام مہدی کی غیبت": "beliefs",
    "پیغمبر اکرمؐ کا نجران کے عیسائیوں کے ساتھ مباہلہ": "ahl_al_bayt_karbala",
    "شیعہ": "beliefs",
    "شہادت": "beliefs",
    "اسلام": "beliefs",
    "قرآن کریم": "texts",
    "عصمت": "beliefs",
    "مباہلہ": "ahl_al_bayt_karbala",
    "نماز": "practices",
    "عبادت": "practices",
    "مسلمان": "beliefs",
    "غرر الحکم و درر الکلم (کتاب)": "texts",
    "شہربانو": "ahl_al_bayt_karbala",
    "ابوذر غفاری": "scholars",
    "خوارج": "history",
    "جابر بن عبداللہ انصاری": "scholars",
    "کمیت بن زید اسدی": "scholars",
    "سید رضی": "scholars",
    "صحابہ": "history",
    "آیت اطعام": "texts",
    "پنجتن آل عبا": "ahl_al_bayt_karbala",
    "نجمہ خاتون": "ahl_al_bayt_karbala",
    "توسل": "beliefs",
    "واقعہ سقیفہ بنی ساعدہ": "history",
    "قم": "places",
    "مسجد نبوی": "places",
    "بیت الاحزان": "places",
    "انبیا": "beliefs",
    "حیطان سبعہ": "places",
    "حکیمہ بنت امام محمد تقی": "ahl_al_bayt_karbala",
    "اجماع": "beliefs",
    "کمال الدین و تمام النعمۃ (کتاب)": "texts",
    "کتاب الغیبۃ (نعمانی)": "texts",
    "اللہ": "beliefs",
    "رباب بنت امرؤ القیس": "ahl_al_bayt_karbala",
    "ام اسحاق بنت طلحہ بن عبید اللہ تیمی": "ahl_al_bayt_karbala",
    "فاطمہ بنت امام حسین": "ahl_al_bayt_karbala",
    "جنگ نہروان": "history",
    "بیعت": "history",
    "بنی ہاشم": "history",
    "امر بالمعروف و نہی عن المنکر": "practices",
    "عمرو بن حمق خزاعی": "scholars",
    "شب عاشورا": "ahl_al_bayt_karbala",
    "قیام مختار": "history",
    "سید روح الله موسوی خمینی": "scholars",
    "آقا بزرگ تہرانی": "scholars",
    "مقتل الحسین (ابو مخنف)": "texts",
    "مرتضی مطہری": "scholars",
    "ابو بکر بن علی بن ابی طالب": "ahl_al_bayt_karbala",
    "امامت": "beliefs",
    "فروع دین": "practices",
    "اصول دین": "beliefs",
    "حدیث": "texts",
    "دعا": "texts",
    "زیارت": "practices",
    "انتظار فرج": "beliefs",
    "تقلید (فقہ)": "practices",
    "توحید": "beliefs",
    "ولایت": "beliefs",
}

# The note titles that are the same topic as an existing article but whose
# wording differs (the note carries «علیہ السلام», the Wikipedia title does
# not). Key and value are compared after `normalize_title`.
MANUAL_MERGE: dict[str, str] = {
    "امام حسین علیہ السلام": "حسین بن علی",
    "امام موسی کاظم علیہ السلام": "موسی بن جعفر",
    "امام رضا علیہ السلام": "علی رضا",
    "حضرت فاطمہ زہرا سلام اللہ علیہا": "فاطمہ زہرا",
    "امام علی علیہ السلام": "علی بن ابی طالب",
    "امام حسن مجتبی علیہ السلام": "حسن ابن علی",
    "امام زین العابدین علیہ السلام": "زین العابدین",
    "امام محمد باقر علیہ السلام": "محمد باقر",
    "امام جعفر صادق علیہ السلام": "جعفر صادق",
    "امام محمد تقی علیہ السلام": "محمد تقی",
    "امام علی نقی علیہ السلام": "علی نقی",
    "امام حسن عسکری علیہ السلام": "حسن بن علی عسکری",
    "امام مہدی علیہ السلام": "محمد بن حسن مہدی",
    "حضرت زینب سلام اللہ علیہا": "زینب بنت علی",
}

DIACRITICS = re.compile(r"[\u064B-\u0652\u0670\u0640\u200c\u200d]")
SPACES = re.compile(r"[\s\u00a0]+")


def normalize_title(raw: str) -> str:
    """Fold a title enough to notice that two spellings mean the same page."""
    text = unicodedata.normalize("NFKC", raw or "")
    text = DIACRITICS.sub("", text)
    text = (
        text.replace("ہ", "ه")
        .replace("ی", "ي")
        .replace("ک", "ك")
        .replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
    )
    return SPACES.sub(" ", text).strip()


NORMALIZED_MANUAL_MERGE: dict[str, str] = {
    normalize_title(key): normalize_title(value) for key, value in MANUAL_MERGE.items()
}
NORMALIZED_GROUPS: dict[str, str] = {
    normalize_title(key): value for key, value in GROUP_BY_TITLE.items()
}


def clean_body(raw: str) -> str:
    """The notes are already prose; normalise whitespace and stray escapes."""
    text = (raw or "").replace("\r\n", "\n").replace("\r", "\n")
    text = (
        text.replace("\\u200c", "\u200c")
        .replace("\\u200d", "")
        .replace("\\u200e", "")
        .replace("\\u200f", "")
        .replace("\\u00a0", " ")
        .replace("\\n", "\n")
        .replace("\\t", " ")
    )
    lines = [SPACES.sub(" ", line).strip() for line in text.split("\n")]
    text = "\n".join(line for line in lines if line)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def excerpt_of(text: str, limit: int = 170) -> str:
    paragraph = next((p for p in text.split("\n\n") if len(p) >= 80), text.split("\n\n", 1)[0])
    paragraph = SPACES.sub(" ", paragraph).strip()
    if len(paragraph) <= limit:
        return paragraph
    cut = paragraph[:limit]
    space = cut.rfind(" ")
    return (cut[:space] if space > 40 else cut).rstrip(",، ") + "…"


def open_base(path: Path, workdir: Path) -> Path:
    """Expand the committed .gz (or accept a plain .db) into the workdir."""
    if path.suffix.lower() == ".gz":
        target = workdir / "base.db"
        with gzip.open(path, "rb") as packed, target.open("wb") as handle:
            shutil.copyfileobj(packed, handle, length=1024 * 1024)
        return target
    return path


def source_revision(row: sqlite3.Row) -> tuple[str, str, int]:
    """(revision_url, history_url, revision_id) for one Wikishia source row."""
    revision_url = (row["revision_url"] or "").strip()
    plain = (row["url"] or row["fetched_url"] or row["requested_url"] or "").strip()
    if not revision_url:
        revision_url = plain
    history_url = (row["fetched_url"] or plain or revision_url).strip()
    match = re.search(r"oldid=(\d+)", revision_url)
    revision_id = int(match.group(1)) if match else 0
    if revision_id == 0:
        try:
            revision_id = int(row["revision_id"] or 0)
        except (TypeError, ValueError):
            revision_id = 0
    return revision_url, history_url, revision_id


def merge(base_db: Path, notes_path: Path, output_db: Path) -> dict[str, int]:
    if output_db.exists():
        output_db.unlink()

    # Start from a copy of the reader edition, so every Wikipedia article,
    # reference, Imam row and curated topic stays byte-for-byte intact.
    shutil.copyfile(base_db, output_db)
    app = sqlite3.connect(output_db)
    app.row_factory = sqlite3.Row
    notes = sqlite3.connect(f"file:{notes_path.resolve().as_posix()}?mode=ro", uri=True)
    notes.row_factory = sqlite3.Row

    max_article = app.execute("SELECT MAX(id) FROM articles").fetchone()[0] or 0
    max_section = app.execute("SELECT MAX(id) FROM sections").fetchone()[0] or 0
    max_reference = app.execute("SELECT MAX(id) FROM source_references").fetchone()[0] or 0
    next_article = max_article + 1
    next_section = max_section + 1
    next_reference = max_reference + 1

    groups = {
        row["slug"]: row["id"]
        for row in app.execute("SELECT id, slug FROM groups")
    }
    if not groups:
        raise SystemExit("the base edition has no groups")

    # Title -> article id, and the set of existing headings per article, so a
    # second import never duplicates a section.
    by_title: dict[str, int] = {}
    display_title: dict[int, str] = {}
    for row in app.execute("SELECT id, title_ur FROM articles"):
        by_title.setdefault(normalize_title(row["title_ur"]), row["id"])
        display_title[row["id"]] = row["title_ur"]
    headings: dict[int, set[str]] = {}
    for row in app.execute("SELECT article_id, heading_ur FROM sections"):
        headings.setdefault(row["article_id"], set()).add(normalize_title(row["heading_ur"]))

    counts = {
        "merged_articles": 0,
        "new_articles": 0,
        "sections": 0,
        "references": 0,
        "related": 0,
        "aliases": 0,
        "skipped_notes": 0,
    }

    note_rows = notes.execute("SELECT * FROM articles ORDER BY article_id").fetchall()
    for note in note_rows:
        title = (note["title"] or "").strip()
        if not title:
            counts["skipped_notes"] += 1
            continue
        normalized = normalize_title(title)
        manual = NORMALIZED_MANUAL_MERGE.get(normalized)
        target_id = None
        if manual:
            target_id = by_title.get(manual)
        if target_id is None:
            target_id = by_title.get(normalized)

        # Sections of this note, with the exact revision URL of each.
        section_rows = notes.execute(
            "SELECT * FROM article_sections WHERE article_id = ? ORDER BY position",
            (note["article_id"],),
        ).fetchall()
        prepared_sections: list[tuple[str, str, str]] = []
        for section in section_rows:
            body = clean_body(section["body_urdu"])
            heading = (section["heading_urdu"] or "").strip() or "تعارف"
            if len(body) < 40:
                continue
            url_row = notes.execute(
                """
                SELECT s.* FROM section_sources ss
                JOIN sources s ON s.source_id = ss.source_id
                WHERE ss.section_id = ?
                ORDER BY CASE WHEN s.revision_url <> '' THEN 0 ELSE 1 END, s.source_id
                LIMIT 1
                """,
                (section["section_id"],),
            ).fetchone()
            url = source_revision(url_row)[0] if url_row else ""
            prepared_sections.append((heading, body, url))
        if not prepared_sections:
            counts["skipped_notes"] += 1
            continue

        # The note's own page and revision.
        source_row = notes.execute(
            """
            SELECT s.* FROM article_sources asrc
            JOIN sources s ON s.source_id = asrc.source_id
            WHERE asrc.article_id = ?
            ORDER BY CASE WHEN s.revision_url <> '' THEN 0 ELSE 1 END, s.source_id
            LIMIT 1
            """,
            (note["article_id"],),
        ).fetchone()
        if source_row is None:
            source_row = notes.execute(
                "SELECT * FROM sources WHERE title = ? OR requested_title = ? LIMIT 1",
                (title, title),
            ).fetchone()
        revision_url, history_url, revision_id = (
            source_revision(source_row) if source_row else ("", "", 0)
        )
        attribution = (
            f"ویکی شیعہ (ur.wikishia.net) — “{title}”"
            + (f"؛ revision {revision_id}" if revision_id else "")
            + (f"؛ {revision_url}" if revision_url else "")
            + "۔ اصل صفحے کا لنک ہر حصے کے ساتھ محفوظ ہے۔"
        )

        if target_id is not None:
            counts["merged_articles"] += 1
        else:
            slug = NORMALIZED_GROUPS.get(normalized, "other")
            group_id = groups.get(slug, groups.get("other"))
            if group_id is None:
                group_id = next(iter(groups.values()))
            body_all = "\n\n".join(text for _, text, _ in prepared_sections)
            target_id = next_article
            next_article += 1
            app.execute(
                """
                INSERT INTO articles(id, title_ur, title_search, group_id, source_url,
                  history_url, revision_id, character_count, excerpt, license_id, attribution)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    target_id,
                    title,
                    title,
                    group_id,
                    revision_url,
                    history_url,
                    revision_id,
                    len(body_all),
                    excerpt_of(body_all),
                    "source-attributed",
                    attribution,
                ),
            )
            by_title.setdefault(normalized, target_id)
            display_title[target_id] = title
            headings.setdefault(target_id, set())
            counts["new_articles"] += 1

        seen = headings.setdefault(target_id, set())
        ordinal = (
            app.execute(
                "SELECT COALESCE(MAX(ordinal), 0) FROM sections WHERE article_id = ?",
                (target_id,),
            ).fetchone()[0]
            or 0
        )
        for heading, body, url in prepared_sections:
            key = normalize_title(heading)
            if key in seen:
                continue
            seen.add(key)
            ordinal += 1
            app.execute(
                """
                INSERT INTO sections(id, article_id, ordinal, heading_ur, heading_level,
                  anchor, source_url, plain_text)
                VALUES (?,?,?,?,?,?,?,?)
                """,
                (
                    next_section,
                    target_id,
                    ordinal,
                    heading,
                    2,
                    f"wikishia-{note['article_id']}-{section_rows_position(prepared_sections, heading, body)}",
                    url,
                    body,
                ),
            )
            next_section += 1
            counts["sections"] += 1

        # External links cited by the note become the article's ماخذ list.
        for ref in notes.execute(
            """
            SELECT DISTINCT r.url AS url
            FROM article_sources asrc
            JOIN source_references r ON r.source_id = asrc.source_id
            WHERE asrc.article_id = ?
            ORDER BY r.reference_id
            """,
            (note["article_id"],),
        ):
            url = (ref["url"] or "").strip()
            if not url.startswith(("http://", "https://")):
                continue
            # The note's own title labels every citation, so it would be
            # noise; the URL itself is the permanent, checkable source.
            text = url
            app.execute(
                "INSERT INTO source_references(id, article_id, reference_anchor, reference_text, source_url)"
                " VALUES (?,?,?,?,?)",
                (next_reference, target_id, "", text[:420], url),
            )
            next_reference += 1
            counts["references"] += 1

        # «مزید پڑھیں»: resolve each linked title against the merged catalogue.
        for link in notes.execute(
            "SELECT linked_title FROM related_links WHERE article_id = ?",
            (note["article_id"],),
        ):
            linked = (link["linked_title"] or "").strip()
            if not linked:
                continue
            other = by_title.get(normalize_title(linked))
            if other is None or other == target_id:
                continue
            app.execute(
                "INSERT OR IGNORE INTO related_articles(source_article_id, target_article_id, target_title)"
                " VALUES (?,?,?)",
                (target_id, other, display_title.get(other, linked)),
            )
            counts["related"] += 1

        # Aliases from the dedup map keep the note findable by its other names.
        for alias in notes.execute(
            "SELECT alias_title FROM dedup_map WHERE article_id = ?",
            (note["article_id"],),
        ):
            name = (alias["alias_title"] or "").strip()
            if not name or name == title:
                continue
            app.execute(
                "INSERT OR IGNORE INTO aliases(alias, article_id) VALUES (?,?)",
                (name, target_id),
            )
            counts["aliases"] += 1

    # Recompute chapter counts from what the table really holds.
    app.execute(
        "UPDATE groups SET article_count = "
        "(SELECT COUNT(*) FROM articles a WHERE a.group_id = groups.id)"
    )

    article_count = app.execute("SELECT COUNT(*) FROM articles").fetchone()[0]
    section_count = app.execute("SELECT COUNT(*) FROM sections").fetchone()[0]
    reference_count = app.execute("SELECT COUNT(*) FROM source_references").fetchone()[0]
    meta_updates = {
        "title_ur": "اثنا عشری انسائکلوپیڈیا",
        "title_latin": "Twelver Shia Urdu Encyclopedia",
        "source": (
            "ur.wikipedia.org — curated Twelver Shia selection; "
            "ur.wikishia.net — detailed topic notes"
        ),
        "attribution": (
            "Urdu Wikipedia contributors and Wikishia (ur.wikishia.net) contributors; "
            "every article, section and reference keeps the exact page/revision it came from."
        ),
        "wikishia_notes": (
            f"{counts['new_articles']} new topic notes, {counts['merged_articles']} notes "
            "appended to existing articles, each section carrying its own revision URL"
        ),
        "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "article_count": str(article_count),
        "section_count": str(section_count),
        "reference_count": str(reference_count),
    }
    for key, value in meta_updates.items():
        app.execute(
            "INSERT INTO metadata(key, value) VALUES (?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, value),
        )

    app.commit()
    app.execute("VACUUM")
    app.execute("ANALYZE")
    app.commit()

    problem = app.execute("PRAGMA quick_check").fetchone()[0]
    foreign = app.execute("PRAGMA foreign_key_check").fetchall()
    app.close()
    notes.close()
    if problem != "ok":
        raise SystemExit(f"quick_check failed: {problem}")
    if foreign:
        raise SystemExit(f"foreign key violations: {foreign[:5]}")
    counts.update(
        articles=article_count,
        sections_total=section_count,
        references_total=reference_count,
        bytes=output_db.stat().st_size,
    )
    return counts


def section_rows_position(
    prepared: list[tuple[str, str, str]], heading: str, body: str
) -> int:
    """Stable anchor component: the 1-based position of the section in the note."""
    for index, (candidate_heading, candidate_body, _) in enumerate(prepared, start=1):
        if candidate_heading == heading and candidate_body == body:
            return index
    return 0


def gzip_file(source: Path, target: Path) -> None:
    """Write a deterministic .gz (no timestamp, no original file name)."""
    with source.open("rb") as raw, target.open("wb") as out:
        with gzip.GzipFile(filename="", mode="wb", fileobj=out, mtime=0, compresslevel=9) as packed:
            shutil.copyfileobj(raw, packed, length=1024 * 1024)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base",
        type=Path,
        default=ROOT / "assets" / "athna_ashari_encyclopedia.db.gz",
    )
    parser.add_argument(
        "--notes",
        type=Path,
        default=ROOT / "google_drive" / "wikishia_urdu_twelver_detailed_notes(1).sqlite",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "assets" / "athna_ashari_encyclopedia.db.gz",
    )
    parser.add_argument(
        "--keep-db",
        action="store_true",
        help="Leave the expanded .db next to the output (build artefact).",
    )
    args = parser.parse_args()
    for path in (args.base, args.notes):
        if not path.is_file():
            parser.error(f"not found: {path}")

    workdir = Path(tempfile.mkdtemp(prefix="wikishia-merge-"))
    try:
        base_db = open_base(args.base, workdir)
        expanded = args.output.with_suffix("")  # assets/…db
        counts = merge(base_db, args.notes, expanded)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        gzip_file(expanded, args.output)
        if not args.keep_db:
            expanded.unlink()
        print(
            f"{args.output}: {counts['articles']} articles "
            f"({counts['new_articles']} new, {counts['merged_articles']} merged), "
            f"{counts['sections_total']} sections (+{counts['sections']}), "
            f"{counts['references_total']} references (+{counts['references']}), "
            f"+{counts['related']} related links, +{counts['aliases']} aliases, "
            f"{args.output.stat().st_size / 1048576:.1f} MB gzipped"
        )
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

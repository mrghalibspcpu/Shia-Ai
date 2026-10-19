#!/usr/bin/env python3
"""Merge the Urdu detailed-notes SQLite export into the app encyclopedia.

The import is additive: existing articles, prose and sources stay intact;
matching titles gain the imported notes as additional sections, and new titles
are assigned to one of the existing ten library shelves. Every imported
section and source retains its own direct URL.

    python3 scripts/merge_encyclopedia_notes.py \
      --notes 'google_drive/wikishia_urdu_twelver_detailed_notes(1).sqlite' \
      --base assets/athna_ashari_encyclopedia_v2.db.gz \
      --output assets/athna_ashari_encyclopedia_v2.db
"""
from __future__ import annotations

import argparse
import gzip
import shutil
import sqlite3
import unicodedata
from pathlib import Path


def norm(value: str) -> str:
    return "".join(ch for ch in unicodedata.normalize("NFKC", value) if not ch.isspace() and ch not in "\u200c\u200d\u200e\u200f\ufeff")


def assign_group(title: str, topic_labels: list[str]) -> int:
    text = f"{title} {' '.join(topic_labels)}"
    folded = norm(text)
    if "امام" in title and any(term in title for term in ("علیہ السلام", "علیہ", "مہدی")):
        return 1
    if any(term in text for term in ("کربلا", "اہل بیت", "فاطمہ", "زینب", "سیدہ", "کوفہ", "عاشورا", "شہادت")):
        return 2
    if any(term in text for term in ("عبادت", "نماز", "زیارت", "دعا", "خمس", "تقلید", "عزاداری", "فقہ", "روزہ", "حج")):
        return 4
    if any(term in text for term in ("کتاب", "حدیث", "قرآن", "صحیفہ", "نہج البلاغہ", "مقتل")):
        return 5
    if any(term in text for term in ("شیخ", "سید", "علما", "عالم", "عالمہ", "محدث", "مؤلف", "مرجع")):
        return 6
    if any(term in text for term in ("مسجد", "قم", "مقام", "مزار", "مدینہ", "مکہ", "حیطان")):
        return 7
    if any(term in text for term in ("تاریخ", "جنگ", "سقیفہ", "قیام", "تاریخی", "واقعہ", "غیبت")):
        return 8
    if any(term in text for term in ("ادارہ", "حوزہ", "تنظیم", "مدرسہ")):
        return 9
    if any(term in text for term in ("عقیدہ", "توحید", "امامت", "نبوت", "اصول دین", "عدل", "ولایت", "رجعت")):
        return 3
    # Keep generic people in the biographies shelf and avoid an unclassified
    # section; this mirrors how the existing selected encyclopedia is curated.
    return 6 if any(term in folded for term in ("بن", "خاتون", "غفاری")) else 10


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True, help="gzipped app-edition encyclopedia")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not args.notes.is_file() or not args.base.is_file():
        raise SystemExit("Both source SQLite files must exist.")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(args.base, "rb") as source, args.output.open("wb") as target:
        shutil.copyfileobj(source, target)

    app = sqlite3.connect(args.output)
    source = sqlite3.connect(f"file:{args.notes.resolve()}?mode=ro", uri=True)
    app.execute("PRAGMA foreign_keys=ON")
    app.execute("PRAGMA journal_mode=DELETE")
    try:
        # This import is safe to rerun: remove only rows tagged by this source
        # before repopulating; no existing encyclopedia row is deleted.
        app.execute("CREATE TABLE IF NOT EXISTS imported_note_articles (article_id INTEGER PRIMARY KEY)")
        app.execute("CREATE TABLE IF NOT EXISTS imported_note_links (owner_id INTEGER NOT NULL, target_title TEXT NOT NULL, PRIMARY KEY(owner_id,target_title))")
        # Clear only artifacts from the previous run, including sections and
        # references merged into an article that already existed in the base.
        app.execute("DELETE FROM sections WHERE anchor LIKE 'drive-note-%'")
        app.execute("DELETE FROM source_references WHERE reference_anchor LIKE 'imported-note-%'")
        app.execute("DELETE FROM related_articles WHERE (source_article_id,target_title) IN (SELECT owner_id,target_title FROM imported_note_links)")
        app.execute("DELETE FROM imported_note_links")
        prior = [row[0] for row in app.execute("SELECT article_id FROM imported_note_articles")]
        for article_id in prior:
            app.execute("DELETE FROM articles WHERE id=?", (article_id,))
        app.execute("DELETE FROM imported_note_articles")
        app.commit()

        group_ids = {row[1]: row[0] for row in app.execute("SELECT id,slug FROM groups")}
        existing = {norm(title): article_id for article_id, title in app.execute("SELECT id,title_ur FROM articles")}
        max_article = app.execute("SELECT COALESCE(MAX(id),0) FROM articles").fetchone()[0]
        max_section = app.execute("SELECT COALESCE(MAX(id),0) FROM sections").fetchone()[0]
        max_reference = app.execute("SELECT COALESCE(MAX(id),0) FROM source_references").fetchone()[0]
        article_ids: dict[int, int] = {}
        added_articles = added_sections = merged_titles = added_references = 0

        for article_id, title, summary in source.execute("SELECT article_id,title,summary_urdu FROM articles ORDER BY article_id"):
            source_rows = source.execute("""
                SELECT s.source_id, COALESCE(s.title,s.requested_title,''),
                       COALESCE(NULLIF(s.revision_url,''),NULLIF(s.url,''),s.requested_url),
                       COALESCE(s.revision_id,'')
                FROM article_sources x JOIN sources s ON s.source_id=x.source_id
                WHERE x.article_id=? ORDER BY s.source_id
            """, (article_id,)).fetchall()
            primary_url = next((r[2] for r in source_rows if r[2]), "")
            revision = next((r[3] for r in source_rows if r[3]), "")
            existing_id = existing.get(norm(title))
            if existing_id is not None:
                target_id = existing_id
                merged_titles += 1
            else:
                labels = [r[0] for r in source.execute("""
                    SELECT t.label_urdu FROM topics t JOIN article_topics x ON x.topic_id=t.topic_id
                    WHERE x.article_id=? ORDER BY t.topic_id
                """, (article_id,))]
                group_id = assign_group(title, labels)
                max_article += 1
                target_id = max_article
                revision_int = int(revision) if revision.isdigit() else 0
                text_count = sum(len(row[0] or "") for row in source.execute(
                    "SELECT heading_urdu FROM article_sections WHERE article_id=?", (article_id,))) + sum(
                    len(row[0] or "") for row in source.execute(
                        "SELECT body_urdu FROM article_sections WHERE article_id=?", (article_id,)))
                app.execute("""
                    INSERT INTO articles(id,title_ur,title_search,group_id,source_url,history_url,
                      revision_id,character_count,excerpt,license_id,attribution)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?)
                """, (target_id, title, norm(title), group_id, primary_url, primary_url,
                      revision_int, text_count, summary, "CC-BY-SA-4.0",
                      "ویکی شیعہ اردو اور فراہم کردہ تفصیلی نوٹس"))
                app.execute("INSERT INTO imported_note_articles(article_id) VALUES(?)", (target_id,))
                existing[norm(title)] = target_id
                added_articles += 1
            article_ids[article_id] = target_id

            next_ordinal = app.execute(
                "SELECT COALESCE(MAX(ordinal),0)+1 FROM sections WHERE article_id=?", (target_id,)
            ).fetchone()[0]
            for position, heading, body in source.execute("""
                SELECT position,heading_urdu,body_urdu FROM article_sections
                WHERE article_id=? ORDER BY position
            """, (article_id,)):
                if not (body or "").strip():
                    continue
                source_link = source.execute("""
                    SELECT source_url FROM section_sources WHERE section_id=(
                      SELECT section_id FROM article_sections WHERE article_id=? AND position=?
                    ) ORDER BY source_id LIMIT 1
                """, (article_id, position)).fetchone()
                if not source_link or not source_link[0]:
                    source_link = (primary_url,)
                max_section += 1
                app.execute("""
                    INSERT INTO sections(id,article_id,ordinal,heading_ur,heading_level,anchor,source_url,plain_text)
                    VALUES(?,?,?,?,?,?,?,?)
                """, (max_section, target_id, next_ordinal, heading or "تفصیلی نوٹ", 2,
                      f"drive-note-{article_id}-{position}", source_link[0], body))
                next_ordinal += 1
                added_sections += 1

            # The entry's page and all directly linked sources are kept as
            # clickable end-of-article references. Deduplicate by URL/title.
            reference_candidates = list(source_rows)
            for source_id, ref_url in source.execute("""
                SELECT r.source_id,r.url FROM article_sources a
                JOIN source_references r ON r.source_id=a.source_id WHERE a.article_id=?
                ORDER BY r.reference_id
            """, (article_id,)):
                if ref_url:
                    source_title = next((r[1] for r in source_rows if r[0] == source_id), "ماخذ")
                    reference_candidates.append((source_id, source_title, ref_url, ""))
            seen: set[tuple[str, str]] = set()
            for _, ref_title, ref_url, _ in reference_candidates:
                ref_title = (ref_title or title).strip()
                if not ref_url or (ref_title, ref_url) in seen:
                    continue
                seen.add((ref_title, ref_url))
                # Existing-page overlaps still gain the new corpus reference.
                duplicate = app.execute(
                    "SELECT 1 FROM source_references WHERE article_id=? AND reference_text=? AND source_url=? LIMIT 1",
                    (target_id, ref_title, ref_url),
                ).fetchone()
                if duplicate:
                    continue
                max_reference += 1
                app.execute("""
                    INSERT INTO source_references(id,article_id,reference_anchor,reference_text,source_url)
                    VALUES(?,?,?,?,?)
                """, (max_reference, target_id, f"imported-note-{article_id}-{max_reference}", ref_title, ref_url))
                added_references += 1

        # Import only links originating in the supplied 95-article set; link
        # titles and their direct URLs remain available even when no local
        # article can be resolved.
        for old_id, linked_title, url, related_id in source.execute("""
            SELECT article_id,linked_title,url,related_article_id FROM related_links ORDER BY link_id
        """):
            owner_id = article_ids[old_id]
            target_id = article_ids.get(related_id) if related_id is not None else None
            label = (linked_title or "").strip()
            if not label:
                label = url
            # Avoid creating huge duplicate topic link lists.
            if app.execute("""SELECT 1 FROM related_articles
                WHERE source_article_id=? AND target_title=? LIMIT 1""", (owner_id,label)).fetchone():
                continue
            app.execute("INSERT INTO related_articles(source_article_id,target_article_id,target_title) VALUES(?,?,?)",
                        (owner_id,target_id,label))
            app.execute("INSERT OR IGNORE INTO imported_note_links(owner_id,target_title) VALUES(?,?)",
                        (owner_id,label))

        for group_id, in app.execute("SELECT id FROM groups"):
            count = app.execute("SELECT COUNT(*) FROM articles WHERE group_id=?", (group_id,)).fetchone()[0]
            app.execute("UPDATE groups SET article_count=? WHERE id=?", (count,group_id))
        # The app builds its cross-book search index from article sections at
        # first launch; the source-only FTS virtual table is not needed.
        app.commit()
        integrity = app.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {integrity}")
        print(f"Added {added_articles} articles; merged into {merged_titles} existing titles; "
              f"added {added_sections} source-linked sections and {added_references} references.")
        print("Totals:", app.execute("SELECT COUNT(*) FROM articles").fetchone()[0], "articles,",
              app.execute("SELECT COUNT(*) FROM sections").fetchone()[0], "sections")
    finally:
        source.close()
        app.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

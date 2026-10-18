#!/usr/bin/env python3
"""Recount community_stats/ and rewrite stats.json (privacy-safe aggregates).

Counts anonymous install records in community_stats/installs/ (lines or files
containing `SV-XXXXXX | installed: ... | last_active: ... | status: active`)
and preserves global_zikr_total unless --global-zikr is given.
Run from the repo root:  python3 scripts/update_community_stats.py [--global-zikr N]
"""
import argparse, datetime, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "community_stats"

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--global-zikr", type=int, default=None,
                    help="set the worldwide Tasbeeh zikr total (default: keep current)")
    args = ap.parse_args()
    stats_path = FOLDER / "stats.json"
    current = json.loads(stats_path.read_text()) if stats_path.exists() else {}
    total = active = 0
    seen = set()
    for path in sorted((FOLDER / "installs").rglob("*")):
        if not path.is_file() or path.name == "README.md":
            continue
        for line in path.read_text(errors="replace").splitlines():
            m = re.search(r"(SV-[A-Z0-9]+)", line)
            if not m or m.group(1) in seen:
                continue
            seen.add(m.group(1)); total += 1
            if "status: removed" not in line:
                active += 1
    stats = {
        "total_installs": total,
        "active_users": active,
        "global_zikr_total": args.global_zikr if args.global_zikr is not None else int(current.get("global_zikr_total", 0)),
        "updated_at": datetime.date.today().isoformat(),
        "note": current.get("note", "Privacy-safe public counters for ShiaVerse."),
    }
    stats_path.write_text(json.dumps(stats, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(stats, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()

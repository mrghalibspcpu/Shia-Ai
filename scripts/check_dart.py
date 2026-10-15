#!/usr/bin/env python3
"""Offline guard for the Flutter client when the Dart SDK is unavailable.

``flutter analyze`` remains the real check in CI. This script is a fast, local
second line of defence: it parses every Dart file with tree-sitter-dart and
reports syntax errors, unresolved project imports, and references to symbols
that no longer exist.

Usage::

    python3 scripts/check_dart.py            # check app/lib and app/test
    python3 scripts/check_dart.py --verbose  # also print per-file status

Requires ``pip install tree-sitter tree-sitter-dart``. Without those packages the
script still runs the import/symbol checks and says the grammar was skipped.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "app"

# Symbols that were removed together with the AI integration. Any new reference
# means a screen was wired back to deleted code.
FORBIDDEN_SYMBOLS = (
    "AiRepository",
    "GeminiClient",
    "AiChatScreen",
    "AiSource",
    "ChatMessage",
    "looksLikeGeminiApiKey",
    "stripModelMarkup",
    "noMatchMessage",
    "localGroundedAnswer",
    "kGeminiModelFallbacks",
    "SHIA_AI_API_BASE_URL",
)

STRIP_PATTERNS = (
    re.compile(r"//[^\n]*"),
    re.compile(r"/\*.*?\*/", re.DOTALL),
    re.compile(r"r?'(?:\\.|[^'\\\n])*'"),
    re.compile(r'r?"(?:\\.|[^"\\\n])*"'),
    re.compile(r"r'''(?:.|[^'])*?'''", re.DOTALL),
    re.compile(r'r?"""(?:.|[^"])*?"""', re.DOTALL),
)


def strip_noise(source: str) -> str:
    """Remove comments and string literals so symbol scans do not false-positive."""
    text = source
    for pattern in (STRIP_PATTERNS[2], STRIP_PATTERNS[3], STRIP_PATTERNS[4], STRIP_PATTERNS[5]):
        text = pattern.sub("''", text)
    text = STRIP_PATTERNS[1].sub("", text)
    text = STRIP_PATTERNS[0].sub("", text)
    return text


def dart_files() -> list[Path]:
    return sorted(
        path
        for base in (APP_DIR / "lib", APP_DIR / "test")
        for path in base.rglob("*.dart")
    )


def check_syntax(paths: list[Path]) -> tuple[int, bool]:
    try:
        import tree_sitter
        import tree_sitter_dart
    except ImportError:
        print("SKIP tree-sitter-dart is not installed; syntax parsing was not run")
        return 0, False

    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_dart.language()))
    errors = 0
    for path in paths:
        tree = parser.parse(path.read_bytes())
        if not tree.root_node.has_error:
            continue
        errors += 1
        print(f"SYNTAX ERROR {path.relative_to(ROOT)}")
        for node in _error_nodes(tree.root_node):
            line = node.start_point[0] + 1
            snippet = path.read_text(encoding="utf-8", errors="replace").splitlines()[line - 1]
            print(f"  line {line}: {snippet.strip()[:140]}")
    return errors, True


def _error_nodes(node, limit: int = 5) -> list:
    found = []
    stack = [node]
    while stack and len(found) < limit:
        current = stack.pop()
        if current.type == "ERROR" or current.is_missing:
            found.append(current)
            continue
        stack.extend(current.children)
    return found


def check_imports(paths: list[Path]) -> int:
    errors = 0
    package_name = "shia_ai"
    for path in paths:
        source = path.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(r"""import\s+'([^']+)'""", source):
            target = match.group(1)
            if target.startswith("dart:"):
                continue
            if target.startswith("package:flutter/") or target.startswith("package:flutter_test"):
                continue
            if target.startswith(f"package:{package_name}/"):
                resolved = APP_DIR / "lib" / target.split("/", 1)[1]
            elif target.startswith("package:"):
                continue  # third-party packages are resolved by pub
            else:
                resolved = (path.parent / target).resolve()
            if not resolved.is_file():
                errors += 1
                print(f"UNRESOLVED IMPORT {path.relative_to(ROOT)}: {target}")
    return errors


DECL_RE = re.compile(
    r"""^(?:class|abstract\s+class|enum|mixin|extension(?:\s+type)?|sealed\s+class|base\s+class)\s+([A-Z][A-Za-z0-9_]*)""",
    re.MULTILINE,
)
#: Top-level values, typed or untyped: ``const kGold = ...`` and
#: ``const Color kGold = ...`` both export ``kGold``. Missing the typed form
#: made the unused-import check report a file as dead when the only symbol it
#: used was, say, ``kArabicFont``.
TOPLEVEL_VALUE_RE = re.compile(
    r"""^(?:const|final|var|late\s+final|late\s+var)\s+"""
    r"""(?:[A-Za-z_][A-Za-z0-9_<>,.\s?]*?\s+)?([a-z_][A-Za-z0-9_]*)\s*[=;]""",
    re.MULTILINE,
)
TOPLEVEL_FUNC_RE = re.compile(
    r"""^(?:[A-Za-z_][A-Za-z0-9_<>,\s?\.\[\]]*?)\b([a-z_][A-Za-z0-9_]*)\s*\(""",
    re.MULTILINE,
)
EXPORT_RE = re.compile(r"""export\s+'([^']+)'(?:\s+show\s+([^;]+))?;""")
IMPORT_RE = re.compile(r"""import\s+'([^']+)'((?:\s+(?:as|show|hide)\s+[^;]+)*)\s*;""")


def resolve_project_import(uri: str, importer: Path) -> Path | None:
    """Map a Dart import URI onto a file in this repository, or None."""
    if uri.startswith("dart:") or uri.startswith("package:flutter"):
        return None
    if uri.startswith("package:shia_ai/"):
        return (APP_DIR / "lib" / uri.split("/", 1)[1]).resolve()
    if uri.startswith("package:"):
        return None  # resolved by pub, not by this script
    resolved = (importer.parent / uri).resolve()
    return resolved if resolved.is_file() else None


def exported_names(path: Path, depth: int = 0) -> set[str]:
    """Public names a file makes visible to importers, including re-exports."""
    if depth > 4 or not path.is_file():
        return set()
    source = path.read_text(encoding="utf-8", errors="replace")
    text = strip_noise(source)
    names = set(DECL_RE.findall(text))
    names |= set(TOPLEVEL_VALUE_RE.findall(text))
    names |= set(TOPLEVEL_FUNC_RE.findall(text))
    for target, shown in EXPORT_RE.findall(source):
        resolved = (path.parent / target).resolve()
        if shown:
            names |= {name.strip() for name in shown.split(",") if name.strip()}
        else:
            names |= exported_names(resolved, depth + 1)
    return names


def identifiers_in(source: str) -> set[str]:
    """Identifiers in a file, keeping the code inside ``${...}`` interpolations.

    ``strip_noise`` blanks whole string literals, which would hide an import used
    only inside an interpolated string (``'${formatBytes(n)}'``).
    """
    def keep_interpolations(match: re.Match[str]) -> str:
        inner = "".join(re.findall(r"\$\{[^}]*\}", match.group(0)))
        return f"'{inner}'"

    text = source
    for pattern in (STRIP_PATTERNS[2], STRIP_PATTERNS[3], STRIP_PATTERNS[4], STRIP_PATTERNS[5]):
        text = pattern.sub(keep_interpolations, text)
    text = STRIP_PATTERNS[1].sub("", text)
    text = STRIP_PATTERNS[0].sub("", text)
    return set(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))


def check_unused_imports(paths: list[Path]) -> int:
    """Flag project imports that contribute no referenced symbol.

    ``flutter analyze`` reports these as ``unused_import`` warnings and fails the
    build, so catch them without the Dart SDK too.
    """
    errors = 0
    for path in paths:
        source = path.read_text(encoding="utf-8", errors="replace")
        identifiers = identifiers_in(source)
        for uri, clauses in IMPORT_RE.findall(source):
            if clauses.strip():
                continue  # explicit show/hide/as: trust the author and analyze
            resolved = resolve_project_import(uri, path)
            if resolved is None:
                continue
            names = exported_names(resolved)
            if not names:
                continue
            if not (names & identifiers):
                errors += 1
                print(
                    f"UNUSED IMPORT {path.relative_to(ROOT)}: {uri} "
                    f"(none of {len(names)} exported names referenced)"
                )
    return errors


#: Well-known SDK symbols and the library that provides them. Without the Dart
#: SDK these are invisible locally but ``flutter analyze`` fails the build with
#: ``undefined_identifier`` when the import is missing (this exact mistake once
#: shipped: ``utf8.decode`` without ``dart:convert``).
SDK_SYMBOLS = {
    "utf8": "dart:convert",
    "jsonDecode": "dart:convert",
    "jsonEncode": "dart:convert",
    "base64Encode": "dart:convert",
    "base64Decode": "dart:convert",
}


def check_sdk_imports(paths: list[Path]) -> int:
    """Flag uses of well-known SDK symbols whose library is not imported."""
    errors = 0
    for path in paths:
        source = path.read_text(encoding="utf-8", errors="replace")
        imported = {uri for uri, _clauses in IMPORT_RE.findall(source)}
        text = strip_noise(source)
        for symbol, library in SDK_SYMBOLS.items():
            if library in imported:
                continue
            if re.search(rf"\b{re.escape(symbol)}\b", text):
                errors += 1
                print(
                    f"MISSING IMPORT {path.relative_to(ROOT)}: '{symbol}' "
                    f"needs import '{library}';"
                )
    return errors


def check_forbidden(paths: list[Path]) -> int:
    errors = 0
    for path in paths:
        text = strip_noise(path.read_text(encoding="utf-8", errors="replace"))
        for symbol in FORBIDDEN_SYMBOLS:
            if re.search(rf"\b{re.escape(symbol)}\b", text):
                errors += 1
                print(f"REMOVED SYMBOL {path.relative_to(ROOT)}: {symbol}")
    return errors


def check_balance(paths: list[Path]) -> int:
    errors = 0
    for path in paths:
        text = strip_noise(path.read_text(encoding="utf-8", errors="replace"))
        for open_char, close_char in (("{", "}"), ("(", ")"), ("[", "]")):
            delta = text.count(open_char) - text.count(close_char)
            if delta != 0:
                errors += 1
                print(
                    f"UNBALANCED {open_char}{close_char} in {path.relative_to(ROOT)} "
                    f"(off by {delta})"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    paths = dart_files()
    if not paths:
        print("No Dart files found under app/lib or app/test")
        return 1

    syntax_errors, parsed = check_syntax(paths)
    total = syntax_errors
    total += check_imports(paths)
    total += check_unused_imports(paths)
    total += check_sdk_imports(paths)
    total += check_forbidden(paths)
    total += check_balance(paths)

    if args.verbose:
        for path in paths:
            print(f"  checked {path.relative_to(ROOT)}")
    print(
        f"{len(paths)} Dart files checked"
        f"{'' if parsed else ' (syntax parsing skipped)'}: "
        f"{'no problems found' if total == 0 else f'{total} problem(s) found'}"
    )
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())

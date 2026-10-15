#!/usr/bin/env python3
"""Builds ``app/assets/geo/cities.tsv.gz`` — the offline place list behind the
prayer-times location picker and the "which town am I in" lookup of a GPS fix.

The data is GeoNames (https://www.geonames.org, CC BY 4.0), taken from two
PyPI packages so the build needs nothing but the package index:

* ``geonamescache`` — the GeoNames ``cities500`` / ``cities5000`` dumps;
* ``reverse_geocoder`` — ``rg_cities1000.csv``, used only to turn GeoNames'
  numeric province codes into names ("04" → "Punjab").

Selection: every place with ~500+ people in the countries most readers live in
(South Asia, the Gulf, Iran, Iraq, the Levant, Central Asia), and every town of
~5000+ people everywhere else. Anything smaller is still reachable through the
picker's online search.

Format (UTF-8, gzip, one place per line, biggest population first)::

    #shiaverse-cities<TAB>1<TAB><count>
    #c<TAB>PK<TAB>Pakistan                       (one line per country)
    name<TAB>country<TAB>province<TAB>lat<TAB>lon<TAB>population

``name`` is folded to ASCII ("Muzaffarābād" → "Muzaffarabad") so the picker can
match what people type on an English keyboard.

Usage::

    python3 scripts/build_city_index.py            # downloads the two packages
    python3 scripts/build_city_index.py --cache /tmp/geo-cache
"""
from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import tarfile
import unicodedata
import urllib.request
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "app" / "assets" / "geo" / "cities.tsv.gz"

GEONAMESCACHE_WHEEL = (
    "https://files.pythonhosted.org/packages/48/c2/"
    "52f1b29de8839b4b55cd2641dfd722a6a94953d74fa82514e26084a92318/"
    "geonamescache-3.0.2-py3-none-any.whl"
)
REVERSE_GEOCODER_SDIST = (
    "https://files.pythonhosted.org/packages/0b/0f/"
    "b7d5d4b36553731f11983e19e1813a1059ad0732c5162c01b3220c927d31/"
    "reverse_geocoder-1.5.1.tar.gz"
)

#: Countries listed down to villages of ~500 people.
DENSE_COUNTRIES = frozenset(
    "PK IN AF IR IQ SA AE BH KW QA OM YE SY LB JO AZ BD TJ UZ TM KG NP LK".split()
)

FOLD = str.maketrans({
    "ı": "i", "İ": "I", "ø": "o", "Ø": "O", "ß": "ss", "æ": "ae", "Æ": "AE",
    "đ": "d", "Đ": "D", "ł": "l", "Ł": "L", "ð": "d", "Ð": "D", "þ": "th",
    "œ": "oe", "Œ": "OE", "ħ": "h", "Ħ": "H", "ə": "e", "Ə": "E",
    "‘": "'", "’": "'", "ʻ": "'", "ʼ": "'", "ʿ": "'", "ʾ": "'", "–": "-", "—": "-",
})


def ascii_fold(value: str) -> str:
    text = value.translate(FOLD)
    text = "".join(ch for ch in unicodedata.normalize("NFKD", text) if not unicodedata.combining(ch))
    return " ".join(text.split())


def fetch(url: str, cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / url.rsplit("/", 1)[-1]
    if not target.exists():
        print(f"downloading {target.name}")
        with urllib.request.urlopen(url, timeout=120) as response:
            target.write_bytes(response.read())
    return target


def load_geonamescache(wheel: Path, name: str) -> dict:
    with zipfile.ZipFile(wheel) as archive:
        return json.loads(archive.read(f"geonamescache/data/{name}.json"))


def load_rg_rows(sdist: Path) -> list[dict]:
    with tarfile.open(sdist) as archive:
        member = next(m for m in archive.getmembers() if m.name.endswith("rg_cities1000.csv"))
        raw = archive.extractfile(member).read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(raw)))


def province_names(cities: dict, rg_rows: list[dict]) -> dict[tuple[str, str], str]:
    """(country, GeoNames admin1 code) → province name, by majority vote."""
    by_name: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for row in rg_rows:
        by_name[(row["cc"], ascii_fold(row["name"]).lower())].append(row)
    votes: dict[tuple[str, str], Counter] = defaultdict(Counter)
    for city in cities.values():
        code = city.get("admin1code") or ""
        if not code:
            continue
        key = (city["countrycode"], ascii_fold(city["name"]).lower())
        for row in by_name.get(key, ()):
            if abs(float(row["lat"]) - city["latitude"]) < 0.08 and abs(float(row["lon"]) - city["longitude"]) < 0.08:
                if row["admin1"]:
                    votes[(city["countrycode"], code)][row["admin1"]] += 1
    return {key: counter.most_common(1)[0][0] for key, counter in votes.items()}


def round_population(value: int) -> int:
    if value < 100:
        return value
    digits = len(str(value)) - 2
    return int(round(value / 10 ** digits) * 10 ** digits)


def build(cache: Path) -> tuple[list[str], list[str]]:
    wheel = fetch(GEONAMESCACHE_WHEEL, cache)
    sdist = fetch(REVERSE_GEOCODER_SDIST, cache)
    dense = load_geonamescache(wheel, "cities500")
    sparse = load_geonamescache(wheel, "cities5000")
    rg_rows = load_rg_rows(sdist)
    provinces = province_names(dense, rg_rows)

    chosen: dict[str, dict] = {}
    for gid, city in dense.items():
        if city["countrycode"] in DENSE_COUNTRIES:
            chosen[gid] = city
    for gid, city in sparse.items():
        chosen.setdefault(gid, city)

    # One row per (name, country) within ~2 km: GeoNames lists a few places
    # twice (a town and its tehsil seat at the same coordinates).
    places = sorted(chosen.values(), key=lambda c: (-c["population"], c["geonameid"]))
    kept: list[dict] = []
    seen: dict[tuple[str, str], list[tuple[float, float]]] = defaultdict(list)
    for city in places:
        name = ascii_fold(city["name"])
        if not name or "\t" in name:
            continue
        key = (name.lower(), city["countrycode"])
        lat, lon = city["latitude"], city["longitude"]
        if any(abs(lat - a) < 0.02 and abs(lon - b) < 0.02 for a, b in seen[key]):
            continue
        seen[key].append((lat, lon))
        kept.append(city)

    countries = {
        code: info.get("name", code)
        for code, info in json.loads(zipfile.ZipFile(wheel).read("geonamescache/data/countries.json")).items()
    }
    used = sorted({city["countrycode"] for city in kept})
    header = [f"#c\t{code}\t{ascii_fold(countries.get(code, code))}" for code in used]

    lines = []
    for city in kept:
        province = provinces.get((city["countrycode"], city.get("admin1code") or ""), "")
        lines.append(
            "\t".join(
                (
                    ascii_fold(city["name"]),
                    city["countrycode"],
                    ascii_fold(province),
                    f"{city['latitude']:.3f}",
                    f"{city['longitude']:.3f}",
                    str(round_population(int(city["population"] or 0))),
                )
            )
        )
    return header, lines


def write(header: list[str], lines: list[str], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    body = "\n".join([f"#shiaverse-cities\t1\t{len(lines)}", *header, *lines]) + "\n"
    buffer = io.BytesIO()
    # mtime=0 keeps the archive byte-identical between runs.
    with gzip.GzipFile(filename="", mode="wb", fileobj=buffer, compresslevel=9, mtime=0) as handle:
        handle.write(body.encode("utf-8"))
    output.write_bytes(buffer.getvalue())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=Path("/tmp/shiaverse-geo-cache"))
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    header, lines = build(args.cache)
    write(header, lines, args.output)
    countries = Counter(line.split("\t")[1] for line in lines)
    print(f"{len(lines)} places, {len(countries)} countries, PK={countries['PK']} → {args.output}")
    print(f"size: {args.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()

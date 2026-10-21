#!/usr/bin/env python3
"""Give every APK the same Android versionCode, then re-sign if it changed.

Flutter's ``--split-per-abi`` adds ``abi * 1000`` to the version code. A
phone that already has the arm64 split (code 2036 for 1.26.0) then refuses
a later universal or 32-bit APK as "package appears to be invalid". This
rewrites the binary manifest's versionCode and re-signs so every file can
replace that install.
"""

from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

RES_STRING_POOL_TYPE = 0x0001
RES_XML_TYPE = 0x0003
RES_XML_START_ELEMENT_TYPE = 0x0102
RES_XML_END_ELEMENT_TYPE = 0x0103
RES_XML_CDATA_TYPE = 0x0104
TYPE_INT_DEC = 0x10


def _u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def _decode_pool_string(data: bytes, strings_start: int, offset: int, utf8: bool) -> str:
    pos = strings_start + offset
    if utf8:
        # Two length fields: UTF-16 length, then UTF-8 length. Each is one
        # byte, or two when the high bit is set.
        def take_len() -> int:
            nonlocal pos
            first = data[pos]
            pos += 1
            if first & 0x80:
                second = data[pos]
                pos += 1
                return ((first & 0x7F) << 8) | second
            return first

        take_len()
        utf8_len = take_len()
        raw = data[pos : pos + utf8_len]
        return raw.decode("utf-8", errors="replace")
    char_len = _u16(data, pos)
    pos += 2
    if char_len & 0x8000:
        char_len = ((char_len & 0x7FFF) << 16) | _u16(data, pos)
        pos += 2
    raw = data[pos : pos + char_len * 2]
    return raw.decode("utf-16-le", errors="replace")


def _string_pool(data: bytes) -> list[str]:
    # The file starts with the XML chunk; the string pool is the next chunk.
    offset = 8
    chunk_type, header_size, chunk_size = struct.unpack_from("<HHI", data, offset)
    if chunk_type != RES_STRING_POOL_TYPE:
        raise ValueError(f"expected string pool at {offset}, found type {chunk_type:#x}")
    string_count = _u32(data, offset + 8)
    flags = _u32(data, offset + 16)
    strings_start = offset + _u32(data, offset + 20)
    utf8 = bool(flags & (1 << 8))
    offsets = [
        _u32(data, offset + header_size + index * 4) for index in range(string_count)
    ]
    return [
        _decode_pool_string(data, strings_start, item, utf8) for item in offsets
    ]


def read_version_code(manifest: bytes) -> int:
    value, _ = _find_version_code(manifest)
    return value


def _find_version_code(manifest: bytes) -> tuple[int, int]:
    strings = _string_pool(manifest)
    try:
        name_index = strings.index("versionCode")
    except ValueError as exc:
        raise ValueError("AndroidManifest.xml has no versionCode attribute") from exc
    offset = 0
    size = len(manifest)
    while offset + 8 <= size:
        chunk_type, header_size, chunk_size = struct.unpack_from("<HHI", manifest, offset)
        if chunk_size < 8 or offset + chunk_size > size:
            raise ValueError(f"bad XML chunk at {offset}")
        # The outer XML chunk wraps every other chunk. Step into it instead
        # of skipping to the end of the file.
        if chunk_type == RES_XML_TYPE:
            offset += header_size
            continue
        if chunk_type == RES_XML_START_ELEMENT_TYPE:
            ext = offset + header_size
            attribute_start = _u16(manifest, ext + 8)
            attribute_size = _u16(manifest, ext + 10)
            attribute_count = _u16(manifest, ext + 12)
            if attribute_size < 20:
                raise ValueError(f"unexpected attribute size {attribute_size}")
            attrs = ext + attribute_start
            for index in range(attribute_count):
                attr = attrs + index * attribute_size
                if _u32(manifest, attr + 4) == name_index:
                    data_type = manifest[attr + 15]
                    value = _u32(manifest, attr + 16)
                    if data_type != TYPE_INT_DEC:
                        raise ValueError(
                            f"versionCode type is {data_type:#x}, expected INT_DEC"
                        )
                    return value, attr + 16
        offset += chunk_size
    raise ValueError("versionCode attribute was not found in the XML tree")


def set_version_code(manifest: bytearray, version_code: int) -> bool:
    current, data_offset = _find_version_code(manifest)
    if current == version_code:
        return False
    struct.pack_into("<I", manifest, data_offset, version_code)
    return True


def _rewrite_apk(apk: Path, manifest: bytes) -> None:
    tmp = apk.with_suffix(apk.suffix + ".tmp")
    with zipfile.ZipFile(apk, "r") as src, zipfile.ZipFile(tmp, "w") as dst:
        for info in src.infolist():
            payload = manifest if info.filename == "AndroidManifest.xml" else src.read(info.filename)
            out = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
            out.compress_type = info.compress_type
            out.external_attr = info.external_attr
            out.create_system = info.create_system
            dst.writestr(out, payload)
    os.replace(tmp, apk)


def _tool(explicit: str | None, name: str) -> str:
    if explicit:
        return explicit
    from shutil import which

    found = which(name)
    if not found:
        raise SystemExit(f"::error title=Missing {name}::Cannot re-sign the APK")
    return found


def _resign(apk: Path, args: argparse.Namespace) -> None:
    zipalign = _tool(args.zipalign, "zipalign")
    apksigner = _tool(args.apksigner, "apksigner")
    if not args.keystore:
        raise SystemExit("::error title=Missing keystore::Cannot re-sign after changing versionCode")
    help_text = subprocess.run(
        [zipalign, "-h"], capture_output=True, text=True, check=False
    )
    page_align = "-P" in (help_text.stdout + help_text.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        aligned = Path(tmp) / "aligned.apk"
        command = [zipalign]
        if page_align:
            command += ["-P", "16"]
        command += ["-f", "4", str(apk), str(aligned)]
        subprocess.run(command, check=True)
        subprocess.run(
            [
                apksigner,
                "sign",
                "--ks",
                args.keystore,
                "--ks-pass",
                f"pass:{args.ks_pass}",
                "--ks-key-alias",
                args.key_alias,
                "--key-pass",
                f"pass:{args.key_pass}",
                "--v1-signing-enabled",
                "true",
                "--v2-signing-enabled",
                "true",
                "--v3-signing-enabled",
                "true",
                "--min-sdk-version",
                "24",
                "--out",
                str(apk),
                str(aligned),
            ],
            check=True,
        )


def force(apk: Path, version_code: int, args: argparse.Namespace) -> None:
    with zipfile.ZipFile(apk) as archive:
        manifest = bytearray(archive.read("AndroidManifest.xml"))
    current = read_version_code(manifest)
    if current == version_code:
        print(f"{apk.name}: versionCode {current} already shared")
        return
    if not set_version_code(manifest, version_code):
        print(f"{apk.name}: versionCode {current} already shared")
        return
    if read_version_code(manifest) != version_code:
        raise SystemExit(f"::error title=versionCode patch failed::{apk.name}")
    _rewrite_apk(apk, bytes(manifest))
    _resign(apk, args)
    print(f"{apk.name}: versionCode {current} -> {version_code}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version-code", type=int, required=True)
    parser.add_argument("--zipalign")
    parser.add_argument("--apksigner")
    parser.add_argument("--keystore", default=os.environ.get("ANDROID_KEYSTORE_PATH"))
    parser.add_argument("--ks-pass", default=os.environ.get("ANDROID_KEYSTORE_PASSWORD"))
    parser.add_argument("--key-alias", default=os.environ.get("ANDROID_KEY_ALIAS"))
    parser.add_argument("--key-pass", default=os.environ.get("ANDROID_KEY_PASSWORD"))
    parser.add_argument("apks", nargs="+", type=Path)
    args = parser.parse_args()
    if args.version_code < 1:
        raise SystemExit("version code must be positive")
    for apk in args.apks:
        force(apk, args.version_code, args)
    return 0


if __name__ == "__main__":
    sys.exit(main())

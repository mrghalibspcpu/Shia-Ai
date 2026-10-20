#!/usr/bin/env python3
"""Put the publisher's real support e-mail into the privacy-policy page.

Usage: python3 scripts/set_policy_contact.py you@example.com

The page ships with the public GitHub Issues contact only (nothing invented).
Running this replaces the marker comment with a mailto link; running it again
with another address updates the link.
"""
import pathlib
import re
import sys

page = pathlib.Path(__file__).resolve().parent.parent / "docs/privacy-policy/index.html"
if len(sys.argv) != 2 or not re.fullmatch(r"[^@\s<>\"']+@[^@\s<>\"']+\.[A-Za-z]{2,}", sys.argv[1]):
    sys.exit("usage: set_policy_contact.py name@example.com")
mail = sys.argv[1]
html = page.read_text(encoding="utf-8")
link = f' or e-mail <a href="mailto:{mail}">{mail}</a><!--CONTACT_EMAIL-->'
new, n = re.subn(r"(?: or e-mail <a href=\"mailto:[^\"]+\">[^<]+</a>)?<!--CONTACT_EMAIL-->", link, html)
if n != 1:
    sys.exit("marker not found")
page.write_text(new, encoding="utf-8")
print("updated", page)

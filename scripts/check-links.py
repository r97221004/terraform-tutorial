#!/usr/bin/env python3
"""Check relative links and #anchors in Markdown files (GitHub heading slugs).

Usage: scripts/check-links.py README.md docs/**/*.md
Code blocks are skipped, so regexes and HCL inside them aren't mistaken for links.
"""
import os
import re
import sys


def slug(heading: str) -> str:
    heading = heading.strip().lower()
    heading = re.sub(r"[`*]", "", heading)
    heading = re.sub(r"[^\w\- ]", "", heading)
    return heading.replace(" ", "-")


def without_code(text: str) -> str:
    return re.sub(r"```.*?```", "", text, flags=re.S)


problems = 0
for path in sys.argv[1:]:
    text = without_code(open(path, encoding="utf-8").read())
    for match in re.finditer(r"\]\(([^)\s]+)\)", text):
        target = match.group(1)
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        file_part, _, anchor = target.partition("#")
        resolved = os.path.normpath(os.path.join(os.path.dirname(path), file_part)) if file_part else path
        if not os.path.exists(resolved):
            print(f"{path}: broken link {target}")
            problems += 1
            continue
        if anchor and resolved.endswith(".md"):
            headings = [slug(line.lstrip("#")) for line in without_code(open(resolved, encoding="utf-8").read()).splitlines() if line.startswith("#")]
            if anchor not in headings:
                print(f"{path}: missing anchor {target}")
                problems += 1

print(f"Checked {len(sys.argv) - 1} files: {problems} problem(s).")
sys.exit(1 if problems else 0)

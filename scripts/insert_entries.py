#!/usr/bin/env python3
"""Insert discovered entries into the awesome-list readme.

Usage: insert_entries.py <readme_path> <entries_json_path>

The entries JSON is an array of {repo, category, description, ...} objects.
Entries are grouped by category and inserted at the end of the matching
"## <Category>" section. If a section is missing, the entry is dropped with a
warning so a human can decide where it belongs.
"""

import json
import re
import sys
from pathlib import Path


def main() -> int:
    readme_path = Path(sys.argv[1])
    entries_path = Path(sys.argv[2])

    readme = readme_path.read_text()
    entries = json.loads(entries_path.read_text())

    by_category: dict[str, list[dict]] = {}
    for entry in entries:
        by_category.setdefault(entry["category"], []).append(entry)

    for category, items in by_category.items():
        readme = insert_into_section(readme, category, items)

    readme_path.write_text(readme)
    return 0


def insert_into_section(readme: str, section: str, items: list[dict]) -> str:
    header = re.compile(rf"^## {re.escape(section)}\s*$", re.MULTILINE)
    match = header.search(readme)
    if not match:
        readme = create_section(readme, section)
        match = header.search(readme)
        if not match:
            print(
                f"warn: failed to create section '## {section}'; "
                f"skipping {len(items)} entr{'y' if len(items) == 1 else 'ies'}",
                file=sys.stderr,
            )
            return readme

    section_start = match.end()
    next_header = re.search(r"^## ", readme[section_start:], re.MULTILINE)
    section_end = section_start + next_header.start() if next_header else len(readme)

    section_text = readme[section_start:section_end]
    lines = section_text.split("\n")

    bullet_indices = [i for i, line in enumerate(lines) if line.startswith("- ")]
    new_bullets = [format_entry(item) for item in items]

    if bullet_indices:
        last = bullet_indices[-1]
        lines = lines[: last + 1] + new_bullets + lines[last + 1 :]
    else:
        # No existing bullets — drop them in after the section header / intro paragraph,
        # preserving any prose that follows the header.
        insert_at = 1
        while insert_at < len(lines) and lines[insert_at].strip():
            insert_at += 1
        lines = lines[:insert_at] + [""] + new_bullets + lines[insert_at:]

    new_section = "\n".join(lines)
    return readme[:section_start] + new_section + readme[section_end:]


def create_section(readme: str, section: str) -> str:
    """Create a new section before ## Contributing (or at the end)."""
    print(f"info: creating new section '## {section}'", file=sys.stderr)

    new_section = f"\n## {section}\n\n"

    # Insert before ## Contributing if it exists
    contrib = re.search(r"^## Contributing\s*$", readme, re.MULTILINE)
    if contrib:
        insert_at = contrib.start()
        readme = readme[:insert_at] + new_section + readme[insert_at:]
    else:
        readme = readme.rstrip() + "\n" + new_section

    # Add to TOC if one exists (look for "## Contents" with bullet list)
    toc_header = re.search(r"^## Contents\s*$", readme, re.MULTILINE)
    if toc_header:
        toc_start = toc_header.end()
        next_h = re.search(r"^## ", readme[toc_start:], re.MULTILINE)
        toc_end = toc_start + next_h.start() if next_h else len(readme)
        toc_text = readme[toc_start:toc_end]

        # Find the last TOC bullet before Contributing
        toc_lines = toc_text.split("\n")
        insert_idx = len(toc_lines) - 1
        for i, line in enumerate(toc_lines):
            if "contributing" in line.lower():
                insert_idx = i
                break

        slug = section.lower().replace(" ", "-")
        toc_entry = f"- [{section}](#{slug})"
        toc_lines.insert(insert_idx, toc_entry)
        readme = readme[:toc_start] + "\n".join(toc_lines) + readme[toc_end:]

    return readme


def format_entry(item: dict) -> str:
    repo = item["repo"]
    name = repo.split("/")[-1]
    desc = item["description"].rstrip(". ")
    badge = (
        f"![](https://img.shields.io/github/stars/{repo}"
        f"?style=flat-square&label=%20&color=gray)"
    )
    return f"- [{name}](https://github.com/{repo}) — {desc}. {badge}"


if __name__ == "__main__":
    raise SystemExit(main())

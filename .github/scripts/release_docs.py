#!/usr/bin/env python3
"""Keep VERSION, CHANGELOG.md and RELEASE_HIGHLIGHTS.md consistent.

Usage:
    python3 .github/scripts/release_docs.py --check

Exit code 0 when consistent, 1 with a list of problems otherwise. No third-party
imports: this runs on a bare runner and on a machine that only has python3.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SEMVER = re.compile(r"^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def check() -> list[str]:
    problems: list[str] = []

    version_file = REPO / "VERSION"
    if not version_file.is_file():
        return ["VERSION is missing"]
    version = read(version_file).strip()
    if not SEMVER.match(version):
        problems.append(f"VERSION '{version}' is not semver")

    changelog = REPO / "CHANGELOG.md"
    if not changelog.is_file():
        problems.append("CHANGELOG.md is missing")
    else:
        text = read(changelog)
        headings = re.findall(r"^## (\S+)", text, flags=re.MULTILINE)
        if not headings:
            problems.append("CHANGELOG.md has no '## <version>' section")
        else:
            if headings[0] != version:
                problems.append(
                    f"CHANGELOG.md top section is '{headings[0]}', VERSION is '{version}'"
                )
            if len(set(headings)) != len(headings):
                problems.append("CHANGELOG.md has duplicate version sections")
            for h in headings:
                if not SEMVER.match(h):
                    problems.append(f"CHANGELOG.md section '{h}' is not semver")

    highlights = REPO / "RELEASE_HIGHLIGHTS.md"
    if not highlights.is_file():
        problems.append("RELEASE_HIGHLIGHTS.md is missing")
    else:
        body = [
            line
            for line in read(highlights).splitlines()
            if line.strip() and not line.startswith("#")
        ]
        bullets = [line for line in body if line.lstrip().startswith("-")]
        if not bullets:
            problems.append("RELEASE_HIGHLIGHTS.md has no bullet points")
        if any("TODO" in line or "TBD" in line for line in body):
            problems.append("RELEASE_HIGHLIGHTS.md still contains TODO/TBD")
    highlights_cn = REPO / "RELEASE_HIGHLIGHTS_CN.md"
    if not highlights_cn.is_file():
        problems.append("RELEASE_HIGHLIGHTS_CN.md is missing")

    skill = REPO / "SKILL.md"
    if not skill.is_file():
        problems.append("SKILL.md is missing")
    else:
        text = read(skill)
        if not text.startswith("---\n"):
            problems.append("SKILL.md does not start with YAML frontmatter")
        name = re.search(r"^name:\s*(.+)$", text, flags=re.MULTILINE)
        description = re.search(r"^description:\s*(.+)$", text, flags=re.MULTILINE)
        if not name:
            problems.append("SKILL.md frontmatter has no name")
        elif name.group(1).strip() != REPO.name:
            problems.append(
                f"SKILL.md name '{name.group(1).strip()}' != repository directory '{REPO.name}'"
            )
        if not description:
            problems.append("SKILL.md frontmatter has no description")
        elif len(description.group(1)) > 1024:
            problems.append("SKILL.md description exceeds 1024 characters")

    manifest = REPO / "agents/openai.yaml"
    if not manifest.is_file():
        problems.append("agents/openai.yaml is missing")
    else:
        text = read(manifest)
        for key in ("display_name", "short_description", "allow_implicit_invocation"):
            if key not in text:
                problems.append(f"agents/openai.yaml has no {key}")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify and exit non-zero on problems")
    parser.add_argument("--version", action="store_true", help="print the version and exit")
    args = parser.parse_args()

    if args.version:
        print(read(REPO / "VERSION").strip())
        return 0

    problems = check()
    if problems:
        print("release documents are inconsistent:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"release documents consistent (version {read(REPO / 'VERSION').strip()})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

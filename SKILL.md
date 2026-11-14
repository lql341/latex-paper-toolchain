---
name: latex-paper-toolchain
description: Set up, repair, and verify a minimal XeLaTeX/CTeX toolchain for bilingual (Chinese/English) papers — BasicTeX on macOS or TeX Live on Debian without polluting the desktop font stack, stable native CJK font binding, and a cold-state build proven by embedded font names and clean reference/bibliography resolution. Use when installing, auditing, or debugging the paper toolchain itself, not for ordinary LaTeX syntax questions.
license: MIT
compatibility: Verified on macOS 26.6.2 (Apple Silicon) + BasicTeX/TeX Live 2026, and on Ubuntu 26.04 CI with apt TeX Live. Scripts are POSIX sh; no Python except one CI meta-check, no network, no root unless apt/tlmgr needs it.
---

# latex-paper-toolchain

Two jobs, and they are different:

1. **Install the minimum** that can typeset Chinese + Latin + math + plots + bibliography,
   without changing how the desktop renders Chinese.
2. **Prove it works.** A toolchain that "compiled once" is not verified. Verified means:
   cold state (no `.aux`, no `.bbl`), references resolved, and the CJK glyphs in the PDF
   come from a font you can name.

This is not a LaTeX tutorial — assume LaTeX syntax is known. This repository exists for the
places where the default answer is wrong.

## Default answers that are wrong here

| Tempting default | What actually works |
|---|---|
| `brew install --cask mactex` (~5 GB) | `basictex` (~533 MB) + explicit `tlmgr install` for what the paper uses |
| `\documentclass[fontset=mac]{ctexart}` | `fontset=none` + explicit `\setCJKmainfont{Songti SC Regular}` |
| Copy Songti/PingFang into `~/Library/Fonts` so XeTeX finds it | Leave system fonts alone; pin families XeTeX can already open |
| `sudo apt install texlive-lang-chinese` on a desktop | `scripts/install-debian.sh --apply` (isolation rule first, then apt) |
| `\setCJKmainfont{FandolSong-Regular}` | `FandolSong-Regular.otf` — the family name does not resolve on Ubuntu |
| "PDF generated" = done | Check `Missing character`, undefined refs, and the embedded subset names |
| Install more fonts to fix a font problem | Fix the mapping; adding fonts usually makes fallback worse |

## Entry points

| Situation | Run |
|---|---|
| Machine already has TeX; paper won't build | `scripts/doctor.sh` → `scripts/cold-build.sh` |
| Fresh macOS | `references/macos-native-fonts.md` (install → font binding → cold build) |
| Fresh Debian/Ubuntu desktop | `scripts/install-debian.sh` (dry-run) → `--apply` |
| TeX already installed, desktop fonts changed | `scripts/fontconfig-isolate.sh --check` → `--write` |
| Odd errors, missing sty, interrupted install | `references/troubleshooting.md` |
| Writing a new paper | copy `assets/macos/macos-native-fonts.tex`, start from `assets/example/main.tex` |
| Prove an install changed nothing | `scripts/font-audit.sh save before|after` → `diff` |
| Put this skill on a machine | `scripts/install.sh [--claude] [--codex] [--link]` |

Every script takes `--help` and is dry-run by default where it would change the system
(`install-debian.sh`, `fontconfig-isolate.sh --dry-run`). Read the printed plan before `--apply`.

## The verification loop (always run all three)

```bash
scripts/doctor.sh                              # binaries, packages, can XeTeX open the CJK family
scripts/cold-build.sh --expect-font STSongti   # clean build + log assertions + embedded fonts
scripts/font-audit.sh diff before after        # desktop font stack untouched
```

Report back with concrete evidence: page count, the embedded CJK font names, and whether the
font manifest hash is unchanged. "It builds" without those three is not a result.

## Hard rules

- **Never** add fonts to `/Library/Fonts` or `~/Library/Fonts` to satisfy XeTeX. TeX Live fonts
  live in TEXMF (`/usr/local/texlive/<year>basic/texmf-dist`).
- `tlmgr install --dry-run <pkg>` before installing a package whose dependency closure is unknown.
- Do not add `texlive-full`, `latex-cjk-all`, `fonts-noto-cjk`, `fonts-noto-cjk-extra` "just in case".
- `mktextfm STFangsong` in the log is a CTeX probe, not a missing-package error — switch to
  `fontset=none` instead of installing the font.
- A `codesign`/`spctl` failure inside a sandbox is not evidence about the host system's trust
  chain; do not report it as tampering or as verification.
- Cross-platform byte-identical layout is **not** a goal: macOS native fonts and Linux Fandol
  will differ. Reproducibility here means "the same platform rebuilds the same document".

## Layout

```text
SKILL.md                     this file: decisions and entry points
scripts/install.sh           install into ~/.agents/skills (+ Claude Code / Codex)
scripts/install-debian.sh    Debian/Ubuntu: plan by default, --apply to execute
scripts/fontconfig-isolate.sh  keep Arphic fonts out of the desktop fallback chain
scripts/doctor.sh            read-only health check
scripts/cold-build.sh        clean build + log assertions + embedded font list
scripts/font-audit.sh        font-directory manifest, before/after comparison
scripts/_common.sh           shared POSIX sh helpers (sourced, never run)
assets/macos/                drop-in CJK font binding for macOS
assets/example/              bilingual smoke test (math, plot, table, code, biber, cref)
references/                  macOS setup, Debian isolation, troubleshooting, claim matrix
tests/                       static, Debian-tools and TeX layers; tests/run-all.sh runs all
```

## What is actually verified

See `references/verified-matrix.md`. Read it before repeating a claim to a user: it separates
what was measured (with environment and date) from what is inferred. `fontset=mac` behavior,
LuaLaTeX, Intel Macs, Windows and TeX Live 2027 are **not** verified here.

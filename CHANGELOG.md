# Changelog

## 0.3.2 - 2026-11-14

Closes two holes where the suite asserted things it could not actually fail on.

- `font-audit.sh` was only ever exercised in the "unchanged" direction, so its `diff` was never
  proven to detect anything. A `FONT_AUDIT_DIRS` override (test seam, like `LPT_OS_OVERRIDE`) lets
  `test-static.sh` run the tool against a throwaway font directory and assert all four outcomes:
  identical → `UNCHANGED`, modified → `CHANGED`, added → `CHANGED` with the file named, removed →
  `CHANGED`.
- `cold-build.sh --png` was never run in CI. `test-tex.sh` now renders a page and fails if the render
  line is missing, the tool reported a failure, or no file appeared.
- `docs/ROADMAP.md` gains R7: branch protection and required status checks are repository settings
  that no file can enforce, with the `gh api` invocation that turns them on.

## 0.3.1 - 2026-11-14

Documentation only: no script or behaviour changed.

- `docs/ROADMAP.md` — the items that are deliberately not automated, with the blocker and the manual
  procedure that closes each one: Windows/WSL, a real BasicTeX build on a CI runner, end-to-end
  desktop-font verification on a real Debian desktop, and confirming the TeX Live 2020 floor.
  LuaLaTeX and Intel Mac are recorded as declined / blocked instead of silently missing.
- The file states its own lifecycle (finish an item → record it in `references/verified-matrix.md`,
  add a CHANGELOG line, delete the item) and a document map, so a new contributor knows which file
  answers which question.
- `README`/`README_CN`/`SKILL.md` link to it; the layout sections now include `docs/`.

## 0.3.0 - 2026-11-14

Portability floor, macOS CI coverage, and install polish.

- `doctor.sh` now reports **feature floors** instead of failing late: it detects the siunitx v3
  marker (`\ProvidesExplPackage {siunitx}`) and pgfplots' own `\pgfplotsversion`, because the
  example needs TeX Live >= 2021 (`\qty`, `compat=1.18`). On an older install it says what will
  break and how to work around it, instead of letting the build die with
  `Undefined control sequence \qty`.
- Documented the floor in `SKILL.md`, both READMEs, `references/troubleshooting.md` (with the
  siunitx v2 fallback and the `install-tl` route) and `references/verified-matrix.md` — including
  the honest note that no TeX Live 2020 machine was available to test it.
- `validate.yml` gains a **macOS job** running the static and Debian-tools layers. It does not
  install BasicTeX (sudo, minutes, and it would only re-test the author's machine); its job is to
  catch BSD-vs-GNU drift in `stat`, `sed -i` and `mktemp` usage.
- `install.sh --minimal` skips `tests/` and `.github/` when copying, so a consumer installation
  carries only what the model needs plus the references.
- `scripts/_common.sh` is no longer executable — it is sourced, never run — and the static layer
  now asserts that, the reverse of what it asserts for the entry points.
- READMEs carry a Validate badge; the repository has topics for discoverability.

## 0.2.2 - 2026-11-14

Found by cloning the published repository into a directory with a different name and running the
suite there — the same thing a fork, a CI workspace, or `git clone <url> my-copy` produces.

- The skill name is treated as an identity, not a path: `release_docs.py` and `test-static.sh`
  compare `SKILL.md`'s `name` against `latex-paper-toolchain` instead of the checkout directory,
  and a differing directory is a note rather than a failure.
- `install.sh` now reads the skill name from the frontmatter instead of using the directory it was
  cloned into, so a differently named checkout still installs as `latex-paper-toolchain`.
- `--dest DIR` is documented and implemented as a *skills root*: the skill is installed at
  `DIR/<skill-name>`. Previously it was used verbatim as the final directory, which made the
  installed path depend on how you invoked the script.
- `tests/test-static.sh` covers both: a differently named checkout installs under the skill name,
  and a plain `--dest` install produces `<dest>/latex-paper-toolchain/SKILL.md` without `.git`.

## 0.2.1 - 2026-11-14

Fixes a destructive path in `scripts/install.sh`, found by asking it to install onto a machine
whose `~/.agents/skills` is a symlink into the same checkout (the layout this repository's author
actually runs).

- `install.sh` compared the destination with the source as strings. With a symlinked skills root
  the two are the same directory but different strings, so the installer moved the repository aside
  as a "backup" and then failed copying from a path that no longer existed. It now resolves both
  sides with `pwd -P` and reports "resolve to the same directory; nothing to do" instead.
- The `--link` fast path uses the same canonical comparison, so re-running it on a symlinked
  installation is a no-op rather than a re-link.
- `tests/test-static.sh` covers the layout: symlinked skills root (source intact, no `.bak` of the
  source) and a genuine install into a fresh destination (SKILL.md present, `.git` dropped).

## 0.2.0 - 2026-11-14

The Debian/Ubuntu half stops being documentation and becomes an executable, testable procedure;
the repository gains the layout that scnet-hpc already uses (agent manifest, release highlights,
validate/release workflows, shared shell helpers, tests split by layer).

- `scripts/fontconfig-isolate.sh` — `--check` / `--write` / `--remove` / `--dry-run` for the
  user-level `rejectfont` rule that keeps the Arphic fonts pulled in by `texlive-lang-chinese` out
  of the desktop fallback chain. Refreshes the cache after writing, prints the resulting
  `fc-match` resolution, and reports `not-applicable` on macOS instead of pretending.
- `scripts/install-debian.sh` — dry-run by default; `--apply` runs isolation rule → `apt-get update`
  → `apt-get install --no-install-recommends <minimal set>`, then takes a before/after font manifest
  and reports how the default CJK families resolve. Refuses to run off Debian/Ubuntu. Installs
  `texlive-bibtex-extra` because `biblatex.sty` is only a Recommends elsewhere.
- `scripts/install.sh` — installs the skill into `~/.agents/skills` (optionally also Claude Code and
  Codex), copying by default or `--link` for development; backs up an existing installation with a
  timestamp and strips `.git`/build products from the copy.
- `scripts/_common.sh` — shared POSIX sh helpers (paths, logging, hashing/stat portability, font
  directories, platform detection) sourced by every script; `LPT_OS_OVERRIDE` lets the test suite
  exercise the Linux branch on a macOS host.
- `agents/openai.yaml` — interface metadata for harnesses that read it.
- `RELEASE_HIGHLIGHTS.md` / `_CN.md` and `.github/scripts/release_docs.py --check` — VERSION,
  CHANGELOG, SKILL.md frontmatter and the release notes are validated against each other in CI.
- Workflows mirror the repository contract: `validate.yml` (static, hermetic Debian tools, and a real
  XeLaTeX build installed through `scripts/install-debian.sh --apply`) and `release.yml` (tag +
  GitHub Release from the highlights, only for a validated `main`).
- Tests split into `test-static.sh`, `test-debian-tools.sh`, `test-tex.sh`, orchestrated by
  `run-all.sh`. New negative cases: a document with a dangling `\ref` must fail, and
  `--expect-font` must fail for a font that is not embedded. `--help` is exercised for every script.

## 0.1.1 - 2026-11-14

Two defects that only surfaced once the full suite ran on Linux, plus a released tag for the
initial publication.

- **Font binding on Linux**: `\setCJKmainfont{FandolSong-Regular}` fails on Ubuntu's TeX Live
  ("font not found") while `FandolSong-Regular.otf` resolves. The example now binds Fandol by file
  name, and `doctor.sh` tries file-name and family-name candidates in turn, reporting which form
  worked. Measured before/after in CI run 43609000774.
- **Missing `biblatex.sty` on Debian/Ubuntu**: it ships in `texlive-bibtex-extra`, which is only a
  *Recommends* of `texlive-latex-extra`, so `--no-install-recommends` drops it and the build fails
  even though `biber` is installed. Added to the documented install set and to CI; `doctor.sh`
  hints the apt package when the `.sty` is missing on Linux. CI run 43609328438.
- CI is green end-to-end (run 43609596146): doctor, cold build with Fandol embedded, repeat cold
  build, and the font-directory invariant, all on ubuntu-latest.

## 0.1.0 - 2026-11-14

First public release. Distilled from private notes that were written while validating a bilingual
XeLaTeX toolchain on macOS (2026-08-30) and while isolating CTeX fonts on Debian (2026-08-30).

- `scripts/doctor.sh` — read-only check of platform, binaries, style packages, and whether XeTeX can
  open the platform's CJK family by name (real probe compile, not a font-list lookup).
- `scripts/cold-build.sh` — clean state (removes `.bbl`, `.xdv`, `.bcf`), full `latexmk -xelatex`
  build, log assertions for undefined references/citations, missing characters, missing inputs and
  TeX errors, then the embedded font list. Uses `pdffonts` when present and falls back to parsing
  `xdvipdfmx -vv` (TeX Live ships it; no poppler required). `--expect-font` turns "a font was
  embedded" into an assertion.
- `scripts/font-audit.sh` — font-directory manifest with content digest, `save`/`diff`/`list`/`show`,
  plus recorded `fc-match` state on Linux. This is the evidence that an install did not touch the
  desktop font stack.
- `assets/macos/macos-native-fonts.tex` — `fontset=none` binding for Songti SC / Heiti SC, including
  the `AutoFakeSlant` needed to avoid the `Font shape ... undefined` warning for italic CJK.
- `assets/example/` — two-page bilingual smoke test exercising CJK/Latin mixed text, `amsmath`,
  `pgfplots`, `booktabs`, `listings`, `siunitx`, `cleveref`, and a Biber bibliography. Falls back to
  Fandol when the macOS fonts are absent, so the same file builds on Linux.
- `tests/run-all.sh` — static checks (syntax, frontmatter, links, privacy, versioning) plus a TeX
  layer that runs doctor, cold build and a font-invariant assertion; auto-skips without `xelatex`.
- `references/verified-matrix.md` — every claim with its environment, date, and status, including
  what was deliberately not verified.
- `.github/workflows/ci.yml` — `static` job (no TeX needed) plus a `tex` job that installs a
  minimal Debian-flavoured toolchain on ubuntu-latest and runs the full test suite.

Known limits at this version: no LuaLaTeX path, no Windows support, the Linux build is verified in
CI rather than on a local Linux machine, and the Debian font-isolation procedure is documented from
a 2026-08-30 session instead of being re-run by the test suite.

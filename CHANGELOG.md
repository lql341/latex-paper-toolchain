# Changelog

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

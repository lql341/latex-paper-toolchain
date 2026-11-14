# Changelog

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
- Linux/Fandol font binding addresses the `.otf` files instead of the family name: on Ubuntu's TeX
  Live, `\setCJKmainfont{FandolSong-Regular}` is not found while `FandolSong-Regular.otf` is. Found
  by the first CI run, recorded in `references/verified-matrix.md`.
- Debian/Ubuntu install list now includes `texlive-bibtex-extra`: `biblatex.sty` is only a
  Recommends of `texlive-latex-extra`, so `--no-install-recommends` drops it and the build fails.
  Found by the second CI run.
- `.github/workflows/ci.yml` — `static` job (no TeX needed) plus a `tex` job that installs a
  minimal Debian-flavoured toolchain on ubuntu-latest and runs the full test suite, which is also
  the first real verification of the Linux/Fandol path.

Known limits at this version: no LuaLaTeX path, no Windows support, Linux verified in CI only
(the author's Linux measurements predate this repository), and the Debian font-isolation procedure
is documented from a 2026-08-30 session rather than re-run by the test suite.

# Troubleshooting

Symptom-first. Every entry states what was actually observed, so you can tell whether your case is
the same one.

## `File 'zhnumber.sty' not found`

**Observed:** macOS, after `sudo tlmgr update --all`. The update introduced CTeX and XeCJK but not
`zhnumber`, so `ctexart` failed on the first compile with this error.

```bash
sudo tlmgr install zhnumber
```

If the file is still missing afterwards, the CTeX installation itself is incomplete:

```bash
sudo tlmgr install --dry-run ctex    # inspect the closure first
sudo tlmgr install ctex
```

## `mktextfm STFangsong` / CTeX font probing

**Observed:** `\documentclass[fontset=mac]{ctexart}` on macOS where STFangsong is not installed.

This is a CTeX probe, not a broken package. Installing or copying a Fangsong font is the wrong fix —
use explicit binding instead:

```latex
\documentclass[UTF8,fontset=none]{ctexart}
\input{assets/macos/macos-native-fonts}
```

## `Font shape TU/SongtiSCRegular(0)/m/sl undefined`

**Observed:** italic CJK (e.g. inside `\emph`) in a document bound to Songti SC only.

```latex
\setCJKmainfont{Songti SC Regular}[BoldFont = Songti SC Bold, AutoFakeSlant = 0.2]
```

After this the log is clean. This is a synthetic slant, not a real italic face.

## `Undefined control sequence \qty` (or `compat=1.18` unknown)

**Cause:** TeX Live older than 2021. `\qty` is a siunitx v3 command; `\pgfplotset{compat=1.18}`
needs pgfplots >= 1.18. Debian 11 and Ubuntu 20.04 ship TeX Live 2020, where both are missing —
and the error points at the document, not at the age of the installation.

Diagnose:

```bash
scripts/doctor.sh | sed -n '/feature floors/,/CJK font probe/p'
kpsewhich siunitx.sty | xargs grep -l 'ProvidesExplPackage'   # v3 marker
```

Options, in order of preference:

1. install a newer TeX Live (`scripts/install-debian.sh` targets current Debian/Ubuntu, which are
   fine; for an old release use the upstream `install-tl`);
2. if you must stay on the old installation, rewrite the affected commands for siunitx v2:
   `\qty{1.2}{\metre\per\second}` → `\SI{1.2}{\metre\per\second}`, `\num{3.14e-2}` stays valid;
3. drop `compat=1.18` to the highest level your pgfplots supports (it degrades behaviour, so it is
   the last resort).

Do not "fix" this by editing `assets/example` to the lowest common denominator: the example exists
to state the floor.

## BasicTeX cask ends with a partial download

**Observed:** CTAN mirror truncation at the tail of the package; Homebrew keeps the partial file in
its cache, so a plain retry can reuse it.

```bash
HOMEBREW_CURL_RETRIES=5 HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask basictex
```

## A font "is installed" but XeTeX cannot find it

Order of evidence, cheapest first:

```bash
kpsewhich ctex.sty                      # is the macro package actually on TEXMF?
fc-list : family | grep -i songti       # does the desktop see the family? (Linux)
xelatex -no-pdf probe.tex               # can XeTeX open it by name? (the only real test)
```

`fc-list` listing a family does **not** mean XeTeX can open it: on macOS, PingFang SC is enumerated
by the system font service but is not reliably openable by family name, and the PingFang UI
collection under `/System/.../Reserved/` is protected. `scripts/doctor.sh` runs the probe compile,
which is the check that matters.

## Fonts installed with TeX leaked into the desktop

**Observed:** Debian, after installing `texlive-lang-chinese` plus `fonts-noto-cjk`; Chinese spacing
changed in the terminal and in Electron apps.

Do not attempt to fix this by installing more fonts. See `debian-fontconfig.md` §6: remove what was
added, add a user-level `rejectfont` rule, `fc-cache -f`, compare `fc-match`, and reboot.

Verify with the manifest, not by eye:

```bash
scripts/font-audit.sh diff before after
```

## Build "succeeds" but references are `??`

Cause: warm state. A previous run's `.aux` or `.bbl` masked a broken `\ref`/`\cite`, or Biber never
ran because the `.bcf` was stale.

```bash
latexmk -C main.tex
rm -f main.bbl main.bcf main.run.xml
latexmk -xelatex -interaction=nonstopmode -halt-on-error main.tex
```

`scripts/cold-build.sh` does exactly this and then greps the log for
`There were undefined references`, `Citation ... undefined`, `Missing character:` and `! `.

## Biber errors are invisible in the exit code

Biber writes `main.blg` next to the build. A failed Biber run can still leave a "successful" LaTeX
pass with unresolved citations.

```bash
grep -E '^(ERROR|FATAL)' main.blg
```

`cold-build.sh` fails the build if `main.blg` contains either, and it removes the stale `.blg`
before building.

## `codesign` / `spctl` fail for every binary, including Apple's

**Observed:** inside a restricted agent sandbox, `codesign`/`spctl` returned
`CSSMERR_TP_NOT_TRUSTED` or a Code Signing subsystem internal error for Skim, TeX binaries, Apple's
Preview.app and `/bin/zsh`. That is a broken trust-service environment, not evidence that a file was
modified.

Alternative evidence that does work:

- downloaded file SHA-256 matches the package-manager metadata;
- the BasicTeX PKG SHA-512 matches the published value;
- per-file content hashes of the original DMG and the installed copy agree;
- LaunchServices actually starts the app and opens the verification PDF.

Re-run Gatekeeper checks in a normal interactive terminal before making any security claim, and do
not extrapolate sandbox failures to the host system.

## Locale / encoding problems with Chinese filenames or output

Not verified in this repository's tests. If you hit it, check `LANG`, and note that `ctex` expects
UTF-8 sources (`\documentclass[UTF8]{ctexart}`). Do not "fix" it by switching to `pdflatex` — that
removes the font path this skill depends on.

## Uninstalling

```bash
brew uninstall --cask basictex        # macOS
sudo apt-get remove texlive-xetex texlive-lang-chinese   # Debian
```

Then re-run `font-audit.sh diff before after`. On macOS the manifest should be `UNCHANGED`; on
Debian, removing the TeX CJK packages should remove the Arphic fonts too, but the Fontconfig cache
may need `fc-cache -f` before `fc-match` returns to baseline.

# macOS: minimal BasicTeX + native CJK fonts

Environment these commands were run in: Apple Silicon (arm64), macOS 26.6.2, BasicTeX 2026.0301
(TeX Live 2026), Homebrew cask `basictex`. Verified 2026-08-30, re-verified 2026-11-14 with
`scripts/doctor.sh` and `scripts/cold-build.sh` (see `verified-matrix.md`).

Total disk after install: ~533 MB under `/usr/local/texlive/2026basic`, plus ~22 MB of `tlmgr`
rollback backups. No file was added to `/Library/Fonts` or `~/Library/Fonts` (both stayed at
0 files, manifest SHA-256 unchanged).

## 1. Baseline before installing

Do this first, so "the install changed nothing" is a measurement rather than a belief:

```bash
scripts/font-audit.sh save before

uname -m; sw_vers
command -v xelatex || true
command -v tlmgr || true
```

## 2. Install BasicTeX

```bash
brew install --cask basictex
eval "$(/usr/libexec/path_helper)"
hash -r
xelatex --version
tlmgr --version
```

BasicTeX installs system-wide (`/Library/TeX`, `/usr/local/texlive/<year>basic`), so later `tlmgr`
changes need `sudo`. The Homebrew command itself must **not** be run with `sudo`.

## 3. Keep the install small

```bash
tlmgr option docfiles     # expect 0
tlmgr option srcfiles     # expect 0
```

Install only what the paper uses, and preflight unknown closures:

```bash
sudo tlmgr update --self --all
sudo tlmgr install --dry-run ctex
sudo tlmgr install ctex xecjk zhnumber latexmk biber biblatex pgfplots siunitx cleveref
```

`tlmgr` packages land in TEXMF (`texmf-dist`), which is not registered with the macOS font service.
That is exactly what keeps the desktop untouched.

## 4. Bind fonts explicitly (`fontset=none`)

Do **not** use `\documentclass[fontset=mac]{ctexart}`. Measured behaviour:

- `fontset=mac` compiles, but CTeX probes `STFangsong`; when it is absent the log shows an
  `mktextfm` attempt (harmless noise, but it invites "install the font" as a wrong fix);
- PingFang SC is enumerated by the system font service but XeTeX cannot reliably open it by family
  name;
- `/System/Library/.../Reserved/PingFangUI.ttc` is a protected UI collection and is not a stable
  interface for a paper toolchain.

Use the two families XeTeX opens reliably:

```latex
% !TEX program = xelatex
\documentclass[UTF8,fontset=none]{ctexart}
\input{assets/macos/macos-native-fonts}
```

`assets/macos/macos-native-fonts.tex` pins `Songti SC Regular` / `Songti SC Bold` and
`Heiti SC Light` / `Heiti SC Medium`, maps `\songti \heiti \kaishu \fangsong` onto families that
exist, and sets `AutoFakeSlant` on the main font (without it, italic CJK logs
`Font shape TU/SongtiSCRegular(0)/m/sl undefined`; with it, a clean log).

There is no stable independently addressable Kai/FangSong on this macOS build, so `\kaishu` and
`\fangsong` fall back to Songti variants by design — documented, not accidental.

## 5. Cold-start verification

```bash
latexmk -C main.tex
rm -f main.bbl
latexmk -xelatex -synctex=1 -interaction=nonstopmode -halt-on-error main.tex
```

Measured result for `assets/example/main.tex`: exit 0, 2 pages, Biber resolved, no undefined
references, no missing characters, no overfull boxes, ~8 s cold. Then check the embedded fonts —
`scripts/cold-build.sh` does all of the above in one step:

```bash
scripts/cold-build.sh --expect-font STSongti
```

Under the hood, when `pdffonts` (poppler) is absent, the font list comes from the `.xdv` that a
normal `latexmk -xelatex` run leaves behind:

```bash
xdvipdfmx -vv -o /tmp/latex-verify.pdf main.xdv 2>&1 | grep -E 'CID:|pdf_font>>'
```

Expected subset names for the macOS binding:

```text
STSongti-SC-Regular
STSongti-SC-Bold
STSongti-SC-Light
STHeitiSC-Light
```

Page preview without extra tools (macOS ships `sips`):

```bash
sips -s format png main.pdf --out /tmp/latex-verify.png
```

## 6. Failure paths seen on this platform

| Symptom | Cause | Fix |
|---|---|---|
| `File 'zhnumber.sty' not found` | `tlmgr update --all` pulled CTeX/XeCJK but not `zhnumber` | `sudo tlmgr install zhnumber` |
| `mktextfm STFangsong` in the log | CTeX `fontset=mac` probe | switch to `fontset=none`; do not install the font |
| BasicTeX cask ends with a partial download | CTAN mirror truncation; Homebrew keeps the cache | `HOMEBREW_CURL_RETRIES=5 HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask basictex` |
| `codesign`/`spctl` returns `CSSMERR_TP_NOT_TRUSTED` for everything | no access to the system trust chain inside the sandbox | not evidence of tampering; re-run Gatekeeper checks in a normal interactive shell |
| Italic CJK warns `Font shape ... undefined` | no italic face in the family | `AutoFakeSlant=0.2` on `\setCJKmainfont` |

## 7. Rollback

```bash
brew uninstall --cask basictex      # removes /Library/TeX, /usr/local/texlive/2026basic,
                                    # /etc/paths.d/TeX, /etc/manpaths.d/TeX
scripts/font-audit.sh save after
scripts/font-audit.sh diff before after   # expect UNCHANGED
```

If the font manifest is unchanged, no font-cache reset and no reboot is needed.

## 8. Scope

Bound to macOS 26.6.2 / Apple Silicon / BasicTeX + TeX Live 2026. Unverified: Intel Macs, older
macOS, LuaLaTeX, TeX Live 2027. Songti/Heiti font locations can change across macOS majors — after
an OS upgrade, re-run the cold build and re-check the embedded font names.

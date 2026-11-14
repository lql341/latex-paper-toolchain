# Verified matrix

Every claim in this repository, with the environment it was measured in and its status. Read this
before repeating a claim to a user. "Verified" means measured output on the stated machine; it is
not a general truth about LaTeX.

## Environments

| ID | Environment | Recorded |
|---|---|---|
| **M1** | macOS 26.6.2, Apple Silicon (arm64), BasicTeX 2026.0301 / TeX Live 2026, CTeX 2.6.5, XeCJK 3.10.6, latexmk 4.88, Biber 2.22 | 2026-08-30, re-checked 2026-11-14 |
| **D1** | Debian 13, XFCE desktop, Fontconfig, Chromium/Electron apps present, TeX Live from apt | 2026-08-30 |

## Claims

| # | Claim | Env | Status | Evidence |
|---|---|---|---|---|
| 1 | BasicTeX cask installs ~533 MB and needs no full MacTeX | M1 | verified | `du -sh /usr/local/texlive` = 522 M; cask `basictex` alone in `brew list --cask` |
| 2 | TeX Live fonts do not appear in macOS font directories | M1 | verified | `/Library/Fonts` and `~/Library/Fonts` both 0 files; manifest SHA-256 unchanged before/after |
| 3 | `fontset=mac` triggers an `STFangsong` / `mktextfm` probe | M1 | verified | build log line from 2026-08-30 run |
| 4 | `fontset=none` + explicit Songti SC / Heiti SC builds clean | M1 | verified | `cold-build.sh` on `assets/example`: 2 pages, 0 warnings, 0 overfull |
| 5 | Italic CJK needs `AutoFakeSlant` to avoid `Font shape ... undefined` | M1 | verified | before/after logs, 2026-11-14 |
| 6 | XeTeX cannot reliably open PingFang SC by family name; PingFangUI.ttc is protected | M1 | verified | probe compiles and font-service behaviour, 2026-08-30 |
| 7 | A normal `latexmk -xelatex` run leaves `.xdv`, so font extraction needs no poppler | M1 | verified | `.xdv` present after build; `xdvipdfmx -vv` lists `CID:` names; `pdffonts` absent on this machine |
| 8 | `pdffonts` is **not** available by default on macOS | M1 | verified | `command -v pdffonts` empty (2026-11-14) |
| 9 | `sips` renders PDF pages to PNG without extra tools | M1 | verified | `sips -s format png main.pdf --out p.png` → valid PNG |
| 10 | `tlmgr update --all` can leave CTeX without `zhnumber` | M1 | verified | first compile error, then `tlmgr install zhnumber` fixed it |
| 11 | BasicTeX download can truncate at the tail and needs retries | M1 | verified | Homebrew log on 2026-08-30; fixed with `HOMEBREW_CURL_RETRIES=5` |
| 12 | `codesign`/`spctl` fail for all binaries inside the sandbox | M1 | verified (sandbox only) | `CSSMERR_TP_NOT_TRUSTED` for Apple binaries too; conclusion limited to "not evidence" |
| 13 | `texlive-lang-chinese` depends on Arphic fonts and rebuilds the Fontconfig cache | D1 | verified | `apt-get` transcript; `dpkg-query -W` before/after |
| 14 | `--no-install-recommends` does not prevent the Arphic dependencies | D1 | verified | same transcript: they are `Depends`, not `Recommends` |
| 15 | A user-level `rejectfont` rule keeps Arphic fonts out of desktop fallback | D1 | verified | `fc-match` before/after identical after the rule |
| 16 | `ctex` uses Fandol when the desktop has no CJK font configured | D1 | verified | `ctex-fontset-fandol.def` in the log |
| 17 | Removing added fonts + `fc-cache -f` + full reboot restores rendering | D1 | verified | recovery sequence in `debian-fontconfig.md` §6 |
| 18 | Same document builds on macOS and Linux with different fonts | M1, D1 | verified per platform | example falls back to Fandol when Songti is absent |

| 19 | `\setCJKmainfont{FandolSong-Regular}` (family) fails on Ubuntu TeX Live; the `.otf` file name works | CI (ubuntu-latest, apt TeX Live) | verified 2026-11-14 | CI run 43609000774: "font not found" with the family name; file-name binding compiles |
| 20 | `biblatex.sty` lives in `texlive-bibtex-extra`; `--no-install-recommends` omits it even though the example needs it | CI | verified 2026-11-14 | CI run 43609328438: `File 'biblatex.sty' not found` until the package was added |
| 21 | ubuntu-latest + apt TeX Live builds `assets/example` cold, with Fandol embedded and no font-directory change | CI | verified 2026-11-14 | CI run 43609596146 green (doctor, cold-build, repeat build, font invariant) |
| 22 | macOS and Linux reach the same verdict through the same scripts | M1, CI | verified per platform | 23/23 local checks on macOS, 23/23 in CI on Ubuntu |

## Not verified (do not claim)

| Claim | Status |
|---|---|
| `fontset=mac` is broken on all macOS versions | untested — only 26.6.2 measured |
| Intel Macs behave identically | untested |
| LuaLaTeX path works with this font binding | untested — XeLaTeX only |
| TeX Live 2027 keeps the same package names and font behaviour | untested |
| Windows / WSL support | untested, no scripts provided |
| Ubuntu packaging matches Debian 13 for `texlive-lang-chinese` | untested |
| Byte-identical PDF output across macOS and Debian | **false by design** — native fonts vs Fandol |
| The Fandol fallback in `assets/example` builds on a machine without `texlive-lang-chinese` | untested — the fallback assumes Fandol is present |
| Fandol file names are identical across TeX Live versions | untested — only apt TeX Live on ubuntu-latest and the Fandol package contract |
| Local macOS shell can reproduce the Debian font isolation | untested — cross-platform, not re-run |
| The sandbox `codesign` result says anything about the host trust chain | explicitly rejected |

## How to extend this file

When you verify something new, add a row with: the claim, the environment ID (add a new one if the
machine differs), the date, the status, and the command or output that proves it. If a claim later
fails, change its status to `regressed` rather than deleting the row — the history is the point.

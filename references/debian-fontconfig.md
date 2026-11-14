# Debian/Ubuntu desktop: install Chinese TeX without touching the desktop font stack

Environment: Debian 13, XFCE, Fontconfig, Chromium/Electron applications present. Recorded
2026-08-30. The failure below is real and was reproduced: terminals and Electron apps changed
Chinese glyph spacing after a TeX install, and logging out was not enough to recover.

## Why this bites

`texlive-lang-chinese` does not only ship macros. On Debian 13 it **depends on four
`fonts-arphic-*` packages**, which install into `/usr/share/fonts` and trigger a Fontconfig cache
rebuild. `--no-install-recommends` does not prevent this: those are hard dependencies, not
recommendations. It only prevents the much larger `latex-cjk-all` closure (Japanese, Korean, Thai,
more legacy CJK fonts).

The TeX macros themselves need none of those fonts: `ctex` can use TeX Live's own Fandol fonts,
which live inside TEXMF and are invisible to the desktop.

## 1. Baseline (before apt)

```bash
scripts/font-audit.sh save before

mkdir -p ~/latex-install-audit
fc-match sans-serif:lang=zh-cn > ~/latex-install-audit/font-sans-before.txt
fc-match monospace:lang=zh-cn > ~/latex-install-audit/font-mono-before.txt
dpkg-query -W > ~/latex-install-audit/packages-before.txt
```

## 2. Isolate the Arphic fonts first

Create `~/.config/fontconfig/conf.d/99-texlive-cjk-isolation.conf`:

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <selectfont>
    <rejectfont>
      <glob>/usr/share/fonts/truetype/arphic/*</glob>
      <glob>/usr/share/fonts/truetype/arphic-*/*</glob>
    </rejectfont>
  </selectfont>
</fontconfig>
```

This only stops desktop Fontconfig from enumerating those files. It does not delete them and does
not affect TeX Live reading its own TEXMF fonts.

Order matters: write the rule **before** `apt-get install`, so the cache rebuild that the package
triggers already excludes them.

## 3. Install the minimal complete set

```bash
sudo apt-get update
sudo apt-get install --no-install-recommends \
  texlive-xetex texlive-lang-chinese \
  texlive-latex-extra texlive-bibtex-extra texlive-science \
  texlive-fonts-recommended latexmk biber
```

`texlive-bibtex-extra` is where `biblatex.sty` lives on Debian/Ubuntu. It is only a *Recommends*
of `texlive-latex-extra`, so `--no-install-recommends` drops it and the build fails with
```File `biblatex.sty' not found```. Measured in CI on ubuntu-latest (2026-11-14). The `biber`
binary alone is not enough.

Do **not** add unless there is a stated need:

```text
fonts-noto-cjk   fonts-noto-cjk-extra   latex-cjk-all   texlive-full
```

`fonts-noto-cjk` is safe only if the desktop was already using Noto CJK. Adding it as part of a TeX
install changes the fallback chain for every application.

## 4. Refresh and compare

```bash
fc-cache -f
fc-match sans-serif:lang=zh-cn
fc-match monospace:lang=zh-cn
scripts/font-audit.sh save after
scripts/font-audit.sh diff before after
```

`fc-match` must match the "before" output, and the manifest diff must be `UNCHANGED` **if you only
care about the desktop**. When you install `texlive-lang-chinese`, the manifest *will* show the new
Arphic files — that is expected. What must not change is the `fc-match` resolution and the number of
CJK families Fontconfig reports:

```bash
fc-list :lang=zh family | wc -l    # compare with the baseline
```

If `fc-match` changed: fix Fontconfig first. Do not install more fonts to compensate.

## 5. Prove the TeX side uses Fandol, not the desktop fonts

```bash
latexmk -xelatex -interaction=nonstopmode -halt-on-error main.tex
grep -m1 'ctex-fontset-fandol' main.log
```

If you let CTeX pick the fontset (no `fontset=none`, no explicit binding), the log shows
`ctex-fontset-fandol.def` — that is the proof Chinese typesetting came from TEXMF, independent of
the desktop font stack.

If you bind the fonts yourself, address the **files**, not the family. Measured on Ubuntu's TeX
Live (CI, 2026-11-14): `\setCJKmainfont{FandolSong-Regular}` fails with "font not found", while
`\setCJKmainfont{FandolSong-Regular.otf}` succeeds. This is what `assets/example/main.tex` does.

```latex
\setCJKmainfont{FandolSong-Regular.otf}[BoldFont={FandolSong-Bold.otf},
                                        ItalicFont={FandolKai-Regular.otf}]
\setCJKsansfont{FandolHei-Regular.otf}[BoldFont={FandolHei-Bold.otf}]
\setCJKmonofont{FandolFang-Regular.otf}
```

Then run the normal verification loop:

```bash
scripts/doctor.sh
scripts/cold-build.sh --expect-font Fandol
```

## 6. Failure and recovery (observed)

Sequence that broke the desktop: explicitly installing `fonts-noto-cjk` (plus `-extra`) while
`texlive-lang-chinese` pulled in Arphic fonts. After the Fontconfig rebuild, terminal and
Chromium/Electron Chinese spacing was wrong. Logging out did not clear it.

Recovery that worked, in order:

1. `sudo apt-get remove fonts-noto-cjk fonts-noto-cjk-extra`
2. add the user-level `rejectfont` rule for the newly introduced CJK fonts, restoring the previous
   fallback chain
3. `fc-cache -f`
4. full system reboot (not just logout) — some renderers cache font metrics per session
5. `latexmk -g -xelatex` on the combined test document; XeLaTeX, `ctex`, TikZ, PGFPlots and Biber
   all normal

## 7. Scope

Debian 13 + XFCE + Fontconfig, on a desktop with Chromium/Electron apps. Not verified on headless
servers (where the whole issue is moot), on Ubuntu versions with different Arphic packaging, or with
Wayland-only sessions. If you genuinely want Noto CJK on the desktop, configure the app and terminal
fonts explicitly and reboot to verify — do not assume a new font is only used by LaTeX.

Upstream TeX Live installs into a user directory (`install-tl`) usually do not register fonts in
`/usr/share/fonts`, which avoids this class of problem, at the cost of unpinning yourself from APT
management.

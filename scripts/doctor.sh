#!/bin/sh
# doctor.sh — read-only health check for a XeLaTeX / CTeX paper toolchain.
#
# Answers three questions without changing anything:
#   1. are the binaries there, and what TeX Live version is this?
#   2. are the style packages a bilingual paper needs actually installed?
#   3. can XeTeX open a CJK font by family name right now?
#
# Usage: scripts/doctor.sh [-q]
#   -q  only print problems (quiet)
#
# Exit codes: 0 all required checks passed, 1 something required is missing.
set -eu

QUIET=0
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=1 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "doctor.sh: unknown option $arg" >&2; exit 2 ;;
    esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
problem() { printf 'FAIL  %s\n' "$*"; }
warn() { [ "$QUIET" -eq 1 ] || printf 'WARN  %s\n' "$*"; }
ok() { [ "$QUIET" -eq 1 ] || printf 'ok    %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

fail=0

# --- platform ---------------------------------------------------------------
OS=$(uname -s)
say "== platform"
say "   $OS $(uname -r) $(uname -m)"
if [ "$OS" = Darwin ]; then
    say "   $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
elif [ -r /etc/os-release ]; then
    say "   $(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)"
fi

# --- binaries ---------------------------------------------------------------
say "== binaries"
REQUIRED="xelatex kpsewhich"
RECOMMENDED="latexmk biber"
OPTIONAL="pdffonts xdvipdfmx tlmgr"

for b in $REQUIRED; do
    if have "$b"; then ok "$b -> $(command -v "$b")"; else problem "$b not found on PATH"; fail=1; fi
done
for b in $RECOMMENDED; do
    if have "$b"; then ok "$b -> $(command -v "$b")"; else warn "$b not found (needed for bibliography / multi-pass builds)"; fi
done
for b in $OPTIONAL; do
    if have "$b"; then
        ok "$b -> $(command -v "$b")"
    else
        warn "$b not found (optional)"
    fi
done

have xelatex && say "   $(xelatex --version 2>/dev/null | head -n 1)"

# --- style packages ---------------------------------------------------------
say "== packages"
check_sty() { # check_sty <file.sty> <1 if required>
    path=$(kpsewhich "$1" 2>/dev/null || true)
    if [ -n "$path" ]; then
        ok "$1"
    elif [ "$2" = 1 ]; then
        problem "$1 missing  ->  sudo tlmgr install $(echo "$1" | sed 's/\.sty$//')"
        fail=1
    else
        warn "$1 missing"
    fi
}
for sty in ctex.sty xeCJK.sty fontspec.sty zhnumber.sty amsmath.sty \
           booktabs.sty pgfplots.sty siunitx.sty cleveref.sty hyperref.sty; do
    check_sty "$sty" 1
done
check_sty biblatex.sty 0   # optional: only papers that cite need it
check_sty listings.sty 0   # optional: code blocks in the example
# --- CJK font probe ---------------------------------------------------------
say "== CJK font probe"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/latex-doctor.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

if [ "$OS" = Darwin ]; then
    MAIN_FONT="Songti SC Regular"
    SANS_FONT="Heiti SC Light"
else
    MAIN_FONT="FandolSong-Regular"
    SANS_FONT="FandolHei-Regular"
fi

cat >"$TMP/probe.tex" <<EOF
\\documentclass[UTF8,fontset=none]{ctexart}
\\setCJKmainfont{$MAIN_FONT}
\\setCJKsansfont{$SANS_FONT}
\\begin{document}
中文 CJK probe 0123
\\end{document}
EOF

if have xelatex; then
    set +e
    ( cd "$TMP" && xelatex -no-pdf -interaction=nonstopmode -halt-on-error probe.tex ) \
        >"$TMP/probe.out" 2>&1
    probe_status=$?
    set -e
    if [ "$probe_status" -eq 0 ]; then
        ok "XeTeX opened '$MAIN_FONT' and '$SANS_FONT'"
    else
        problem "XeTeX cannot open '$MAIN_FONT' / '$SANS_FONT' by family name"
        grep -E '^(!!|! )|Font .* not found|fontspec error' "$TMP/probe.out" | head -n 5 | sed 's/^/      /'
        if [ "$OS" = Darwin ]; then
            say "      macOS: pin Songti SC / Heiti SC (assets/macos/macos-native-fonts.tex);"
            say "      do not copy fonts into ~/Library/Fonts."
        else
            say "      Debian/Ubuntu: sudo apt-get install --no-install-recommends texlive-lang-chinese"
        fi
        fail=1
    fi
fi

# --- desktop font side effects ---------------------------------------------
say "== desktop font stack"
if have fc-list; then
    n=$(fc-list :lang=zh family 2>/dev/null | wc -l | tr -d ' ')
    say "   fc-list CJK families: $n"
    say "   $(fc-match sans-serif:lang=zh-cn 2>/dev/null)"
    [ "$n" -eq 0 ] && warn "no CJK family visible to Fontconfig (Fandol is inside TEXMF and will not appear here)"
else
    say "   fc-list not available (macOS: normal; system fonts are used directly)"
fi

if [ "$OS" = Darwin ]; then
    for d in /Library/Fonts "$HOME/Library/Fonts"; do
        [ -d "$d" ] || continue
        say "   $d: $(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ') file(s)"
    done
    say "   (TeX Live should not add files here; run scripts/font-audit.sh to prove it)"
fi

say ""
if [ "$fail" -ne 0 ]; then
    printf 'VERDICT: problems found (see FAIL lines above)\n'
    exit 1
fi
printf 'VERDICT: required checks passed\n'

#!/bin/sh
# cold-build.sh — clean-state build and verification for a XeLaTeX paper.
#
# A first compile that happens to succeed proves very little: stale .aux/.bbl files
# hide broken references, and a "PDF generated" message says nothing about whether
# the CJK glyphs were embedded. This script removes that ambiguity:
#
#   1. cold clean  (latexmk -C, then drop .bbl/.bcf/.run.xml/.xdv)
#   2. full build  (latexmk -xelatex, halt on error)
#   3. inspect the log for undefined refs/citations, missing glyphs, missing files
#   4. list the fonts actually embedded in the PDF
#
# Usage:
#   scripts/cold-build.sh [options] [FILE.tex]
#
# Options:
#   --png                  also render page 1 to PNG (sips on macOS, pdftoppm on Linux)
#   --expect-font NAME     fail unless NAME appears in the embedded font list
#                          (repeatable; substring match, e.g. STSongti)
#   -h, --help             show this help
#
# Exit codes: 0 verified, 1 verification failed, 2 usage error.
set -eu

usage() {
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

PNG=0
EXPECT_LIST=""
FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --png) PNG=1 ;;
        --expect-font=*) EXPECT_LIST="${EXPECT_LIST}${1#--expect-font=}
" ;;
        --expect-font)
            [ $# -ge 2 ] || { echo "cold-build.sh: --expect-font needs a value" >&2; exit 2; }
            EXPECT_LIST="${EXPECT_LIST}$2
"
            shift ;;
        -*) echo "cold-build.sh: unknown option $1" >&2; exit 2 ;;
        *) FILE=$1 ;;
    esac
    shift
done

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
[ -n "$FILE" ] || FILE=$REPO/assets/example/main.tex

[ -f "$FILE" ] || { echo "cold-build.sh: no such file: $FILE" >&2; exit 2; }

DIR=$(cd "$(dirname "$FILE")" && pwd)
BASE=$(basename "$FILE" .tex)
LOG="$BASE.log"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cold-build.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

cd "$DIR"

say() { printf '%s\n' "$*"; }
fail=0

# --- tool discovery ---------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

if ! have xelatex; then
    say "FATAL: xelatex not found on PATH (run scripts/doctor.sh)"
    exit 1
fi

# --- 1. cold clean ----------------------------------------------------------
say "== clean: $BASE"
if have latexmk; then
    latexmk -C "$BASE.tex" >/dev/null 2>&1 || true
else
    for ext in aux log out toc lof lot fls fdb_latexmk synctex.gz bbl blg bcf run.xml pdf xdv; do
        rm -f "$BASE.$ext"
    done
fi
# latexmk -C does not always drop these, and a stale .bbl is the classic false pass.
rm -f "$BASE.bbl" "$BASE.blg" "$BASE.bcf" "$BASE.run.xml" "$BASE.xdv" "$BASE.pdf"
say "   removed build products and .bbl"

# --- 2. build ---------------------------------------------------------------
say "== build: latexmk -xelatex $BASE.tex"
set +e
if have latexmk; then
    latexmk -xelatex -synctex=1 -interaction=nonstopmode -halt-on-error "$BASE.tex" \
        >"$TMP/build.out" 2>&1
    status=$?
else
    xelatex -interaction=nonstopmode -halt-on-error "$BASE.tex" >"$TMP/build.out" 2>&1
    status=$?
    if [ "$status" -eq 0 ] && have biber && grep -q 'backend=biber' "$BASE.tex" 2>/dev/null; then
        biber "$BASE" >"$TMP/biber.out" 2>&1 || status=$?
        xelatex -interaction=nonstopmode -halt-on-error "$BASE.tex" >>"$TMP/build.out" 2>&1 || status=$?
        xelatex -interaction=nonstopmode -halt-on-error "$BASE.tex" >>"$TMP/build.out" 2>&1 || status=$?
    fi
fi
set -e

if [ "$status" -ne 0 ] || [ ! -f "$BASE.pdf" ]; then
    say "FAIL: build exited $status (no PDF produced)"
    tail -n 30 "$TMP/build.out"
    exit 1
fi
say "   build ok"

# --- 3. log assertions ------------------------------------------------------
say "== log checks"
check() { # check <label> <extended-regex>
    if grep -Eq "$2" "$LOG" 2>/dev/null; then
        say "   FAIL  $1"
        grep -E "$2" "$LOG" | head -n 5 | sed 's/^/         /'
        fail=1
    else
        say "   ok    $1"
    fi
}

check "no undefined references"      'LaTeX Warning: There were undefined (references|citations)'
check "no undefined reference stray" "^LaTeX Warning: Reference .* undefined"
check "no undefined citations"       "^.*Citation .* undefined"
check "no missing characters"        'Missing character:'
# shellcheck disable=SC2016  # the backtick is part of TeX's error text
check "no missing input files"       'File `[^`]*\.(tex|sty|cls|bib|def|cfg)'"'"' not found'
check "no package errors"            '^! '

if [ -f "$BASE.blg" ] && grep -Eq '^(ERROR|FATAL)' "$BASE.blg"; then
    say "   FAIL  biber reported errors"
    grep -E '^(ERROR|FATAL)' "$BASE.blg" | head -n 5 | sed 's/^/         /'
    fail=1
fi

pages=$(sed -n 's/^Output written on .* (\([0-9][0-9]*\) pages.*/\1/p' "$LOG" | tail -n 1)
[ -n "${pages:-}" ] || pages="?"
overfull=$(grep -c '^Overfull \\hbox' "$LOG" 2>/dev/null || true)
say "   pdf: $BASE.pdf, $pages page(s), overfull hbox: ${overfull:-0}"

# --- 4. embedded fonts ------------------------------------------------------
say "== embedded fonts"
FONTS=""
if have pdffonts; then
    pdffonts "$BASE.pdf" | sed 's/^/   /'
    FONTS=$(pdffonts "$BASE.pdf" | sed -n '3,$p' | awk '{print $1}')
elif have xdvipdfmx && [ -f "$BASE.xdv" ]; then
    # TeX Live ships xdvipdfmx; no poppler needed. The .xdv survives a normal
    # latexmk -xelatex run, so this costs one extra conversion, not an extra build.
    xdvipdfmx -vv -o "$TMP/fontcheck.pdf" "$BASE.xdv" 2>&1 \
        | sed -n 's/.*(CID:\([^)]*\)).*/\1/p' | sort -u >"$TMP/fonts.txt"
    FONTS=$(cat "$TMP/fonts.txt")
    if [ -z "$FONTS" ]; then
        say "   WARN  could not extract font names from $BASE.xdv"
    else
        sed 's/^/   /' "$TMP/fonts.txt"
    fi
else
    say "   SKIP  no pdffonts and no $BASE.xdv — font embedding unverified"
fi

if [ -n "$EXPECT_LIST" ]; then
    while IFS= read -r want; do
        [ -n "$want" ] || continue
        if printf '%s\n' "$FONTS" | grep -Fq "$want"; then
            say "   ok    expected font present: $want"
        else
            say "   FAIL  expected font missing: $want"
            fail=1
        fi
    done <<EOF
$EXPECT_LIST
EOF
fi

# --- optional render --------------------------------------------------------
if [ "$PNG" -eq 1 ]; then
    png="$BASE.png"
    # shellcheck disable=SC2015  # say() always succeeds, so the || branch means "render failed"
    if have sips; then
        sips -s format png "$BASE.pdf" --out "$png" >/dev/null 2>&1 \
            && say "== render: $png (sips)" \
            || say "   WARN  sips failed"
    elif have pdftoppm; then
        # shellcheck disable=SC2015
        pdftoppm -png -r 150 -f 1 -l 1 "$BASE.pdf" "${png%.png}" >/dev/null 2>&1 \
            && say "== render: ${png%.png}-1.png (pdftoppm)" \
            || say "   WARN  pdftoppm failed"
    else
        say "   SKIP  no sips and no pdftoppm"
    fi
fi

if [ "$fail" -ne 0 ]; then
    say ""
    say "VERDICT: failed — do not claim the document builds cleanly."
    exit 1
fi
say ""
say "VERDICT: cold build verified ($pages page(s), references resolved, fonts listed above)."

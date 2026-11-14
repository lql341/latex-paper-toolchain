#!/usr/bin/env bash
# test-tex.sh — everything that needs a real TeX installation.
#
# Skips cleanly (exit 0) when xelatex is absent, so it is safe to run anywhere.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
pass=0
fail=0
skip=0

ok() { printf 'ok    %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }
note() { printf 'skip  %s\n' "$*"; skip=$((skip + 1)); }
section() { printf '\n== %s\n' "$*"; }

if ! command -v xelatex >/dev/null 2>&1; then
    note "TeX layer (xelatex not on PATH)"
    printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
    exit 0
fi

section "doctor"
if "$REPO/scripts/doctor.sh" >/tmp/lpt-doctor.log 2>&1; then
    ok "doctor.sh exit 0"
    grep -E '^ok    (xelatex|ctex\.sty|XeTeX opened)' /tmp/lpt-doctor.log | head -n 3 | sed 's/^/         /'
else
    bad "doctor.sh reported problems (see /tmp/lpt-doctor.log)"
    grep -E '^FAIL' /tmp/lpt-doctor.log | head -n 5 | sed 's/^/         /'
fi

section "font manifest is stable across a build"
FONT_AUDIT_DIR=$(mktemp -d)
export FONT_AUDIT_DIR
if "$REPO/scripts/font-audit.sh" save before >/dev/null 2>&1; then
    ok "snapshot before build"
else
    bad "font-audit save failed"
fi

section "cold build of assets/example"
if [ "$(uname -s)" = Darwin ]; then expect=STSongti; else expect=Fandol; fi
if "$REPO/scripts/cold-build.sh" --expect-font "$expect" >/tmp/lpt-build.log 2>&1; then
    ok "cold-build.sh verified ($expect embedded)"
    sed -n 's/^   pdf: /         /p' /tmp/lpt-build.log
else
    bad "cold-build.sh failed (see /tmp/lpt-build.log)"
    tail -n 15 /tmp/lpt-build.log | sed 's/^/         /'
fi

# A build must not mutate the desktop font stack; that is the whole premise.
if "$REPO/scripts/font-audit.sh" save after >/dev/null 2>&1; then
    if "$REPO/scripts/font-audit.sh" diff before after >/tmp/lpt-fonts.log 2>&1; then
        ok "font directories unchanged by the build"
    else
        bad "build changed the font stack (see /tmp/lpt-fonts.log)"
    fi
fi
rm -rf "$FONT_AUDIT_DIR"
unset FONT_AUDIT_DIR

section "cold build is repeatable"
if "$REPO/scripts/cold-build.sh" >/tmp/lpt-build2.log 2>&1; then
    ok "second cold build verified"
else
    bad "second cold build failed (non-determinism or leftover state)"
fi

section "a missing font is detected, not ignored"
if "$REPO/scripts/cold-build.sh" --expect-font DefinitelyNotEmbedded >/dev/null 2>&1; then
    bad "--expect-font did not fail on a font that is not embedded"
else
    ok "--expect-font fails when the font is absent"
fi

section "broken references are detected, not ignored"
# A deliberately broken copy: without this, the log assertions are untested claims.
tmp=$(mktemp -d)
cp "$REPO/assets/example/main.tex" "$tmp/main.tex"
cp "$REPO/assets/example/refs.bib" "$tmp/refs.bib"
sed -i.bak 's/\\label{sec:method}//' "$tmp/main.tex"
if "$REPO/scripts/cold-build.sh" "$tmp/main.tex" >/tmp/lpt-broken.log 2>&1; then
    bad "cold-build.sh accepted a document with a dangling \\ref"
else
    ok "cold-build.sh rejects a dangling reference"
fi
rm -rf "$tmp"

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1

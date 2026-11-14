#!/usr/bin/env bash
# tests/run-all.sh — repository self-checks.
#
# Two layers:
#   static   — no TeX needed: syntax, frontmatter, links, privacy, versioning
#   tex      — skipped when xelatex is absent: doctor, cold build, font invariants
#
# Usage: bash tests/run-all.sh [--static-only]
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
STATIC_ONLY=0
[ "${1:-}" = "--static-only" ] && STATIC_ONLY=1

pass=0
fail=0
skip=0

ok()   { printf 'ok    %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }
note() { printf 'skip  %s\n' "$*"; skip=$((skip + 1)); }
section() { printf '\n== %s\n' "$*"; }

# --- static -----------------------------------------------------------------
section "shell syntax"
while IFS= read -r f; do
    if sh -n "$f" 2>/dev/null; then ok "$(basename "$f")"; else bad "$(basename "$f") (sh -n)"; fi
done < <(find "$REPO/scripts" -name '*.sh' | LC_ALL=C sort)
while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then ok "$(basename "$f") (bash -n)"; else bad "$(basename "$f") (bash -n)"; fi
done < <(find "$REPO/tests" -name '*.sh' | LC_ALL=C sort)

section "executable bits"
while IFS= read -r f; do
    if [ -x "$f" ]; then ok "$(basename "$f")"; else bad "$(basename "$f") is not executable"; fi
done < <(find "$REPO/scripts" -name '*.sh' | LC_ALL=C sort)

section "SKILL.md frontmatter"
skill="$REPO/SKILL.md"
if [ -f "$skill" ]; then
    if head -n 1 "$skill" | grep -qx -- '---'; then ok "opens with ---"; else bad "does not open with ---"; fi
    name=$(sed -n '1,40p' "$skill" | sed -n 's/^name: *//p' | head -n 1)
    desc=$(sed -n '1,40p' "$skill" | sed -n 's/^description: *//p' | head -n 1)
    if [ "$name" = "$(basename "$REPO")" ]; then
        ok "name matches directory ($name)"
    else
        bad "name '$name' != directory '$(basename "$REPO")'"
    fi
    if [ -n "$desc" ]; then
        ok "description present ($(printf '%s' "$desc" | wc -c | tr -d ' ') chars)"
        [ "$(printf '%s' "$desc" | wc -c)" -le 1024 ] || bad "description exceeds 1024 chars"
    else
        bad "description missing"
    fi
    if grep -q '^# ' "$skill"; then ok "has an H1 heading"; else bad "no H1 heading"; fi
else
    bad "SKILL.md missing"
fi

section "versioning"
version=$(cat "$REPO/VERSION" 2>/dev/null | tr -d '[:space:]')
if [ -n "$version" ]; then ok "VERSION=$version"; else bad "VERSION missing or empty"; fi
if grep -q "^## $version " "$REPO/CHANGELOG.md" 2>/dev/null; then
    ok "CHANGELOG has an entry for $version"
else
    bad "CHANGELOG has no '## $version' entry"
fi
if grep -q "^## " "$REPO/CHANGELOG.md" 2>/dev/null; then ok "CHANGELOG headed by a version section"; fi

section "documentation links"
missing_links=0
while IFS= read -r mdfile; do
    dir=$(dirname "$mdfile")
    while IFS= read -r target; do
        case "$target" in http*|mailto:*|'#'*|'') continue ;; esac
        target=${target%%#*}
        [ -z "$target" ] && continue
        [ -e "$dir/$target" ] || { bad "dead link in $(basename "$mdfile"): $target"; missing_links=$((missing_links + 1)); }
    done < <(grep -oE '\]\([^)]+\)' "$mdfile" | sed 's/^](//; s/)$//')
done < <(find "$REPO" -maxdepth 2 -name '*.md' -not -path '*/.git/*' | LC_ALL=C sort)
[ "$missing_links" -eq 0 ] && ok "all relative links resolve"

section "privacy"
leaks=$(grep -rInE '/Users/[a-z][A-Za-z0-9._-]*|/home/[a-z][A-Za-z0-9._-]*' \
    --include='*.md' --include='*.sh' --include='*.tex' --include='*.bib' \
    --exclude-dir=.git --exclude-dir=tests "$REPO" 2>/dev/null || true)
if [ -n "$leaks" ]; then
    bad "absolute home paths found:"
    printf '%s\n' "$leaks" | sed 's/^/         /'
else
    ok "no absolute home paths"
fi
secrets=$(grep -rInE 'sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY' \
    --exclude-dir=.git --exclude-dir=tests "$REPO" 2>/dev/null || true)
if [ -z "$secrets" ]; then ok "no credential-looking strings"; else bad "credential-looking strings found"; fi

# --- TeX layer --------------------------------------------------------------
if [ "$STATIC_ONLY" -eq 1 ]; then
    note "TeX layer (--static-only)"
elif ! command -v xelatex >/dev/null 2>&1; then
    note "TeX layer (xelatex not on PATH)"
else
    section "doctor"
    if "$REPO/scripts/doctor.sh" >/tmp/latex-toolchain-doctor.log 2>&1; then
        ok "doctor.sh exit 0"
        grep -E '^ok    (xelatex|ctex\.sty|font|XeTeX opened)' /tmp/latex-toolchain-doctor.log | head -n 3 | sed 's/^/         /'
    else
        bad "doctor.sh reported problems (see /tmp/latex-toolchain-doctor.log)"
        grep -E '^FAIL' /tmp/latex-toolchain-doctor.log | head -n 5 | sed 's/^/         /'
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
    if "$REPO/scripts/cold-build.sh" --expect-font "$expect" >/tmp/latex-toolchain-build.log 2>&1; then
        ok "cold-build.sh verified ($expect embedded)"
        sed -n 's/^   pdf: /         /p' /tmp/latex-toolchain-build.log
    else
        bad "cold-build.sh failed (see /tmp/latex-toolchain-build.log)"
        tail -n 15 /tmp/latex-toolchain-build.log | sed 's/^/         /'
    fi

    # A build must not mutate the desktop font stack; that is the whole premise.
    if "$REPO/scripts/font-audit.sh" save after >/dev/null 2>&1; then
        if "$REPO/scripts/font-audit.sh" diff before after >/tmp/latex-toolchain-fonts.log 2>&1; then
            ok "font directories unchanged by the build"
        else
            bad "build changed the font stack (see /tmp/latex-toolchain-fonts.log)"
        fi
    fi
    rm -rf "$FONT_AUDIT_DIR"

    section "cold build is repeatable"
    if "$REPO/scripts/cold-build.sh" >/tmp/latex-toolchain-build2.log 2>&1; then
        ok "second cold build verified"
    else
        bad "second cold build failed (non-determinism or leftover state)"
    fi

    section "missing-font path is detected, not ignored"
    if GONE=MissingNoSuchFont "$REPO/scripts/cold-build.sh" --expect-font DefinitelyNotEmbedded >/dev/null 2>&1; then
        bad "--expect-font did not fail on a font that is not embedded"
    else
        ok "--expect-font fails when the font is absent"
    fi
fi

# --- summary ----------------------------------------------------------------
printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1

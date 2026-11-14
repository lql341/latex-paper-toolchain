#!/usr/bin/env bash
# test-static.sh — checks that need no TeX and no root.
#
# syntax, executable bits, SKILL.md frontmatter, agent manifest, version/release
# documents, documentation links, privacy, repository hygiene, --help smoke test.
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

section "shell syntax"
while IFS= read -r f; do
    if sh -n "$f" 2>/dev/null; then ok "$(basename "$f") (sh -n)"; else bad "$(basename "$f") (sh -n)"; fi
done < <(find "$REPO/scripts" -name '*.sh' | LC_ALL=C sort)
while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then ok "$(basename "$f") (bash -n)"; else bad "$(basename "$f") (bash -n)"; fi
done < <(find "$REPO/tests" -name '*.sh' | LC_ALL=C sort)

section "executable bits"
while IFS= read -r f; do
    if [ -x "$f" ]; then ok "$(basename "$f")"; else bad "$(basename "$f") is not executable"; fi
done < <(find "$REPO/scripts" -name '*.sh' | LC_ALL=C sort)

section "--help smoke test"
while IFS= read -r f; do
    name=$(basename "$f")
    out=$("$f" --help 2>&1)
    status=$?
    # install-debian.sh dies on macOS before parsing --help? No: --help is parsed first.
    if [ "$status" -eq 0 ] && [ -n "$out" ]; then
        ok "$name --help"
    else
        bad "$name --help (exit $status)"
    fi
done < <(find "$REPO/scripts" -name '*.sh' ! -name '_common.sh' | LC_ALL=C sort)

section "SKILL.md frontmatter"
skill="$REPO/SKILL.md"
if [ -f "$skill" ]; then
    if [ "$(head -n 1 "$skill")" = "---" ]; then ok "opens with ---"; else bad "does not open with ---"; fi
    name=$(sed -n '1,40p' "$skill" | sed -n 's/^name: *//p' | head -n 1)
    desc=$(sed -n '1,40p' "$skill" | sed -n 's/^description: *//p' | head -n 1)
    if [ "$name" = "$(basename "$REPO")" ]; then ok "name matches directory ($name)"; else bad "name '$name' != directory '$(basename "$REPO")'"; fi
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

section "agent manifest"
if [ -f "$REPO/agents/openai.yaml" ]; then
    ok "agents/openai.yaml present"
    if grep -q 'display_name' "$REPO/agents/openai.yaml"; then ok "has display_name"; else bad "no display_name"; fi
    if grep -q 'allow_implicit_invocation' "$REPO/agents/openai.yaml"; then ok "has invocation policy"; else bad "no invocation policy"; fi
else
    bad "agents/openai.yaml missing"
fi

section "version and release documents"
if command -v python3 >/dev/null 2>&1; then
    if python3 "$REPO/.github/scripts/release_docs.py" --check >/tmp/lpt-release-docs.log 2>&1; then
        ok "release docs consistent"
    else
        bad "release docs inconsistent (see /tmp/lpt-release-docs.log)"
        tail -n 5 /tmp/lpt-release-docs.log | sed 's/^/         /'
    fi
else
    note "release doc check (python3 not found)"
    version=$(tr -d '[:space:]' <"$REPO/VERSION")
    if grep -q "^## $version " "$REPO/CHANGELOG.md"; then ok "CHANGELOG has $version"; else bad "CHANGELOG has no '## $version'"; fi
fi

section "documentation links"
missing=0
while IFS= read -r mdfile; do
    dir=$(dirname "$mdfile")
    while IFS= read -r target; do
        case "$target" in http*|mailto:*|'#'*|'') continue ;; esac
        target=${target%%#*}
        [ -z "$target" ] && continue
        [ -e "$dir/$target" ] || { bad "dead link in $(basename "$mdfile"): $target"; missing=$((missing + 1)); }
    done < <(grep -oE '\]\([^)]+\)' "$mdfile" | sed 's/^](//; s/)$//')
done < <(find "$REPO" -maxdepth 2 -name '*.md' -not -path '*/.git/*' | LC_ALL=C sort)
[ "$missing" -eq 0 ] && ok "all relative links resolve"

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

section "repository hygiene"
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$REPO" diff --check >/dev/null 2>&1; then ok "no whitespace errors (git diff --check)"; else bad "git diff --check reported whitespace errors"; fi
    if git -C "$REPO" ls-files --error-unmatch VERSION SKILL.md >/dev/null 2>&1; then ok "core files are tracked"; else bad "VERSION or SKILL.md is not tracked"; fi
else
    note "git not initialized"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1

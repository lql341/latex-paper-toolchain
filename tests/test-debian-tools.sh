#!/usr/bin/env bash
# test-debian-tools.sh — the Debian/Ubuntu side.
#
# Two independent parts:
#   fontconfig logic  runs anywhere (hermetic XDG_CONFIG_HOME, platform override)
#   installer plan    runs only where apt-get exists; never installs anything
#
# Nothing here writes the real user config and nothing installs packages, so this
# is safe on a workstation and in CI.
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

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export XDG_CONFIG_HOME="$tmp/xdg"
rule="$XDG_CONFIG_HOME/fontconfig/conf.d/99-texlive-cjk-isolation.conf"

# The Linux branch is exercised on a macOS host too; that is what the override is for.
export LPT_OS_OVERRIDE=Linux
if [ "$(uname -s)" != Linux ]; then
    note "host is $(uname -s); fontconfig logic runs with LPT_OS_OVERRIDE=Linux"
fi

section "fontconfig-isolate.sh: absent state"
if "$REPO/scripts/fontconfig-isolate.sh" --check >"$tmp/check1.log" 2>&1; then
    bad "--check reported the rule present before it was written"
else
    ok "--check reports the rule absent (exit 1)"
fi
if grep -q 'absent' "$tmp/check1.log"; then ok "--check says 'absent'"; else bad "--check did not say 'absent'"; fi

section "fontconfig-isolate.sh: --write"
match_before=$(command -v fc-match >/dev/null 2>&1 && fc-match sans-serif:lang=zh-cn 2>/dev/null || echo "no-fc-match")

if "$REPO/scripts/fontconfig-isolate.sh" --write >"$tmp/write.log" 2>&1; then
    ok "--write exits 0"
else
    bad "--write exited non-zero (see $tmp/write.log)"
    tail -n 5 "$tmp/write.log" | sed 's/^/         /'
fi
if [ -f "$rule" ]; then ok "rule written to the XDG path"; else bad "rule not written to $rule"; fi
if [ -f "$rule" ] && python3 -c 'import sys,xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$rule" 2>/dev/null; then
    ok "rule is well-formed XML"
else
    bad "rule is missing or not well-formed XML"
fi
if grep -q 'arphic' "$rule" 2>/dev/null; then ok "rule targets arphic"; else bad "rule does not target arphic"; fi
if grep -q 'rejectfont' "$rule" 2>/dev/null; then ok "rule uses rejectfont"; else bad "rule does not use rejectfont"; fi

if "$REPO/scripts/fontconfig-isolate.sh" --check >/dev/null 2>&1; then
    ok "--check reports present after --write"
else
    bad "--check still reports absent after --write"
fi

match_after=$(command -v fc-match >/dev/null 2>&1 && fc-match sans-serif:lang=zh-cn 2>/dev/null || echo "no-fc-match")
if [ "$match_before" = "$match_after" ]; then
    ok "default CJK sans family unchanged ($match_before)"
else
    bad "fc-match changed: '$match_before' -> '$match_after'"
fi

section "fontconfig-isolate.sh: idempotent --write"
if "$REPO/scripts/fontconfig-isolate.sh" --write >"$tmp/write2.log" 2>&1 &&
    grep -q 'already present' "$tmp/write2.log"; then
    ok "second --write is a no-op"
else
    bad "second --write changed the file or exited non-zero"
fi

section "fontconfig-isolate.sh: --dry-run writes nothing"
rm -f "$rule"
if "$REPO/scripts/fontconfig-isolate.sh" --write --dry-run >/dev/null 2>&1; then
    if [ -f "$rule" ]; then bad "--dry-run created the rule"; else ok "--dry-run created nothing"; fi
else
    bad "--write --dry-run exited non-zero"
fi

section "fontconfig-isolate.sh: --remove"
"$REPO/scripts/fontconfig-isolate.sh" --write >/dev/null 2>&1
if "$REPO/scripts/fontconfig-isolate.sh" --remove >/dev/null 2>&1; then
    if [ -f "$rule" ]; then bad "--remove left the rule behind"; else ok "--remove deletes the rule"; fi
else
    bad "--remove exited non-zero"
fi
if "$REPO/scripts/fontconfig-isolate.sh" --check >/dev/null 2>&1; then
    bad "--check reports present after --remove"
else
    ok "--check reports absent after --remove"
fi
if "$REPO/scripts/fontconfig-isolate.sh" --remove >/dev/null 2>&1; then
    ok "--remove is idempotent"
else
    bad "second --remove exited non-zero"
fi

section "macOS branch says not-applicable"
if LPT_OS_OVERRIDE=Darwin "$REPO/scripts/fontconfig-isolate.sh" --check >"$tmp/mac.log" 2>&1; then
    if grep -q 'not-applicable' "$tmp/mac.log"; then ok "macOS: not-applicable"; else bad "macOS: unexpected output"; fi
else
    bad "macOS branch did not exit 0"
fi

section "install-debian.sh"
if ! command -v apt-get >/dev/null 2>&1; then
    note "installer plan (no apt-get on this host)"
else
    if out=$("$REPO/scripts/install-debian.sh" --dry-run 2>&1); then
        ok "dry-run exits 0"
    else
        bad "dry-run exited non-zero"
    fi
    for pkg in texlive-xetex texlive-lang-chinese texlive-bibtex-extra texlive-science latexmk biber; do
        case "$out" in
            *"$pkg"*) ok "plan mentions $pkg" ;;
            *) bad "plan does not mention $pkg" ;;
        esac
    done
    case "$out" in
        *"DRY-RUN"*) ok "dry-run states nothing was changed" ;;
        *) bad "dry-run does not state that nothing changed" ;;
    esac
    if printf '%s' "$out" | grep -q 'fonts-noto-cjk'; then
        bad "plan pulls fonts-noto-cjk (must stay out of the install set)"
    else
        ok "plan keeps fonts-noto-cjk out"
    fi
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1

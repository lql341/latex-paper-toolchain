#!/usr/bin/env bash
# run-all.sh — run every test layer and summarise.
#
#   bash tests/run-all.sh                 # all layers (TeX and Debian layers skip themselves)
#   bash tests/run-all.sh --static-only   # no TeX, no apt: safe in any CI
#
# Layers:
#   test-static.sh        syntax, frontmatter, docs, privacy, hygiene, --help
#   test-debian-tools.sh  fontconfig isolation + Debian installer dry-run (hermetic)
#   test-tex.sh           doctor, cold build, font invariants, negative cases
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATIC_ONLY=0
[ "${1:-}" = "--static-only" ] && STATIC_ONLY=1

status=0
run() {
    printf '\n######## %s ########\n' "$1"
    if ! "$HERE/$1"; then status=1; fi
}

run test-static.sh
run test-debian-tools.sh
if [ "$STATIC_ONLY" -eq 1 ]; then
    printf '\n######## test-tex.sh ########\nskip  TeX layer (--static-only)\n'
else
    run test-tex.sh
fi

printf '\n######## summary ########\n'
if [ "$status" -eq 0 ]; then echo "all layers passed"; else echo "at least one layer failed"; fi
exit "$status"

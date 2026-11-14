#!/bin/sh
# font-audit.sh — prove that a TeX install did not touch the desktop font stack.
#
# Installing Chinese TeX support can silently register CJK fonts with the system
# (most notably on Debian, where texlive-lang-chinese depends on fonts-arphic-*,
# which triggers a Fontconfig rebuild and can change how terminals and Electron
# apps render Chinese). The only reliable evidence is a manifest of the font
# directories before and after, compared by content hash.
#
# Usage:
#   scripts/font-audit.sh save before      # snapshot (run this BEFORE installing)
#   sudo apt-get install ...               # any font-affecting change
#   scripts/font-audit.sh save after       # snapshot again
#   scripts/font-audit.sh diff before after
#
#   scripts/font-audit.sh list             # snapshots taken so far
#   scripts/font-audit.sh show before      # print a manifest
#
# Snapshots live in ${FONT_AUDIT_DIR:-$HOME/.latex-font-audit}/.
# Fontconfig state (Linux only) is recorded too, when fc-cache/fc-match exist.
#
# Exit codes: 0 unchanged, 1 changed (or usage error), 2 nothing to compare.
set -eu

# shellcheck source=scripts/_common.sh
. "$(dirname "$0")/_common.sh"
STORE=${FONT_AUDIT_DIR:-$HOME/.latex-font-audit}

cmd_save() { # cmd_save <label>
    label=$1
    mkdir -p "$STORE"
    manifest="$STORE/$label.manifest"
    payload="$STORE/.payload.$label"

    : >"$payload"
    count=0
    for dir in $(font_dirs); do
        [ -d "$dir" ] || continue
        find "$dir" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
            printf '%s|%s|%s\n' "$f" "$(file_size "$f")" "$(file_mtime "$f")"
        done >>"$payload"
        n=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        count=$((count + n))
    done

    # The digest covers the payload only: the header carries a timestamp, and a
    # timestamp that changes on every save would defeat the whole comparison.
    digest=$(sha256_of "$payload")

    {
        echo "# font-audit label=$label"
        echo "# uname=$(uname -s) $(uname -r) $(uname -m)"
        echo "# date=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "# files=$count"
        echo "# sha256=$digest"
        if have fc-match; then
            echo "# fc-match-sans=$(fc-match sans-serif:lang=zh-cn 2>/dev/null || true)"
            echo "# fc-match-mono=$(fc-match monospace:lang=zh-cn 2>/dev/null || true)"
        fi
        cat "$payload"
    } >"$manifest"

    rm -f "$payload"
    printf '%s\n' "$digest" >"$STORE/$label.sha256"
    echo "saved $manifest"
    echo "  files=$count"
    echo "  sha256=$digest"
}

cmd_diff() { # cmd_diff <a> <b>
    a="$STORE/$1.manifest"
    b="$STORE/$2.manifest"
    [ -f "$a" ] && [ -f "$b" ] || { echo "font-audit.sh: missing snapshot (see list)" >&2; exit 2; }

    ha=$(cat "$STORE/$1.sha256" 2>/dev/null || sha256_of "$a")
    hb=$(cat "$STORE/$2.sha256" 2>/dev/null || sha256_of "$b")

    if [ "$ha" = "$hb" ]; then
        echo "UNCHANGED  $1 == $2  (sha256 $ha)"
        exit 0
    fi
    echo "CHANGED    $1 != $2"
    echo "  $1: $ha"
    echo "  $2: $hb"
    echo ""
    # Ignore the header (label/date differ by design), compare payload only.
    grep -v '^#' "$a" >"$STORE/.a.payload"
    grep -v '^#' "$b" >"$STORE/.b.payload"
    diff -u "$STORE/.a.payload" "$STORE/.b.payload" | sed -n '3,200p' || true
    rm -f "$STORE/.a.payload" "$STORE/.b.payload"
    echo ""
    echo "If fonts changed: do NOT fix this by installing more fonts."
    echo "  Debian: add a user fontconfig rejectfont rule (references/debian-fontconfig.md),"
    echo "          then fc-cache -f and compare fc-match output again."
    echo "  macOS:  remove what was added; TeX Live fonts belong in TEXMF, not /Library/Fonts."
    exit 1
}

cmd_list() {
    [ -d "$STORE" ] || { echo "no snapshots in $STORE"; return 0; }
    for f in "$STORE"/*.manifest; do
        [ -f "$f" ] || continue
        base=${f%.manifest}
        printf '%-20s %s  %s\n' "$(basename "$base")" \
            "$(cat "$base.sha256" 2>/dev/null | cut -c1-16)" \
            "$(sed -n 's/^# files=//p' "$f")"
    done
}

cmd_show() {
    manifest="$STORE/$1.manifest"
    [ -f "$manifest" ] || { echo "font-audit.sh: no snapshot '$1'" >&2; exit 2; }
    cat "$manifest"
}

action=${1:-}
case "$action" in
    save)  [ $# -eq 2 ] || { echo "usage: font-audit.sh save <label>" >&2; exit 2; }; cmd_save "$2" ;;
    diff)  [ $# -eq 3 ] || { echo "usage: font-audit.sh diff <a> <b>" >&2; exit 2; }; cmd_diff "$2" "$3" ;;
    list)  cmd_list ;;
    show)  [ $# -eq 2 ] || { echo "usage: font-audit.sh show <label>" >&2; exit 2; }; cmd_show "$2" ;;
    -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "font-audit.sh: unknown command '$action'" >&2; exit 2 ;;
esac

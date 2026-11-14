#!/bin/sh
# fontconfig-isolate.sh — keep TeX-installed CJK fonts out of the desktop fallback chain.
#
# On Debian/Ubuntu, `texlive-lang-chinese` depends on four `fonts-arphic-*` packages.
# Installing them registers new CJK fonts with Fontconfig, which can change how
# terminals and Chromium/Electron applications render Chinese. The fix is a user-level
# `rejectfont` rule written BEFORE `apt-get install`, so the cache rebuild that the
# package triggers already excludes them.
#
# Usage:
#   scripts/fontconfig-isolate.sh --check    # is the rule in place? (default)
#   scripts/fontconfig-isolate.sh --write    # create it, then refresh the cache
#   scripts/fontconfig-isolate.sh --remove   # delete it, then refresh the cache
#
# Options:
#   --dry-run      print what would change, write nothing
#   --file PATH    use a different rule path (default: <XDG_CONFIG_HOME>/fontconfig/conf.d)
#   -h, --help     show this help
#
# Exit codes: --check returns 0 when the rule is present (or the platform is macOS,
# where this problem does not exist), 1 when it is missing. Other actions return 0.
set -eu

action=""
dry_run=0
conf=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check) action="check" ;;
        --write|--add) action="write" ;;
        --remove|--delete) action="remove" ;;
        --dry-run) dry_run=1 ;;
        --file)
            [ $# -ge 2 ] || { echo "fontconfig-isolate.sh: --file needs a path" >&2; exit 2; }
            conf=$2
            shift ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "fontconfig-isolate.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done
[ -n "$action" ] || action="check"

# shellcheck source=scripts/_common.sh
. "$(dirname "$0")/_common.sh"

[ -n "$conf" ] || conf="$(fontconfig_conf_d)/$FONTCONFIG_RULE"

rule_body() {
    cat <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <!-- Written by latex-paper-toolchain/scripts/fontconfig-isolate.sh.
       Keeps the Arphic fonts that `texlive-lang-chinese` pulls in out of the
       desktop fallback chain. The files stay on disk; TeX Live reads its own
       TEXMF fonts regardless of this rule. -->
  <selectfont>
    <rejectfont>
      <glob>/usr/share/fonts/truetype/arphic/*</glob>
      <glob>/usr/share/fonts/truetype/arphic-*/*</glob>
    </rejectfont>
  </selectfont>
</fontconfig>
XML
}

rule_present() {
    [ -f "$conf" ] || return 1
    grep -q 'arphic' "$conf" 2>/dev/null || return 1
    grep -q 'rejectfont' "$conf" 2>/dev/null || return 1
}

refresh_cache() {
    if have fc-cache; then
        say "   refreshing the Fontconfig cache (fc-cache -f)"
        [ "$dry_run" -eq 1 ] || fc-cache -f >/dev/null 2>&1 || warn "fc-cache -f failed"
    else
        warn "fc-cache not found; the desktop will rebuild its cache on next login"
    fi
}

show_match() {
    have fc-match || return 0
    say "   fc-match sans-serif:lang=zh-cn -> $(fc-match sans-serif:lang=zh-cn 2>/dev/null || true)"
    say "   fc-match monospace:lang=zh-cn  -> $(fc-match monospace:lang=zh-cn 2>/dev/null || true)"
}

if is_darwin; then
    if [ "$action" = "check" ]; then
        say "not-applicable  macOS: TeX Live fonts stay in TEXMF and are never registered"
    else
        say "not-applicable  macOS has no Arphic dependency problem; nothing written"
    fi
    exit 0
fi

case "$action" in
    check)
        if rule_present; then
            say "present  $conf"
            show_match
            exit 0
        fi
        say "absent   $conf"
        say "         run: $0 --write    (do this BEFORE apt-get install)"
        show_match
        exit 1
        ;;

    write)
        say "== fontconfig isolation"
        say "   rule: $conf"
        if rule_present; then
            say "   already present, nothing to do"
        elif [ "$dry_run" -eq 1 ]; then
            say "   DRY-RUN would create the directory $(dirname "$conf")"
            say "   DRY-RUN would write:"
            rule_body | sed 's/^/         /'
        else
            mkdir -p "$(dirname "$conf")"
            tmp="$conf.tmp.$$"
            rule_body >"$tmp"
            mv "$tmp" "$conf"
            say "   wrote $(wc -l <"$conf" | tr -d ' ') line(s)"
        fi
        refresh_cache
        say "== resolution after the rule"
        show_match
        ;;

    remove)
        say "== remove fontconfig isolation"
        if [ -f "$conf" ]; then
            if [ "$dry_run" -eq 1 ]; then
                say "   DRY-RUN would delete $conf"
            else
                rm -f "$conf"
                say "   deleted $conf"
            fi
        else
            say "   no rule at $conf (nothing to remove)"
        fi
        refresh_cache
        show_match
        ;;
esac

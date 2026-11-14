#!/bin/sh
# _common.sh — shared helpers for this skill's scripts. Source it, never run it:
#
#   . "$(dirname "$0")/_common.sh"
#
# POSIX sh only: `doctor.sh` and `font-audit.sh` are /bin/sh scripts, so everything
# here has to work on macOS's bash-as-sh, dash and busybox ash alike. No arrays, no
# `local`, nothing that only bash understands.

LPT_REPO=$(cd "$(dirname "$0")/.." && pwd)
LPT_OS=$(uname -s)
LPT_QUIET=0
LPT_FAIL=0
# Exported so the sourcing script sees the same values in any subshell.
export LPT_REPO LPT_OS LPT_QUIET LPT_FAIL

have() { command -v "$1" >/dev/null 2>&1; }

# LPT_OS_OVERRIDE exists so the test suite can exercise the Linux branch of a
# platform-dependent script on a macOS host. It is never set by the scripts
# themselves, and it must not be used to install anything.
is_darwin() {
    [ "${LPT_OS_OVERRIDE:-$LPT_OS}" = Darwin ]
}

say() { [ "$LPT_QUIET" -eq 1 ] && return 0; printf '%s\n' "$*"; }
ok() { [ "$LPT_QUIET" -eq 1 ] && return 0; printf 'ok    %s\n' "$*"; }
warn() { [ "$LPT_QUIET" -eq 1 ] && return 0; printf 'WARN  %s\n' "$*"; }
problem() { printf 'FAIL  %s\n' "$*"; LPT_FAIL=$((LPT_FAIL + 1)); }
die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
note() { [ "$LPT_QUIET" -eq 1 ] && return 0; printf 'note  %s\n' "$*"; }

verdict() { # verdict <ok message>
    [ "$LPT_FAIL" -eq 0 ] || { printf '\nVERDICT: failed (%s problem(s))\n' "$LPT_FAIL"; return 1; }
    printf '\nVERDICT: %s\n' "$1"
}

# --- hashing and stat, portable across GNU and BSD ---------------------------
sha256_of() { # sha256_of <file>
    if have sha256sum; then sha256sum "$1" | awk '{print $1}'
    elif have shasum; then shasum -a 256 "$1" | awk '{print $1}'
    else cksum "$1" | awk '{print $1"-"$2}'
    fi
}

file_size() { # file_size <file>
    if is_darwin; then stat -f '%z' "$1" 2>/dev/null || echo 0
    else stat -c '%s' "$1" 2>/dev/null || echo 0
    fi
}

file_mtime() { # file_mtime <file>
    if is_darwin; then stat -f '%m' "$1" 2>/dev/null || echo 0
    else stat -c '%Y' "$1" 2>/dev/null || echo 0
    fi
}

# --- desktop font stack ------------------------------------------------------
# Where a platform keeps system and user fonts. TeX Live's own fonts live in TEXMF
# and must never appear in these directories.
font_dirs() {
    if [ -n "${FONT_AUDIT_DIRS:-}" ]; then
        # Space-separated override (test/CI seam, like LPT_OS_OVERRIDE): lets the
        # suite run font-audit against a throwaway directory instead of the real
        # system paths, so "diff detects a change" can actually be tested.
        # shellcheck disable=SC2086  # word splitting is the point here
        printf '%s\n' $FONT_AUDIT_DIRS
        return 0
    fi
    if is_darwin; then
        printf '%s\n' /System/Library/Fonts /Library/Fonts "$HOME/Library/Fonts"
    else
        printf '%s\n' /usr/share/fonts /usr/local/share/fonts \
            "$HOME/.fonts" "$HOME/.local/share/fonts"
    fi
}

# Fontconfig user configuration directory (Linux desktops; harmless on macOS).
fontconfig_conf_d() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d"
}

# Name of the isolation rule this repository installs.
FONTCONFIG_RULE=99-texlive-cjk-isolation.conf
export FONTCONFIG_RULE

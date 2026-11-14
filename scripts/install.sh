#!/bin/sh
# install.sh — put this skill where agent harnesses look for skills.
#
#   ./scripts/install.sh                  # user level: ~/.agents/skills/<name>
#   ./scripts/install.sh --project        # ./.agents/skills/<name> (this repo's project)
#   ./scripts/install.sh --claude         # also link ~/.claude/skills/<name>
#   ./scripts/install.sh --codex          # also link ~/.codex/skills/<name>
#   ./scripts/install.sh --link           # symlink instead of copying (edit = live)
#   ./scripts/install.sh --dest DIR       # explicit destination
#
# ~/.agents/skills is the shared location read by pi and Claude Code. Codex scans it
# on some machines only, hence the optional per-harness links. Existing installations
# are backed up with a timestamp, never overwritten silently.
#
# Copying is the default because a copied skill keeps working after the repo moves.
# `--link` is for developing this repository.
set -eu

# shellcheck source=scripts/_common.sh
. "$(dirname "$0")/_common.sh"

SKILL_NAME=$(basename "$LPT_REPO")
SRC=$LPT_REPO
mode="user"
link=0
dest=""
also_claude=0
also_codex=0

while [ $# -gt 0 ]; do
    case "$1" in
        --user) mode="user" ;;
        --project) mode="project" ;;
        --claude) also_claude=1 ;;
        --codex) also_codex=1 ;;
        --link) link=1 ;;
        --dest)
            [ $# -ge 2 ] || { echo "install.sh: --dest needs a path" >&2; exit 2; }
            dest=$2
            shift ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done

if [ -n "$dest" ]; then
    target=$dest
elif [ "$mode" = "project" ]; then
    target="$PWD/.agents/skills/$SKILL_NAME"
else
    target="$HOME/.agents/skills/$SKILL_NAME"
fi

# Compare directories by canonical path, not by string: ~/.agents/skills is often a
# symlink into a shared checkout, in which case the "destination" *is* the source and
# moving it aside would destroy the repository being installed from.
same_dir() { # same_dir <a> <b>
    [ -e "$1" ] && [ -e "$2" ] || return 1
    a=$(cd "$1" 2>/dev/null && pwd -P) || return 1
    b=$(cd "$2" 2>/dev/null && pwd -P) || return 1
    [ "$a" = "$b" ]
}

install_into() { # install_into <target-dir> <label>
    tgt=$1
    label=$2
    say "== $label"
    say "   $tgt"

    if same_dir "$tgt" "$SRC"; then
        say "   source and destination resolve to the same directory; nothing to do"
        say "   ($(cd "$SRC" && pwd -P))"
        return 0
    fi

    parent=$(dirname "$tgt")
    mkdir -p "$parent"

    if [ -e "$tgt" ] || [ -L "$tgt" ]; then
        if [ "$link" -eq 1 ] && [ -L "$tgt" ] && same_dir "$(readlink "$tgt")" "$SRC"; then
            say "   already linked correctly"
            return 0
        fi
        backup="$tgt.bak.$(date +%Y%m%d%H%M%S)"
        mv "$tgt" "$backup"
        say "   backed up existing installation -> $backup"
    fi

    if [ "$link" -eq 1 ]; then
        ln -s "$SRC" "$tgt"
        say "   linked (changes to the repo are live)"
    else
        cp -R "$SRC" "$tgt"
        # A copy must not carry the repository's git metadata or build products.
        rm -rf "$tgt/.git"
        find "$tgt" -name '*.aux' -o -name '*.log' -o -name '*.pdf' -o -name '*.xdv' \
            -o -name '*.bbl' -o -name '*.fls' -o -name '*.fdb_latexmk' 2>/dev/null \
            | while IFS= read -r f; do rm -f "$f"; done
        say "   copied"
    fi

    [ -f "$tgt/SKILL.md" ] || die "$tgt/SKILL.md is missing after install"
    say "   verified: SKILL.md present"
}

install_into "$target" "skill ($SKILL_NAME)"

if [ "$also_claude" -eq 1 ]; then
    install_into "$HOME/.claude/skills/$SKILL_NAME" "Claude Code"
fi
if [ "$also_codex" -eq 1 ]; then
    install_into "$HOME/.codex/skills/$SKILL_NAME" "Codex"
fi

say ""
say "Reload the agent (pi: /reload) to pick the skill up."
say "Self-check the installation: bash \"$target/tests/run-all.sh\""

#!/bin/sh
# install-debian.sh — the Debian/Ubuntu side of this skill, as an executable procedure.
#
# Dry-run by default: it prints the exact commands and the packages, and changes
# nothing. `--apply` runs them in the order that keeps the desktop font stack intact
# (isolation rule FIRST, then apt), then records a before/after font manifest.
#
# Usage:
#   scripts/install-debian.sh                  # dry-run: show the plan
#   scripts/install-debian.sh --apply          # execute it (sudo unless already root)
#   scripts/install-debian.sh --apply --skip-isolate   # no fontconfig rule (servers)
#
# Options:
#   --apply              run the plan
#   --dry-run            force dry-run (default)
#   --skip-isolate       do not write ~/.config/fontconfig/conf.d/99-*.conf
#   --no-audit           do not take font-audit snapshots around the install
#   -h, --help           show this help
#
# What is installed, and why only this much:
#   texlive-xetex                 xelatex + xdvipdfmx (the engine this skill targets)
#   texlive-lang-chinese          ctex, xeCJK, zhnumber, and the Fandol fonts
#   texlive-latex-extra           booktabs, listings, plenty of paper packages
#   texlive-bibtex-extra          biblatex.sty — only a Recommends of latex-extra,
#                                 so --no-install-recommends drops it without this
#   texlive-science               siunitx, cleveref
#   texlive-fonts-recommended     base font set for the standard classes
#   latexmk, biber                build driver and bibliography backend
#
# Deliberately NOT installed: texlive-full, latex-cjk-all, fonts-noto-cjk,
# fonts-noto-cjk-extra. See references/debian-fontconfig.md.
set -eu

apply=0
isolate=1
audit=1

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) apply=1 ;;
        --dry-run) apply=0 ;;
        --skip-isolate) isolate=0 ;;
        --no-audit) audit=0 ;;
        -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install-debian.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done

# shellcheck source=scripts/_common.sh
. "$(dirname "$0")/_common.sh"

PACKAGES="texlive-xetex texlive-lang-chinese texlive-latex-extra texlive-bibtex-extra \
texlive-science texlive-fonts-recommended latexmk biber"

if is_darwin; then
    die "this script targets Debian/Ubuntu. On macOS use:
       brew install --cask basictex
       sudo tlmgr install ctex xecjk zhnumber latexmk biber biblatex pgfplots siunitx cleveref
       (see references/macos-native-fonts.md)"
fi

if ! have apt-get; then
    die "apt-get not found; this script supports Debian/Ubuntu only"
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo "
fi

say "== plan"
say "   1. record the desktop font baseline      ($(basename "$0") --no-audit to skip)"
if [ "$isolate" -eq 1 ]; then
    say "   2. write the fontconfig isolation rule   $(fontconfig_conf_d)/$FONTCONFIG_RULE"
else
    say "   2. SKIP fontconfig isolation (--skip-isolate)"
fi
say "   3. ${SUDO}apt-get update"
say "   4. ${SUDO}apt-get install --no-install-recommends \\"
for p in $PACKAGES; do
    say "        $p"
done
say "   5. verify: doctor.sh, cold-build.sh, font-audit.sh diff"

if [ "$apply" -eq 0 ]; then
    say ""
    say "DRY-RUN: nothing was changed. Re-run with --apply to execute."
    exit 0
fi

say ""
say "== execution"

audit_dir=$(mktemp -d "${TMPDIR:-/tmp}/lpt-audit.XXXXXX")
trap 'rm -rf "$audit_dir"' EXIT INT TERM
if [ "$audit" -eq 1 ]; then
    FONT_AUDIT_DIR=$audit_dir "$LPT_REPO/scripts/font-audit.sh" save before-install >/dev/null
    say "   baseline recorded in $audit_dir"
fi

if [ "$isolate" -eq 1 ]; then
    "$LPT_REPO/scripts/fontconfig-isolate.sh" --write | sed 's/^/   /'
fi

say "   ${SUDO}apt-get update"
# shellcheck disable=SC2086
${SUDO}apt-get update -qq

say "   ${SUDO}apt-get install --no-install-recommends ..."
# shellcheck disable=SC2086
${SUDO}apt-get install -y --no-install-recommends $PACKAGES

say ""
say "== verification"
if have xelatex; then
    "$LPT_REPO/scripts/doctor.sh" -q || warn "doctor.sh reported problems"
    say "   (full build: scripts/cold-build.sh --expect-font Fandol)"
else
    warn "xelatex is still not on PATH; check the apt output above"
fi

if [ "$audit" -eq 1 ]; then
    FONT_AUDIT_DIR=$audit_dir "$LPT_REPO/scripts/font-audit.sh" save after-install >/dev/null
    say ""
    say "== font manifest"
    # New Arphic files are EXPECTED here; what matters is that the resolution of
    # the default sans/mono CJK families did not change.
    FONT_AUDIT_DIR=$audit_dir "$LPT_REPO/scripts/font-audit.sh" diff before-install after-install \
        >"$audit_dir/diff.txt" 2>&1 || true
    changed=$(grep -c '^[+-][^+-]' "$audit_dir/diff.txt" 2>/dev/null || true)
    say "   font files added/removed: ${changed:-0} (Arphic packages are expected)"
    if have fc-match; then
        say "   fc-match sans-serif:lang=zh-cn -> $(fc-match sans-serif:lang=zh-cn 2>/dev/null || true)"
        say "   If that family changed, fix Fontconfig before installing anything else"
        say "   (references/debian-fontconfig.md §6)."
    fi
fi

say ""
say "Done. Next: scripts/doctor.sh && scripts/cold-build.sh --expect-font Fandol"

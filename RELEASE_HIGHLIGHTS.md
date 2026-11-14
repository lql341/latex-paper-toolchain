# Release highlights — latex-paper-toolchain

- `scripts/install.sh` no longer destroys the checkout it installs from. It compared destination and
  source as strings; on a machine where `~/.agents/skills` is a symlink into the same repository
  those are one directory with two names, so it moved the repository aside as a "backup" and then
  failed to copy from a path that no longer existed. Both sides are now resolved with `pwd -P`.
- Re-running `install.sh --link` against an existing symlinked installation is a no-op instead of a
  re-link.
- The static test layer covers both install layouts: a symlinked skills root (source intact, no
  backup of the source) and a genuine install into a fresh destination (SKILL.md present, `.git`
  stripped).

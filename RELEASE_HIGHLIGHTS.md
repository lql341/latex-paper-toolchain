# Release highlights — latex-paper-toolchain

- Debian/Ubuntu is now executable, not just documented: `scripts/install-debian.sh` prints its
  plan by default and `--apply` runs it in the safe order (fontconfig isolation first, then apt,
  then a before/after font manifest).
- `scripts/fontconfig-isolate.sh` writes, checks and removes the user-level `rejectfont` rule that
  keeps the Arphic fonts pulled in by `texlive-lang-chinese` out of the desktop fallback chain.
- `scripts/install.sh` installs the skill into `~/.agents/skills` (plus optional Claude Code and
  Codex locations), copying by default and backing up whatever it replaces.
- Shared helpers moved into `scripts/_common.sh`; every script is still POSIX sh and passes
  `shellcheck -s sh`.
- The test suite is split by layer (`test-static.sh`, `test-debian-tools.sh`, `test-tex.sh`) and now
  includes negative cases: a document with a dangling `\ref` must fail, and `--expect-font` must
  fail when the font is absent.
- CI mirrors the repository contract: validation, a real TeX build installed through the skill's own
  Debian installer, the hermetic fontconfig cycle, and release publication from these highlights.

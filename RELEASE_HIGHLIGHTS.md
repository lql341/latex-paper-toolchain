# Release highlights — latex-paper-toolchain

- The skill name is an identity, not a directory. `release_docs.py` and `test-static.sh` compare
  `SKILL.md`'s `name` against `latex-paper-toolchain` instead of the checkout directory, so a fork,
  a CI workspace, or `git clone <url> my-copy` no longer fails validation for the wrong reason.
- `install.sh` reads the name from the frontmatter, so a differently named checkout still installs
  as `latex-paper-toolchain` rather than as the local directory name.
- `--dest DIR` is a skills root now: the skill lands in `DIR/<skill-name>`, which makes the
  installed path independent of how the script was invoked.
- Both behaviours are covered by the static test layer.

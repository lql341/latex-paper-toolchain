# Release highlights — latex-paper-toolchain

- `font-audit.sh` can now be tested in both directions. Previously the suite only asserted
  "unchanged", which is an assertion that cannot fail; with a `FONT_AUDIT_DIRS` seam the tests prove
  that a modified, added or removed font file is reported as `CHANGED` (and that the added file is
  named in the diff).
- `cold-build.sh --png` is exercised by the TeX layer: it now fails if the render line is missing,
  the renderer errored, or no image appeared.
- `docs/ROADMAP.md` gains R7: required status checks are repository settings, not files, and the
  exact `gh api` call that enables them is written down.

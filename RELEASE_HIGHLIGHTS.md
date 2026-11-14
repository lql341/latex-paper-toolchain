# Release highlights — latex-paper-toolchain

- New `docs/ROADMAP.md`: the four things this repository does **not** automate — Windows/WSL, a real
  BasicTeX build on a CI runner, end-to-end desktop-font verification on a real Debian desktop, and
  confirming the TeX Live 2020 floor — each with its blocker and a copy-pasteable manual procedure.
- LuaLaTeX (declined) and Intel Mac (blocked, no hardware) are recorded rather than silently absent.
- The document defines its own lifecycle and a document map: which file answers which question, and
  what to move where when an item is finished.
- Documentation only; no script or behaviour changed in this release.

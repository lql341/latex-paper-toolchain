# Release highlights — latex-paper-toolchain

- `doctor.sh` states the **feature floor** instead of letting a build die: it detects siunitx v3
  (`\qty`) and pgfplots 1.18 (`compat=1.18`) from the installed packages. The bundled example needs
  TeX Live >= 2021, and on Debian 11 / Ubuntu 20.04 the old behaviour was an
  `Undefined control sequence \qty` pointing at the document rather than at the installation.
- The floor is documented in the skill, both READMEs, the troubleshooting reference (siunitx v2
  fallback, upstream `install-tl` route) and the verification matrix — including the fact that no
  TeX Live 2020 machine was available to test it.
- CI now runs the static and Debian-tools layers on macOS as well, to catch BSD-vs-GNU drift in
  `stat`, `sed -i` and `mktemp`; BasicTeX is still only exercised on a real machine.
- `install.sh --minimal` installs without `tests/` and `.github/`; `_common.sh` is correctly marked
  as a library rather than an executable, and the static layer asserts both facts.

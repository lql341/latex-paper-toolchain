# Roadmap and manual checks

What is deliberately **not** automated, why, and how a human closes it. `references/verified-matrix.md`
records what has been measured; this file records what has not.

## How this file works

- Statuses: `open` (someone could start today), `blocked` (needs hardware/OS/CI runner that is not
  available), `manual-only` (automating it would produce a test that proves nothing), `declined`
  (decided against, reason recorded).
- When an item is finished: move its evidence into `references/verified-matrix.md` (environment ID,
  date, command, output), add a line to `CHANGELOG.md`, then **delete the item here**. A finished
  item must not stay in this file as a trophy.
- Never mark something verified because a script passed elsewhere. The matrix requires an
  environment and a date; this file requires a named blocker.
- Keep the numbering stable: `R<n>` is referenced from commit messages and matrix rows.

## Open items

### R1 — Windows / WSL support `blocked`

**Why:** the scripts are POSIX sh and would probably run under Git Bash, but the toolchain this
skill verifies (BasicTeX, Fontconfig, `sips`) has no Windows equivalent. A `windows-latest` job that
runs the static layer might work and might produce false reds, which is worse than nothing.

**What is missing:** a Windows machine or WSL2 instance to run
`bash tests/run-all.sh --static-only` on. Suspect commands: `stat -c`, `find -o`, `mktemp -d`,
`ln -s`, `readlink`, and the `pwd -P` canonicalisation in `install.sh`.

**Done looks like:** the static layer passes under Git Bash *and* WSL2, at least one TeX path is
documented (MiKTeX/TeX Live for Windows), and the matrix gains a `W1` environment row. Until then
`SKILL.md` keeps claiming macOS and Linux only.

### R2 — macOS CI that installs a real BasicTeX `blocked`

**Why blocked:** `brew install --cask basictex` needs `sudo`, takes minutes, and on a hosted runner
it mostly re-tests what the author's machine already covers, while adding a slow flaky lane to every
push.

**Current coverage:** `validate.yml` runs the static and Debian-tools layers on `macos-latest`
(fast, catches BSD-vs-GNU drift). The real BasicTeX build is verified on a physical Mac only.

**Manual run, quarterly or before a release:**

```bash
git clone https://github.com/lql341/latex-paper-toolchain /tmp/lpt-check
cd /tmp/lpt-check && bash tests/run-all.sh          # all three layers, real TeX
scripts/doctor.sh | sed -n '/feature floors/,$p'    # versions actually in use
rm -rf /tmp/lpt-check
```

Record `sw_vers -productVersion`, the `BasicTeX`/TeX Live version, and the date as a new row in the
matrix if anything changed.

### R3 — Debian desktop isolation, end to end `manual-only`

**Why not automated:** the damage this skill prevents is a *desktop rendering* change (terminals,
Chromium/Electron). CI has no desktop, so an automated test can only prove that a file was written
and `fc-match` did not move — which is already covered hermetically by `tests/test-debian-tools.sh`.
Claiming more from CI would be dishonest.

**Manual protocol, on a disposable Debian or Ubuntu desktop:**

```bash
scripts/font-audit.sh save before
fc-match sans-serif:lang=zh-cn > /tmp/zh-sans-before.txt
fc-match monospace:lang=zh-cn  > /tmp/zh-mono-before.txt
fc-list :lang=zh family | wc -l > /tmp/zh-count-before.txt
# take screenshots of a terminal and a Chromium/Electron window showing Chinese text

scripts/fontconfig-isolate.sh --write
sudo scripts/install-debian.sh --apply

scripts/font-audit.sh save after
scripts/font-audit.sh diff before after      # Arphic files WILL appear: expected
diff /tmp/zh-sans-before.txt <(fc-match sans-serif:lang=zh-cn)   # must be empty
diff /tmp/zh-count-before.txt <(fc-list :lang=zh family | wc -l) # must be empty
# compare the screenshots by eye; then reboot and compare again
```

**Done looks like:** a new `D2` environment row in the matrix stating that the default CJK
resolution and the desktop rendering were unchanged, with the distro, desktop, and date. The
screenshots stay off-repository (privacy); record their hashes if a durable artifact is wanted.

### R4 — Confirm the TeX Live 2020 floor `open`

**Why open, not blocked:** any machine with Docker or a VM can do it; only this workstation lacks a
container runtime.

**What to prove:** that `assets/example/main.tex` fails on TeX Live 2020 with
`Undefined control sequence \qty`, and that the documented siunitx v2 fallback then builds.

```bash
docker run --rm -it debian:11 bash
apt-get update && apt-get install -y --no-install-recommends \
  texlive-xetex texlive-lang-chinese texlive-latex-extra texlive-bibtex-extra \
  texlive-science texlive-fonts-recommended latexmk biber git
git clone https://github.com/lql341/latex-paper-toolchain /tmp/lpt && cd /tmp/lpt
scripts/doctor.sh            # expect the siunitx-v2 warning, exit 0
scripts/cold-build.sh        # expect failure: \qty unknown
# apply the fallback from references/troubleshooting.md, then rebuild
```

**Done looks like:** a `TL2020` environment row with both outcomes (fails as predicted; fallback
builds), and the `doctor.sh` warning wording confirmed against a real v2 installation.

### R5 — LuaLaTeX `declined for now`

`assets/macos/macos-native-fonts.tex` and the Fandol binding are XeLaTeX paths. LuaLaTeX would need
its own font binding, its own `latexmk` invocation and a second verification pass, for a workflow
nobody here uses. Revisit if a real paper needs it; do not add a half-supported engine flag.

### R6 — Intel Mac `blocked`

No Intel Mac available. `doctor.sh` and `cold-build.sh` would take five minutes there; the only
expected difference is font family availability (`Songti SC` exists on Intel macOS too, but the
`Supplemental` directory layout differs and was never checked on that platform). Record as `M2` if
one ever shows up.

### R7 — Repository settings: required checks `manual-only`

**Why manual:** branch protection and "required status checks" are repository settings, not files;
they need admin rights and they change how every contributor (including the maintainer) pushes.

**Current state:** `validate.yml` runs on every push to `main` and on pull requests, and
`release.yml` only publishes after a successful validation. Nothing *forces* a push to wait for it,
so a broken commit can land and be fixed in the next one — acceptable for a single maintainer, not
for a repository with outside pull requests.

**How to close it** (needs the repository admin token):

```bash
gh api -X PUT repos/lql341/latex-paper-toolchain/branches/main/protection \
  -F required_status_checks.strict=true \
  -F 'required_status_checks.contexts[]=static checks' \
  -F 'required_status_checks.contexts[]=Debian tools (hermetic)' \
  -F 'required_status_checks.contexts[]=static checks (macOS)' \
  -F 'required_status_checks.contexts[]=Real XeLaTeX build (installed by the skill itself)' \
  -F enforce_admins=false \
  -F required_pull_request_reviews= \
  -F restrictions=
```

**Done looks like:** a direct push that fails validation is rejected (or at least visibly blocked for
pull requests), and this item is deleted. Until then, the release workflow's "is the tag already
published" check is what keeps the damage local.

## Document map

| File | Audience | Answers |
|---|---|---|
| `SKILL.md` | the agent | what to do, in what order, and what "verified" means |
| `README.md` / `README_CN.md` | humans | what the skill is, how to install and self-check |
| `references/*.md` | the agent, on demand | per-platform procedure, failure paths, claim matrix |
| `docs/ROADMAP.md` | maintainers | what is missing, why, and how to close it by hand |
| `CHANGELOG.md` | everyone | what changed and which CI run proved it |
| `RELEASE_HIGHLIGHTS*.md` | release bodies | what this version is worth reading for |

## 中文摘要

暂不自动化、只能手工验证的四件事：Windows/WSL（缺机器，且 `stat`/`find` 语义不确定）、
macOS 上真实 BasicTeX 的 CI（cask 要 sudo、耗时长、易假红灯，改为按季度在本机跑 `tests/run-all.sh`
并把环境记进矩阵）、Debian 桌面字体隔离的端到端验证（CI 没有桌面，只能证明写入了规则和 `fc-match`
没变，超出这个范围的说法都是不诚实的）、TeX Live 2020 下限确认（需要 Docker 或虚拟机）。
LuaLaTeX 与 Intel Mac 分别记为"暂不做"和"缺硬件"。
每条都给了可直接执行的步骤；做完就把结论搬进 `references/verified-matrix.md` 并从这里删掉。

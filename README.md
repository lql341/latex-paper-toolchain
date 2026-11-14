# latex-paper-toolchain — an Agent Skill for bilingual LaTeX paper toolchains

An [Agent Skill](https://agentskills.io/specification) that installs the **minimum** XeLaTeX/CTeX
toolchain for Chinese + English papers and then **proves it works**, instead of trusting a first
compile.

It exists because the default answers are wrong in ways that cost hours: full MacTeX when BasicTeX
suffices, `fontset=mac` when the native font can't be opened, fonts copied into `~/Library/Fonts`
when nothing should be copied, `apt install texlive-lang-chinese` on a desktop when that silently
changes how every Electron app renders Chinese.

```bash
scripts/doctor.sh                                # binaries, packages, CJK font probe
scripts/cold-build.sh --expect-font STSongti     # clean build, log assertions, embedded fonts
scripts/font-audit.sh save before                # font stack manifest (run before installing)
```

## What "verified" means here

| Check | Why a first compile is not enough |
|---|---|
| Cold state (`latexmk -C`, `.bbl` removed) | stale `.aux`/`.bbl` hide broken references and citations |
| Log assertions (`Missing character`, undefined refs, `! `) | exit code 0 happily hides missing glyphs |
| Embedded font names | "PDF generated" says nothing about which font the CJK glyphs came from |
| Font-directory manifest hash | a TeX install can register fonts with the desktop without asking |

`scripts/cold-build.sh` prints exactly this:

```text
== embedded fonts
   LMRoman10-Regular
   STSongti-SC-Bold
   STSongti-SC-Regular
VERDICT: cold build verified (2 page(s), references resolved, fonts listed above).
```

## Two platform paths

| | macOS | Debian / Ubuntu desktop |
|---|---|---|
| Install | `brew install --cask basictex` (~533 MB), then `tlmgr` (see the reference) | `scripts/install-debian.sh` prints the plan; `--apply` runs it |
| Hazard | none to fonts, but `fontset=mac` probes STFangsong and tries `mktextfm` | `texlive-lang-chinese` pulls in Arphic fonts and triggers a Fontconfig rebuild |
| Fix | `fontset=none` + explicit Songti SC / Heiti SC | user-level `rejectfont` rule **before** installing |
| CJK source | native macOS fonts | TeX Live Fandol (inside TEXMF, invisible to the desktop) |

Both paths end in the same verification loop. The Debian installer is dry-run by default and orders
the steps so the font rule exists before apt rebuilds the cache; `--skip-isolate` is for servers
where no desktop is involved.

## Layout

```text
SKILL.md                        agent-facing: decisions, entry points, hard rules
agents/openai.yaml              interface metadata for harnesses that read it
scripts/install.sh              install into ~/.agents/skills (+ --claude / --codex / --link)
scripts/install-debian.sh       Debian/Ubuntu plan and executor
scripts/fontconfig-isolate.sh   --check / --write / --remove the rejectfont rule
scripts/doctor.sh               read-only health check + CJK probe compile
scripts/cold-build.sh           clean build, log assertions, embedded font list
scripts/font-audit.sh           font-directory manifest (save / diff / list / show)
scripts/_common.sh              shared POSIX sh helpers (sourced)
assets/macos/                   macos-native-fonts.tex — drop-in \input for ctex documents
assets/example/                 main.tex + refs.bib — bilingual smoke test used by the tests
references/                     macos-native-fonts.md · debian-fontconfig.md · troubleshooting.md · verified-matrix.md
tests/run-all.sh                runs the three layers below
tests/test-static.sh            syntax, frontmatter, docs, privacy, hygiene, --help
tests/test-debian-tools.sh      fontconfig cycle (hermetic) + installer plan
tests/test-tex.sh               doctor, cold build, font invariants, negative cases
```

## Install

```bash
git clone https://github.com/lql341/latex-paper-toolchain
cd latex-paper-toolchain
./scripts/install.sh                 # copies into ~/.agents/skills/<name>
./scripts/install.sh --claude --codex --link   # also link Claude Code / Codex; live edits
```

`~/.agents/skills/` is the shared Agent Skills location used by pi and Claude Code. Codex scans it
on some machines only, hence `--codex`. An existing installation is moved to `<path>.bak.<date>`
instead of being overwritten.

Then, on Debian/Ubuntu:

```bash
sudo scripts/install-debian.sh --apply     # prints nothing until --apply; see --help
scripts/doctor.sh && scripts/cold-build.sh --expect-font Fandol
```

## Self-check

```bash
bash tests/run-all.sh                 # all three layers
bash tests/run-all.sh --static-only   # no TeX, no apt (safe anywhere)
```

Negative cases are part of the suite: a document with a dangling `\ref` must fail the build check,
and `--expect-font` must fail when the named font is not embedded. A verification script that cannot
fail is not a verification script.

## Honest scope

Verified on macOS 26.6.2 (Apple Silicon) with BasicTeX/TeX Live 2026, and on Debian 13 with
`texlive-xetex`. **Not** verified: Intel Macs, older macOS, LuaLaTeX, TeX Live 2027, Windows,
byte-identical layout across platforms. Every claim carries its environment in
[`references/verified-matrix.md`](references/verified-matrix.md).

MIT licensed.

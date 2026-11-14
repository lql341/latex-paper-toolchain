# latex-paper-toolchain — 中英文论文排版工具链（Agent Skill）

[![Validate skill](https://github.com/lql341/latex-paper-toolchain/actions/workflows/validate.yml/badge.svg)](https://github.com/lql341/latex-paper-toolchain/actions/workflows/validate.yml)

一个 [Agent Skill](https://agentskills.io/specification)：装**最小可用**的 XeLaTeX/CTeX 工具链，
然后**证明它真的能用**，而不是编译一次就算成功。

它存在的理由，是那些默认答案都错得很贵：能用 BasicTeX 时却装了整个 MacTeX；
`fontset=mac` 探不到原生字体；为了让 XeTeX 找到字体就往 `~/Library/Fonts` 里拷；
在桌面机上 `apt install texlive-lang-chinese`，结果所有 Electron 应用的中文渲染都变了。

```bash
scripts/doctor.sh                                # 二进制、宏包、CJK 字体探针
scripts/cold-build.sh --expect-font STSongti     # 冷启动构建 + 日志断言 + 嵌入字体
scripts/font-audit.sh save before                # 字体目录清单（装之前先存）
```

## 什么才算“验证过”

| 检查 | 为什么第一次编译成功不算 |
|---|---|
| 冷启动（`latexmk -C`、删 `.bbl`） | 残留的 `.aux`/`.bbl` 会掩盖断掉的引用和文献 |
| 日志断言（`Missing character`、未定义引用、`! `） | 退出码 0 完全可能藏着缺字 |
| PDF 里实际嵌入的字体名 | “生成了 PDF” 说明不了中文来自哪个字体 |
| 字体目录清单哈希 | TeX 安装可能在你不知情时把字体注册进桌面 |

`scripts/cold-build.sh` 的真实输出：

```text
== embedded fonts
   LMRoman10-Regular
   STSongti-SC-Bold
   STSongti-SC-Regular
VERDICT: cold build verified (2 page(s), references resolved, fonts listed above).
```

## 两条平台路径

| | macOS | Debian / Ubuntu 桌面 |
|---|---|---|
| 安装 | `brew install --cask basictex`（约 533 MB），再用 `tlmgr` 补包（见 reference） | `scripts/install-debian.sh` 先打印计划，`--apply` 才执行 |
| 风险点 | 字体本身不动，但 `fontset=mac` 会探测 STFangsong 并触发 `mktextfm` | `texlive-lang-chinese` 依赖文鼎字体，触发 Fontconfig 重建 |
| 对策 | `fontset=none` + 显式 Songti SC / Heiti SC | 安装**之前**先写用户级 `rejectfont` 规则 |
| 中文来源 | macOS 原生字体 | TeX Live 自带 Fandol（在 TEXMF 内，桌面看不见） |

两条路径最后收敛到同一套验证循环。Debian 安装脚本默认只打印计划，并且把顺序排成"先写字体隔离规则、
再让 apt 重建缓存"；纯服务器（没有桌面）用 `--skip-isolate`。

## 目录

```text
SKILL.md                        agent 看的：决策、入口、硬规则
agents/openai.yaml              部分 harness 读取的界面元数据
scripts/install.sh              装进 ~/.agents/skills（可 --claude / --codex / --link）
scripts/install-debian.sh       Debian/Ubuntu：默认出计划，--apply 才执行
scripts/fontconfig-isolate.sh   rejectfont 规则的 --check / --write / --remove
scripts/doctor.sh               只读体检 + CJK 探针编译
scripts/cold-build.sh           冷启动构建、日志断言、嵌入字体清单
scripts/font-audit.sh           字体目录清单（save / diff / list / show）
scripts/_common.sh              公共 POSIX sh 函数（被 source）
docs/ROADMAP.md                 给维护者：哪些不自动化、为什么、手工怎么补
assets/macos/                   macos-native-fonts.tex —— ctex 文档可直接 \input
assets/example/                 main.tex + refs.bib —— 冒烟样稿，测试直接用它
references/                     macos-native-fonts.md · debian-fontconfig.md · troubleshooting.md · verified-matrix.md
tests/run-all.sh                依次跑下面三层
tests/test-static.sh            语法、frontmatter、文档、隐私、卫生、--help
tests/test-debian-tools.sh      字体隔离全流程（隔离式）+ 安装器计划
tests/test-tex.sh               doctor、冷构建、字体不变式、反例
```

## 安装

```bash
git clone https://github.com/lql341/latex-paper-toolchain
cd latex-paper-toolchain
./scripts/install.sh                            # 复制到 ~/.agents/skills/<name>
./scripts/install.sh --claude --codex --link    # 另链 Claude Code / Codex，改仓库即生效
./scripts/install.sh --minimal                  # 不拷贝 tests/ 与 .github/
```

`~/.agents/skills/` 是 pi 与 Claude Code 共用的目录；Codex 是否扫描因机器而异，所以有 `--codex`。
已存在的同名安装会先被移到 `<路径>.bak.<时间戳>`，不会静默覆盖。

Debian/Ubuntu 侧：

```bash
sudo scripts/install-debian.sh --apply     # 不加 --apply 只打印计划
scripts/doctor.sh && scripts/cold-build.sh --expect-font Fandol
```

## 自检

```bash
bash tests/run-all.sh                 # 三层全跑
bash tests/run-all.sh --static-only   # 不要 TeX、不要 apt
```

反例也在测试里：故意留一个悬空 `\ref` 必须让构建检查失败，`--expect-font` 在字体没嵌入时必须失败。
不会失败的验证脚本不算验证。

## 路线图

[`docs/ROADMAP.md`](docs/ROADMAP.md) 列出"刻意不自动化"的几件事——Windows/WSL、CI 里真跑 BasicTeX、
桌面字体端到端验证、TeX Live 2020 下限——每条都写了原因和可以照着做的手工步骤。
凡是没进 `references/verified-matrix.md` 的结论，要么在那里，要么就不该对外声称。

## 适用范围（别当成通用结论）

已验证：macOS 26.6.2（Apple Silicon）+ BasicTeX/TeX Live 2026；Ubuntu 26.04（CI，apt TeX Live）。
自带样例需要 **TeX Live ≥ 2021**（`\qty` 是 siunitx v3，`compat=1.18` 需要 pgfplots 1.18），
`doctor.sh` 会直接报这条下限，而不是等到编译时报一句莫名其妙的 `Undefined control sequence`。
**未验证**：Intel Mac、更早的 macOS、LuaLaTeX、TeX Live 2027、Windows、跨平台逐字节一致排版。
每条结论都标注了环境，见 [`references/verified-matrix.md`](references/verified-matrix.md)。

MIT 许可。

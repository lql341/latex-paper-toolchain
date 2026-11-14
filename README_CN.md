# latex-paper-toolchain — 中英文论文排版工具链（Agent Skill）

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
| 安装 | `brew install --cask basictex`（约 533 MB） | `apt-get install --no-install-recommends texlive-xetex texlive-lang-chinese …` |
| 风险点 | 字体本身不动，但 `fontset=mac` 会探测 STFangsong 并触发 `mktextfm` | `texlive-lang-chinese` 依赖文鼎字体，触发 Fontconfig 重建 |
| 对策 | `fontset=none` + 显式 Songti SC / Heiti SC | 安装**之前**先写用户级 `rejectfont` 规则 |
| 中文来源 | macOS 原生字体 | TeX Live 自带 Fandol（在 TEXMF 内，桌面看不见） |

两条路径最后收敛到同一套验证循环；脚本本身任何一步都不需要 root。

## 目录

```text
SKILL.md              agent 看的：决策、入口、硬规则
scripts/              doctor.sh · cold-build.sh · font-audit.sh（POSIX sh，无 Python）
assets/macos/         macos-native-fonts.tex —— ctex 文档可直接 \input
assets/example/       main.tex + refs.bib —— 冒烟测试样稿，测试用例直接用它
references/           macos-native-fonts.md · debian-fontconfig.md · troubleshooting.md · verified-matrix.md
tests/run-all.sh      静态检查 + 真实 TeX 构建（没有 xelatex 时自动跳过）
```

## 安装

```bash
git clone https://github.com/lql341/latex-paper-toolchain ~/.agents/skills/latex-paper-toolchain
```

`~/.agents/skills/` 是 pi 与 Claude Code 共用的 Agent Skills 目录。Codex 是否扫描它因机器而异，
不扫描的话把目录再链进 `~/.codex/skills/`。

## 自检

```bash
bash tests/run-all.sh                # 静态 + TeX 两层
bash tests/run-all.sh --static-only  # 不需要 TeX，CI 默认
```

## 适用范围（别当成通用结论）

已验证：macOS 26.6.2（Apple Silicon）+ BasicTeX/TeX Live 2026；Debian 13 + `texlive-xetex`。
**未验证**：Intel Mac、更早的 macOS、LuaLaTeX、TeX Live 2027、Windows、跨平台逐字节一致排版。
每条结论都标注了环境，见 [`references/verified-matrix.md`](references/verified-matrix.md)。

MIT 许可。

# 发布要点 — latex-paper-toolchain

- Debian/Ubuntu 从"文档"变成"可执行"：`scripts/install-debian.sh` 默认只打印计划，`--apply`
  才按安全顺序执行（先做 Fontconfig 隔离，再 apt，最后给出装前/装后的字体清单对比）。
- `scripts/fontconfig-isolate.sh` 负责写入、检查、移除那条用户级 `rejectfont` 规则——把
  `texlive-lang-chinese` 依赖进来的文鼎字体挡在桌面字体回退链之外。
- `scripts/install.sh` 把技能装到 `~/.agents/skills`（可另链 Claude Code、Codex），默认复制，
  覆盖前一律备份。
- 公共函数收进 `scripts/_common.sh`；所有脚本仍是 POSIX sh，`shellcheck -s sh` 全绿。
- 测试按层拆开（`test-static.sh`、`test-debian-tools.sh`、`test-tex.sh`），并补了反例：
  故意留一个悬空 `\ref` 必须失败，`--expect-font` 在字体不存在时必须失败。
- CI 与仓库契约一致：校验、用本技能自己的 Debian 安装脚本装出真 TeX 再构建、隔离规则全流程、
  以及从这两个要点文件自动发 Release。

# 发布要点 — latex-paper-toolchain

- `doctor.sh` 改为**先报版本下限**，而不是等你编译时炸：它从已安装的宏包识别 siunitx v3（`\qty`）
  与 pgfplots 1.18（`compat=1.18`）。自带样例需要 TeX Live ≥ 2021；在 Debian 11 / Ubuntu 20.04 上，
  旧行为是 `Undefined control sequence \qty`，报错指向文档而不是指向过老的 TeX 安装。
- 这条下限写进了技能本体、两份 README、troubleshooting（含 siunitx v2 替代写法和上游 `install-tl`
  路线）以及验证矩阵——并且如实标注"没有 TeX Live 2020 的机器可以实测"。
- CI 增加 macOS 作业，跑静态层与 Debian 工具层，专抓 `stat`、`sed -i`、`mktemp` 的 BSD/GNU 差异；
  BasicTeX 仍然只在真机上验证。
- `install.sh --minimal` 不拷贝 `tests/` 与 `.github/`；`_common.sh` 改为不可执行（它是被 source 的
  库），静态测试对这两种情况都有断言。

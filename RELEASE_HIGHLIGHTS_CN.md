# 发布要点 — latex-paper-toolchain

- `font-audit.sh` 现在正反两个方向都被测到。此前测试只断言"没变化"，那是一个**不可能失败**的断言；
  通过 `FONT_AUDIT_DIRS` 这个测试接缝，测试现在能证明：文件被修改、新增、删除都会报 `CHANGED`，
  且新增的文件名会出现在 diff 里。
- `cold-build.sh --png` 进入 TeX 层测试：渲染行缺失、渲染器报错、或没有产出图片，都会失败。
- `docs/ROADMAP.md` 增加 R7：必需状态检查是仓库设置而不是文件，并写下了启用它的 `gh api` 命令。

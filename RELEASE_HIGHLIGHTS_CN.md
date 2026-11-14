# 发布要点 — latex-paper-toolchain

- 技能名是身份，不是目录名。`release_docs.py` 与 `test-static.sh` 现在拿 `SKILL.md` 里的 `name`
  和 `latex-paper-toolchain` 比较，而不是和检出目录比较；fork、CI 工作区或
  `git clone <url> my-copy` 不会因为目录名不同而校验失败。
- `install.sh` 从 frontmatter 读取技能名，所以换个名字的检出目录依然装成 `latex-paper-toolchain`，
  而不是装成本地目录名。
- `--dest DIR` 现在是"skills 根目录"：技能落在 `DIR/<技能名>`，安装路径不再取决于脚本怎么被调用。
- 这两条行为都纳入了静态测试层。

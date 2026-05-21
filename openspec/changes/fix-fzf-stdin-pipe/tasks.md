## 1. Fix

- [x] 1.1 在 `main_interface()` 的 fzf 命令前添加 `printf '%s\n' "$fzf_input" |`（cc-cleaner.sh:99）

## 2. Verify

- [x] 2.1 运行 `./cc-cleaner.sh`，确认左侧列表显示 18 个 Claude Code 项目
- [x] 2.2 确认预览面板显示选中项目的资源详情

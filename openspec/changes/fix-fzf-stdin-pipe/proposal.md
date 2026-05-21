## Why

`cc-cleaner.sh` 的 `main_interface()` 函数生成了 fzf 输入数据，但从未通过管道传递给 fzf 命令。fzf 没有 stdin 数据时回退到默认行为——列出当前工作目录的文件。用户看到的不是 18 个 Claude Code 项目，而是项目目录中的 25 个文件。

## What Changes

- 在 `main_interface()` 的 fzf 命令前添加 `printf '%s\n' "$fzf_input" |`，将项目数据正确传递给 fzf

## Capabilities

### New Capabilities
<!-- No new capabilities — bug fix only -->

### Modified Capabilities
- `project-browsing`: 主界面 fzf 现在接收并显示扫描到的项目列表，而非当前目录文件

## Impact

- `cc-cleaner.sh` 一处改动（第 99 行）
- 修复后左侧列表显示 `~/.claude/projects/` 中的 18 个项目（格式: `项目名 (/完整路径)`）
- 根因通过 `/systematic-debugging` 定位

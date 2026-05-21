## Context

`main_interface()` 调用 `generate_fzf_input()` 生成项目列表数据存入 `$fzf_input` 变量，但后续的 fzf 命令没有接收任何 stdin。fzf 在无 stdin 时使用默认数据源（`FZF_DEFAULT_COMMAND` 或当前目录文件列表），导致显示当前项目的源码文件而非 Claude Code 项目。

## Goals / Non-Goals

**Goals:**
- 将 `$fzf_input` 正确传递给 fzf 的 stdin

**Non-Goals:**
- 不改变数据生成逻辑
- 不改变 fzf 显示格式

## Decisions

**方案: `printf '%s\n' "$fzf_input" | fzf`**

选择 `printf` 而非 `echo` 以确保 TAB 分隔符在管道透传中不被转义或截断。`printf '%s\n'` 逐字输出，不解释转义序列。

## Risks / Trade-offs

- 无风险 — 一行改动，仅修复数据传递

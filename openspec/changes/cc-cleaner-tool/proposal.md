# Proposal: cc-cleaner — Claude Code 项目资源管理工具

## 问题

使用 Claude Code 一段时间后，`~/.claude/` 下积累了多个项目的会话、文件编辑历史、环境快照等数据。目前没有工具可以：
- 一览所有经过 Claude Code 处理的项目
- 查看某个项目关联了哪些资源
- 批量清理某个项目的 Claude Code 残留数据

## 目标

一个终端交互工具，用于**查看**和**清理** Claude Code 项目资源。

## 功能

1. **项目总览** — 列出 `~/.claude/projects/` 中所有项目，显示会话数、资源大小、项目是否仍存在于磁盘
2. **多选删除** — Tab 多选项目，一键删除项目的全部 Claude Code 资源（projects 目录、file-history、session-env、tasks 等）
3. **可选删除项目本身** — 删除 Claude 资源时，可额外勾选是否 `rm -rf` 原始项目目录
4. **路径白名单** — 受保护路径永不删除，支持查看/新增/删除白名单规则，5 层安全防护
5. **Plans 清理** — 列出所有 plan 文件，多选删除
6. **帮助界面** — `?` 键显示快捷键，零记忆成本

## 非目标

- 不清理全局 `history.jsonl`（行级过滤成本高、错误率高）
- 不清理 `shell-snapshots`（与 session 的直接关联不可靠）
- 不处理 IDE 相关的缓存（`ide/` 目录，格式未知）

## 技术方案

Bash 脚本 + fzf 交互 + Python3 辅助（路径解码、JSON 解析、资源扫描）。核心交互通过 fzf 的 `--preview`、`--multi`、`--bind` 实现。

## 交互流程

```
项目列表(fzf+preview) → Tab多选 → Enter确认
                                    ↓
                            操作选择(3个选项)
                            ├─ 查看详情
                            ├─ 删除Claude资源 → 确认 → 完成
                            └─ 删除资源+项目目录 → 双重确认 → 完成
```

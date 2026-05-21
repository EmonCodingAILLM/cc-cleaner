# cc-cleaner

Claude Code 项目资源管理工具 — 查看和清理 Claude Code 产生的项目数据。

## 安装

```bash
git clone https://github.com/EmonCodingAILLM/cc-cleaner.git ~/cc-cleaner
cd ~/cc-cleaner
chmod +x cc-cleaner.sh lib/whitelist.sh
```

依赖：`fzf`、`python3`

```bash
brew install fzf
```

## 使用

```bash
./cc-cleaner.sh
```

### 快捷键

| 键 | 功能 |
|----|------|
| `↑↓` | 移动光标 |
| `Tab` | 多选项目 |
| `Enter` | 打开操作菜单 |
| `?` | 显示帮助 |
| `Esc` | 退出 |

### 操作菜单

- **查看 Session 详情** — 列出项目的全部会话及其资源占用
- **管理 Plans** — 查看和删除 Claude Code 计划文档
- **管理白名单** — 增删受保护的路径规则
- **删除 Claude 资源** — 清理 `~/.claude/` 下的会话数据和文件历史
- **删除 Claude 资源 + 项目目录** — 额外删除原始项目目录

## 白名单

首次运行自动在 `~/.config/cc-cleaner/whitelist.conf` 生成默认白名单。
白名单中的路径及其子目录**永不删除**。

默认保护：`/`、`/Users`、`/etc`、`/usr`、`/bin`、`/opt`、`/var`、`/tmp`、`/System`、
`/Applications`、`/Library`、`/private`、`~/.ssh`、`~/.gnupg`、`~/.config`

## 安全机制

5 层防护：

1. **白名单硬阻断** — 白名单路径绝不删除
2. **菜单隐藏** — 白名单项目不显示"删除项目目录"选项
3. **路径清单** — 删除前展示全部待删路径
4. **y/N 确认** — 通用确认
5. **输入 DELETE** — 删除项目目录须输入确认词

## 文件结构

```
cc-cleaner.sh          # 入口脚本（fzf 交互 + 流程编排）
lib/
├── scanner.py         # 资源扫描，输出 JSON 数据和预览缓存
├── decoder.py         # Claude Code 路径编码反向解析
└── whitelist.sh       # 白名单管理（增删查）
```

## 工作原理

Claude Code 将项目数据存储在 `~/.claude/` 下：

```
~/.claude/
├── projects/<encoded-path>/<session-id>.jsonl   # 会话数据
├── file-history/<session-id>/                    # 文件编辑快照
├── session-env/<session-id>/                     # 会话环境变量
├── tasks/<session-id>/                           # 任务数据
└── plans/*.md                                    # 计划文档
```

`cc-cleaner` 扫描这些目录，按项目归类，提供统一的清理界面。

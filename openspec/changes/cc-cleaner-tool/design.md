# Design: cc-cleaner

## 架构

```
~/.config/cc-cleaner/
└── whitelist.conf          ← 路径白名单（首次运行自动生成）

cc-cleaner
├── cc-cleaner.sh           ← 唯一入口：fzf 交互 + 流程编排
└── lib/
    ├── scanner.py          ← 扫描 ~/.claude/ 构建资源映射，输出 JSON
    ├── decoder.py          ← encoded-name → 原始路径（消歧算法）
    ├── cleaner.sh          ← 删除执行
    └── whitelist.sh        ← 白名单增删查
```

## 数据传递

scanner.py 一次性输出两份数据，落盘到 `/tmp`：

```
scanner.py
  ├── /tmp/cc-cleaner-data.json     ← 完整 JSON，供所有脚本读取
  └── /tmp/cc-cleaner-previews/     ← 每个项目的预览文本，供 fzf --preview="cat ..."
      ├── <project-id>.txt
      └── ...
```

fzf 的 `--preview` 只做 `cat`，零延迟。

## 交互流程

```
┌─────────────────────────────────────────────────┐
│              主界面 (fzf)                        │
│  ↑↓ 移动  Tab 多选  Enter 菜单  ? 帮助  Esc 退出  │
│                                                 │
│  ┌─ 项目列表 ───────────┬─ Preview ───────────┐  │
│  │ AIAgent/cc-cleaner   │ 项目: ...           │  │
│  │ AIAgent/temp         │ 会话: 25  5.0MB     │  │
│  │ cogniverse           │ 文件历史: 15.2MB    │  │
│  │ ...                  │ ...                 │  │
│  └──────────────────────┴─────────────────────┘  │
└─────────────────────────────────────────────────┘
                    │ Enter (选中项目后)
                    ▼
┌─────────────────────────────────────────────────┐
│              操作菜单 (fzf)                      │
│                                                 │
│  > 查看 Session 详情                            │
│    管理 Plans                                   │
│    管理白名单                                    │
│    删除 Claude 资源                              │
│    删除 Claude 资源 + 项目目录                    │
│                                                 │
│  ↑↓ 移动  Enter 确认  Esc 返回                   │
└─────────────────────────────────────────────────┘
                    │
          ┌────────┼────────┬──────────┐
          ▼        ▼        ▼          ▼
       Session  Plans   白名单      删除确认
       详情     管理     管理       (见下方)
```

## 快捷键

遵循两个原则：**单键优先、尊重通用约定**。

**主界面**

| 键 | 功能 | 说明 |
|----|------|------|
| `↑↓` | 移动光标 | 通用 |
| `Tab` | 多选 | fzf 原生 |
| `Enter` | 打开操作菜单 | 通用确认 |
| `?` | 显示帮助 | vim/less/tmux 惯例 |
| `Esc` | 退出 | 通用 |

**操作菜单**

| 键 | 功能 |
|----|------|
| `↑↓` | 移动光标 |
| `Enter` | 确认选项 |
| `Esc` | 返回主界面 |

**帮助界面**

| 键 | 功能 |
|----|------|
| `q` / `Esc` | 关闭帮助 |

**不使用 Ctrl 修饰键的原因**：避免和终端 Ctrl-C（中断）、Ctrl-W（readline 删词）、Ctrl-D（EOF）等系统级快捷键冲突。操作全部收敛到 Enter 菜单和 `?` 帮助，保证可发现性。

## 路径解码

Claude Code 用 `-` 替换 `/` 编码路径，对含 `-` 的目录名不可逆：

```
/Users/wenqiu/AIAgent/cc-cleaner → -Users-wenqiu-AIAgent-cc-cleaner
解码为: /Users/wenqiu/AIAgent/cc/cleaner  (错误)
```

**消歧算法**：
1. 按 `-` 分段：`["", "Users", "wenqiu", "AIAgent", "cc", "cleaner"]`
2. 从根逐段拼接：`/Users` → `/Users/wenqiu` → ...
3. `os.path.exists()` 返回 False → 将当前段与下一段用 `-` 合并：`cc-cleaner`
4. 最终无法匹配 → 标记 `exists: false`

## 路径白名单

### 存储

`~/.config/cc-cleaner/whitelist.conf`，每行一条路径。支持 `#` 注释、空行、`~` 展开。精确匹配 + 前缀匹配（`/foo/bar` 匹配 `/foo/bar/` 下所有内容）。

### 默认白名单（首次运行自动生成）

```
/
/Users
/etc /usr /bin /sbin /opt /var /tmp
/System /Applications /Library /private
~/.ssh ~/.gnupg ~/.config
```

### 检查逻辑

```python
def is_whitelisted(target_path, whitelist):
    resolved = os.path.realpath(target_path)
    for pattern in whitelist:
        pattern = os.path.expanduser(pattern)
        if resolved == pattern or resolved.startswith(pattern + '/'):
            return True
    return False
```

### 安全分层（5 层）

```
第 0 层: 白名单硬阻断      ← 不可跳过，白名单路径绝不删
第 1 层: 操作菜单          ← 白名单路径隐藏"删除项目目录"选项
第 2 层: 待删路径清单      ← 操作前展示全部将被删除的路径
第 3 层: y/N 确认          ← 通用确认
第 4 层: 输入项目名确认    ← 仅"删除项目目录"场景
```

## 删除确认

### 删除 Claude 资源

```
以下项目的 Claude Code 资源将被删除:
  /Users/wenqiu/WebstormProjects/cogniverse
    ~/.claude/projects/-Users-...-cogniverse/
    ~/.claude/file-history/93b0216a-.../    (15 个目录)
    ~/.claude/session-env/93b0216a-.../      (3 个目录)
    ~/.claude/tasks/93b0216a-.../             (5 个目录)
    共 42 个路径

确认删除? (y/N):
```

### 删除项目目录（额外确认）

```
⚠  还要删除项目目录本身:
    rm -rf /Users/wenqiu/WebstormProjects/cogniverse

此操作不可逆! 输入项目名以确认: _
```

## 数据结构

```json
[
  {
    "id": "-Users-wenqiu-AIAgent-cc-cleaner",
    "path": "/Users/wenqiu/AIAgent/cc-cleaner",
    "exists": true,
    "whitelisted": false,
    "sessions": [
      {
        "id": "b03d7609-...",
        "size_mb": 0.3,
        "mtime": "2026-05-21 11:39",
        "has_file_history": true,
        "file_history_mb": 1.2,
        "has_session_env": true,
        "has_tasks": false
      }
    ],
    "total_size_mb": 1.5
  }
]
```

## Plans 管理

Plans 不与项目关联（文件名无法追溯到项目），作为独立功能从操作菜单进入。

列出 `~/.claude/plans/*.md`，`--preview` 显示内容，Tab 多选删除。

## 错误处理

- 删除失败不中断，逐条执行，最后汇总成功/失败结果
- scanner.py 对已删除的项目正常统计其残留资源
- 删除前所有路径做安全检查（非 `/`、非 `$HOME`、非空）

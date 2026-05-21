# Tasks: cc-cleaner

## Phase 1: 扫描层

- [x] 1.1 **路径解码** (`lib/decoder.py`) — 消歧算法，filesystem-backed resolution
- [x] 1.2 **资源扫描** (`lib/scanner.py`) — JSON data + preview cache 输出
- [x] 1.3 **白名单检查** (scanner.py 内 + `lib/whitelist.sh`) — 精确+前缀匹配，增删查

## Phase 2: 交互层

- [x] 2.1 **主界面** — fzf 列表 + `--preview="cat"` 零延迟 + `--bind="?:execute"` 帮助
- [x] 2.2 **操作菜单** — 第二个 fzf，5 选项（白名单路径隐藏"删除目录"）
- [x] 2.3 **Session 详情** — Python 渲染 session ID、时间、大小、关联资源
- [x] 2.4 **Plans 管理** — fzf 列出 + preview 内容 + Tab 多选删除
- [x] 2.5 **白名单管理** — 菜单式交互：查看、新增(校验)、删除(多选)
- [x] 2.6 **帮助界面** — `?` 键显示快捷键列表，q/Esc 关闭

## Phase 3: 删除层

- [x] 3.1 **删除执行** — Python `shutil.rmtree` 逐项清理 projects/ file-history/ session-env/ tasks/
- [x] 3.2 **确认流程** — 路径清单展示 → y/N → 输入 DELETE → 最终白名单硬检查

## Phase 4: 入口

- [x] 4.1 **主入口** (`cc-cleaner.sh`) — 依赖检查、白名单初始化、scanner 调用、主循环

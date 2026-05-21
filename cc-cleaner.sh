#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_FILE="/tmp/cc-cleaner-data.json"
PREVIEW_DIR="/tmp/cc-cleaner-previews"
IDS_FILE="/tmp/cc-cleaner-selected-ids.txt"

# ── Help ──────────────────────────────────────────────────────────

show_help() {
    cat << 'EOF'

  ═══════════════════════════════════════════════════════════════
  cc-cleaner — Claude Code 项目资源管理工具
  ═══════════════════════════════════════════════════════════════

  快捷键

  主界面
  ─────────────────────────────────────────────────────────────
  ↑↓           移动光标
  Tab          多选项目
  Shift+Tab    取消多选
  Enter        打开操作菜单
  ?            显示此帮助
  Esc          退出

  操作菜单
  ─────────────────────────────────────────────────────────────
  ↑↓           移动光标
  Enter        确认操作
  Esc          返回主界面

  删除确认
  ─────────────────────────────────────────────────────────────
  y/N          确认/取消删除
  输入 DELETE   删除项目目录前的二次确认

  白名单管理
  ─────────────────────────────────────────────────────────────
  a            新增规则
  d            删除规则 (进入 fzf 多选)
  q            返回

  Plans 管理
  ─────────────────────────────────────────────────────────────
  Tab          多选
  Enter        确认删除
  Esc          返回

  ═══════════════════════════════════════════════════════════════

EOF
    printf "  Press Enter to close help... "
    read -r _ || true
}

# ── Scanner ───────────────────────────────────────────────────────

run_scanner() {
    cd "$SCRIPT_DIR"
    python3 lib/scanner.py > /dev/null 2>&1 || {
        echo "ERROR: scanner failed. Running with output:"
        cd "$SCRIPT_DIR" && python3 lib/scanner.py
        exit 1
    }
}

# ── Main fzf list ─────────────────────────────────────────────────

generate_fzf_input() {
    python3 -c "
import json, os
with open('$DATA_FILE') as f:
    data = json.load(f)
for p in data['projects']:
    sid = p['id']
    scount = p['session_count']
    size = p['total_size_mb']
    status = '\033[32m●\033[0m' if p['exists'] else '\033[90m○\033[0m'
    wh = ' \033[31mW\033[0m' if p['whitelisted'] else ''
    basename = os.path.basename(p['path'])
    display = f'{basename} ({p[\"path\"]})'
    print(f'{display}\t{scount:3d}s\t{size:7.1f}M\t{status}{wh}\t{sid}')
" 2>/dev/null
}

main_interface() {
    local header=" Esc 退出 | Tab 多选 | Enter 操作菜单 | ? 帮助 "
    local fzf_input
    fzf_input=$(generate_fzf_input)

    if [ -z "$fzf_input" ]; then
        echo "No Claude Code projects found."
        exit 0
    fi

    printf '%s\n' "$fzf_input" | fzf \
        --multi \
        --ansi \
        --delimiter='\t' \
        --with-nth=1 \
        --nth=1 \
        --preview="cat $PREVIEW_DIR/{5}.txt 2>/dev/null || echo 'Loading...'" \
        --preview-window="right:40%:sharp" \
        --preview-label=" Project Detail " \
        --border=sharp \
        --bind="?:execute($SCRIPT_DIR/cc-cleaner.sh help)+clear-query" \
        --header="$header" \
        --header-first \
        --prompt="Projects > "
}

# ── Operation menu ────────────────────────────────────────────────

operation_menu() {
    local count="$1"
    local is_whitelisted="$2"

    local options
    if [ "$is_whitelisted" = "true" ]; then
        options=$'查看 Session 详情\n管理 Plans\n管理白名单\n━━━━━━━━━━━━━━━━━\n删除 Claude 资源'
    else
        options=$'查看 Session 详情\n管理 Plans\n管理白名单\n━━━━━━━━━━━━━━━━━\n删除 Claude 资源\n删除 Claude 资源 + 项目目录'
    fi

    echo "$options" | fzf \
        --header="已选 $count 个项目 | ↑↓:移动 | Enter:确认 | Esc:返回" \
        --prompt="Action > " \
        --height=14
}

# ── Session details ───────────────────────────────────────────────

show_session_details() {
    python3 -c "
import json
with open('$DATA_FILE') as f:
    data = json.load(f)
with open('$IDS_FILE') as f:
    ids = set(line.strip() for line in f if line.strip())

for p in data['projects']:
    if p['id'] not in ids:
        continue
    print()
    print(f'  项目: {p[\"path\"]}')
    print(f'  状态: {\"存在\" if p[\"exists\"] else \"已删除\"}')
    print(f'  Whitelist: {\"是\" if p[\"whitelisted\"] else \"否\"}  |  {p[\"session_count\"]} sessions  |  {p[\"total_size_mb\"]} MB')
    print()
    header = f'  {\"Session ID\":<38} {\"时间\":<18} {\"大小\":>8}  {\"资源\"}'
    print(header)
    print(f'  {\"─\"*38} {\"─\"*18} {\"─\"*8}  {\"─\"*20}')
    for s in p['sessions']:
        resources = []
        if s['has_file_history']: resources.append('file-history')
        if s['has_session_env']: resources.append('session-env')
        if s['has_tasks']: resources.append('tasks')
        res_str = ', '.join(resources) if resources else '-'
        print(f'  {s[\"id\"]}  {s[\"mtime\"]}  {s[\"size_mb\"]:7.3f}MB  {res_str}')
    print()
" 2>/dev/null

    printf "  Press Enter to return... "
    read -r _ || true
}

# ── Plans management ──────────────────────────────────────────────

manage_plans() {
    local plans_list
    plans_list=$(python3 -c "
import json
with open('$DATA_FILE') as f:
    data = json.load(f)
for p in data['plans']:
    print(f'{p[\"filename\"]}\t{p[\"size_kb\"]:6.1f} KB\t{p[\"mtime\"]}')
" 2>/dev/null)

    if [ -z "$plans_list" ]; then
        echo "No plans found."
        printf "  Press Enter to return... "
        read -r _ || true
        return
    fi

    local selected
    selected=$(echo "$plans_list" | fzf \
        --multi \
        --ansi \
        --delimiter='\t' \
        --nth=1 \
        --preview="cat $HOME/.claude/plans/{1} 2>/dev/null" \
        --preview-window="right:60%:wrap" \
        --header="Tab:多选 | Enter:确认删除 | Esc:返回" \
        --prompt="Plans > ")

    if [ -z "$selected" ]; then
        return
    fi

    echo ""
    echo "  Will delete:"
    echo "$selected" | while IFS= read -r line; do
        local fname
        fname=$(echo "$line" | cut -d$'\t' -f1 | xargs)
        printf "    %s\n" "$HOME/.claude/plans/$fname"
    done
    echo ""
    printf "  Confirm deletion? (y/N): "
    read -r confirm || true

    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        local deleted=0
        while IFS= read -r line; do
            local fname fpath
            fname=$(echo "$line" | cut -d$'\t' -f1 | xargs)
            # Safety: reject names with path traversal or shell metacharacters
            if [[ "$fname" =~ [/.:*?\[\]] ]]; then
                echo "    Skipped unsafe filename: $fname"
                continue
            fi
            fpath="$HOME/.claude/plans/$fname"
            if [ ! -f "$fpath" ]; then
                echo "    Not found: $fpath"
                continue
            fi
            rm -f "$fpath" && deleted=$((deleted + 1))
        done <<< "$selected"
        echo "  Deleted $deleted plan(s)."
        run_scanner
    else
        echo "  Cancelled."
    fi
}

# ── Cleaner ───────────────────────────────────────────────────────

delete_claude_resources() {
    python3 -c "
import json, os, shutil, sys

with open('$DATA_FILE') as f:
    data = json.load(f)

with open('$IDS_FILE') as f:
    ids = set(line.strip() for line in f if line.strip())

claude_dir = data['claude_dir']
ok = 0
fail = 0

for p in data['projects']:
    if p['id'] not in ids:
        continue

    # Entire project directory in ~/.claude/projects/
    proj_dir = os.path.join(claude_dir, 'projects', p['id'])
    try:
        if os.path.exists(proj_dir):
            shutil.rmtree(proj_dir)
            print(f'    [project]  deleted: {proj_dir}')
            ok += 1
    except OSError as e:
        print(f'    [project]  failed:  {proj_dir} ({e})')
        fail += 1

    # Individual session resources
    for s in p['sessions']:
        for subdir in ['file-history', 'session-env', 'tasks']:
            spath = os.path.join(claude_dir, subdir, s['id'])
            try:
                if os.path.exists(spath):
                    shutil.rmtree(spath)
                    print(f'    [{subdir}]  deleted: {spath}')
                    ok += 1
            except OSError as e:
                print(f'    [{subdir}]  failed:  {spath} ({e})')
                fail += 1

print(f'    ───────────────────────')
print(f'    {ok} succeeded, {fail} failed')
" 2>/dev/null
}

delete_project_dirs() {
    python3 -c "
import json, os, shutil, sys

with open('$DATA_FILE') as f:
    data = json.load(f)

with open('$IDS_FILE') as f:
    ids = set(line.strip() for line in f if line.strip())

whitelist_file = os.path.expanduser('$HOME/.config/cc-cleaner/whitelist.conf')
whitelist = []
if os.path.exists(whitelist_file):
    with open(whitelist_file) as f:
        for line in f:
            line = line.split('#')[0].strip()
            if line:
                whitelist.append(os.path.expanduser(line))

for p in data['projects']:
    if p['id'] not in ids:
        continue
    if not p['exists']:
        print(f'    (skipped - already deleted: {p[\"path\"]})')
        continue

    # Final whitelist check
    resolved = os.path.realpath(p['path']) if os.path.exists(p['path']) else p['path']
    blocked = False
    for rule in whitelist:
        if resolved == rule or resolved.startswith(rule.rstrip('/') + '/'):
            print(f'    BLOCKED by whitelist ({rule}): {p[\"path\"]}')
            blocked = True
            break
    if blocked:
        continue

    try:
        shutil.rmtree(p['path'])
        print(f'    deleted: {p[\"path\"]}')
    except OSError as e:
        print(f'    failed:  {p[\"path\"]} ({e})')
" 2>/dev/null
}

collect_and_show_paths() {
    python3 -c "
import json, os

with open('$DATA_FILE') as f:
    data = json.load(f)

with open('$IDS_FILE') as f:
    ids = set(line.strip() for line in f if line.strip())

claude_dir = data['claude_dir']
path_count = 0
total_mb = 0.0

for p in data['projects']:
    if p['id'] not in ids:
        continue

    total_mb += p['total_size_mb']

    proj_dir = os.path.join(claude_dir, 'projects', p['id'])
    print(f'    [project-data]  {proj_dir}')
    path_count += 1

    for s in p['sessions']:
        for subdir in ['file-history', 'session-env', 'tasks']:
            spath = os.path.join(claude_dir, subdir, s['id'])
            if os.path.exists(spath):
                print(f'    [{subdir}]       {spath}')
                path_count += 1

    print(f'     ── 项目目录: {p[\"path\"]}  ({\"存在\" if p[\"exists\"] else \"已删除\"})')
    print()

print(f'  共 {path_count} 个路径, ~{total_mb:.2f} MB')
" 2>/dev/null
}

cleanup_confirmation() {
    local delete_dir_too="$1"

    echo ""
    echo "  ═══════════════════════════════════════════════════════"
    echo "  以下 Claude Code 资源将被删除:"
    echo "  ═══════════════════════════════════════════════════════"
    echo ""

    collect_and_show_paths

    echo ""
    printf "  确认删除? (y/N): "
    read -r confirm || true

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "  Cancelled."
        return 1
    fi

    echo ""
    echo "  Deleting..."
    echo ""
    delete_claude_resources
    echo ""

    if [ "$delete_dir_too" = "true" ]; then
        echo "  ═══════════════════════════════════════════════════════"
        echo "  ⚠  Deleting project directories..."
        echo "  ═══════════════════════════════════════════════════════"
        echo ""
        printf "  Type 'DELETE' to confirm removal of project directories: "
        read -r confirm2 || true

        if [ "$confirm2" != "DELETE" ]; then
            echo "  Cancelled."
            return 1
        fi

        echo ""
        delete_project_dirs
        echo ""
    fi

    echo "  Cleanup complete."
    return 0
}

# ── Main ───────────────────────────────────────────────────────────

main() {
    # Check dependencies
    if ! command -v fzf &> /dev/null; then
        echo "Error: fzf is required. Install with: brew install fzf"
        exit 1
    fi
    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 is required."
        exit 1
    fi

    # Initialize whitelist on first run
    if [ ! -f "$HOME/.config/cc-cleaner/whitelist.conf" ]; then
        source "$SCRIPT_DIR/lib/whitelist.sh"
        whitelist_init_default
    fi

    # Run scanner
    run_scanner

    local proj_total
    proj_total=$(python3 -c "import json; d=json.load(open('$DATA_FILE')); print(len(d['projects']))" 2>/dev/null || echo "?")
    echo "cc-cleaner: found $proj_total projects in ~/.claude/projects/"
    echo ""

    # Main loop
    while true; do
        local selected
        selected=$(main_interface) || break

        if [ -z "$selected" ]; then
            break
        fi

        # Extract project IDs (column 5) and write to temp file
        echo "$selected" | cut -d$'\t' -f5 | xargs -n1 | grep -v '^$' > "$IDS_FILE"
        local proj_count
        proj_count=$(wc -l < "$IDS_FILE" | xargs)

        if [ "$proj_count" -eq 0 ]; then
            break
        fi

        # Check if ANY selected project is whitelisted
        local is_wh
        is_wh=$(python3 -c "
import json
with open('$DATA_FILE') as f:
    data = json.load(f)
with open('$IDS_FILE') as f:
    ids = set(line.strip() for line in f if line.strip())
for p in data['projects']:
    if p['id'] in ids and p['whitelisted']:
        print('true')
        break
" 2>/dev/null)
        is_wh="${is_wh:-false}"

        # Operation menu
        local action
        action=$(operation_menu "$proj_count" "$is_wh")

        case "$action" in
            "查看 Session 详情")
                show_session_details
                printf "  Press Enter to return... "
                read -r _ || true
                ;;
            "管理 Plans")
                manage_plans
                ;;
            "管理白名单")
                source "$SCRIPT_DIR/lib/whitelist.sh"
                whitelist_manage
                run_scanner
                ;;
            "删除 Claude 资源")
                cleanup_confirmation "false"
                printf "  Press Enter to continue... "
                read -r _ || true
                run_scanner
                ;;
            "删除 Claude 资源 + 项目目录")
                cleanup_confirmation "true"
                printf "  Press Enter to continue... "
                read -r _ || true
                run_scanner
                ;;
            *)
                ;;
        esac
    done

    echo ""
    echo "  Bye."
}

# Handle special commands
case "${1:-}" in
    help)
        show_help
        ;;
    *)
        main
        ;;
esac

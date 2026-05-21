#!/bin/bash

WHITELIST_FILE="$HOME/.config/cc-cleaner/whitelist.conf"

mkdir -p "$(dirname "$WHITELIST_FILE")"

whitelist_init_default() {
    if [ -f "$WHITELIST_FILE" ]; then
        return
    fi
    cat > "$WHITELIST_FILE" << 'EOF'
# cc-cleaner path whitelist
# Paths listed below will NEVER be deleted.
# One path per line. Supports ~ expansion and prefix matching.
# Lines starting with # are ignored.
#
/etc
/usr
/bin
/sbin
/opt
/var
/tmp
/System
/System/Volumes/Data
/Applications
/Library
/private
~/.ssh
~/.gnupg
~/.config
EOF
}

whitelist_rules() {
    # Output non-comment, non-empty rules from whitelist file
    while IFS= read -r line; do
        stripped=$(echo "$line" | sed 's/[[:space:]]*#.*//' | xargs)
        [ -z "$stripped" ] && continue
        echo "$stripped"
    done < "$WHITELIST_FILE"
}

whitelist_add() {
    whitelist_init_default

    echo ""
    echo -n "  Enter path to protect: "
    read -r new_path

    if [ -z "$new_path" ]; then
        echo "  Error: path cannot be empty"
        return 1
    fi

    if [ "${new_path:0:1}" != "/" ] && [ "${new_path:0:1}" != "~" ]; then
        echo "  Error: path must start with / or ~"
        return 1
    fi

    # Check duplicates
    expanded=$(python3 -c "import os; print(os.path.expanduser('$new_path'))" 2>/dev/null)
    if grep -qFx "$expanded" "$WHITELIST_FILE" 2>/dev/null || \
       grep -qFx "$new_path" "$WHITELIST_FILE" 2>/dev/null; then
        echo "  Path already in whitelist"
        return 1
    fi

    echo "$new_path" >> "$WHITELIST_FILE"
    echo "  Added: $new_path"
    return 0
}

whitelist_delete() {
    whitelist_init_default

    local rules
    rules=$(whitelist_rules)
    if [ -z "$rules" ]; then
        echo "  Whitelist is empty."
        return
    fi

    local selected
    selected=$(echo "$rules" | fzf \
        --multi \
        --header="Tab:多选 | Enter:确认删除 | Esc:取消" \
        --prompt="Delete rules > ")

    if [ -z "$selected" ]; then
        return
    fi

    echo ""
    echo "  Will remove:"
    echo "$selected" | while read -r line; do echo "    $line"; done
    echo ""
    echo -n "  Confirm removal? (y/N): "
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "  Cancelled."
        return
    fi

    # Use Python with temp file for safe exact-line removal
    local tmp_rm
    tmp_rm=$(mktemp /tmp/cc-cleaner-wlremove.XXXXXX)
    echo "$selected" > "$tmp_rm"
    python3 -c "
with open('$tmp_rm') as rf:
    target_lines = set(line.strip() for line in rf if line.strip())
with open('$WHITELIST_FILE') as f:
    kept = [line for line in f if line.rstrip('\n') not in target_lines]
with open('$WHITELIST_FILE', 'w') as f:
    f.writelines(kept)
"
    rm -f "$tmp_rm"

    echo "  Removed."
}

whitelist_manage() {
    whitelist_init_default

    while true; do
        clear
        echo ""
        echo "  ═══════════════════════════════════════"
        echo "  路径白名单管理"
        echo "  ═══════════════════════════════════════"
        echo ""
        echo "  以下路径及其子目录受保护，永不被删除:"
        echo ""

        local count=0
        while IFS= read -r line; do
            stripped=$(echo "$line" | sed 's/[[:space:]]*#.*//' | xargs)
            [ -z "$stripped" ] && continue
            count=$((count + 1))
            printf "    %s\n" "$stripped"
        done < "$WHITELIST_FILE"

        echo ""
        echo "  ───────────────────────────────────────"
        echo "  $count 条规则  |  $WHITELIST_FILE"
        echo "  ═══════════════════════════════════════"
        echo ""
        echo "  [a] 新增规则"
        echo "  [d] 删除规则"
        echo "  [q] 返回"
        echo ""
        echo -n "  > "
        read -r choice

        case "$choice" in
            a) whitelist_add; echo ""; echo -n "  Press Enter to continue..."; read -r ;;
            d) whitelist_delete; echo ""; echo -n "  Press Enter to continue..."; read -r ;;
            q) break ;;
            *) ;;
        esac
    done
}

# When sourced, just define functions.
# When executed, show management interface.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    whitelist_manage
fi

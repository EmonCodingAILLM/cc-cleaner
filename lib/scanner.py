"""Scan ~/.claude/ and build a resource map for all Claude Code projects.

Outputs:
  /tmp/cc-cleaner-data.json       Full JSON data
  /tmp/cc-cleaner-previews/       Per-project preview text files
"""

import json
import os
import sys
from datetime import datetime

from decoder import decode

CLAUDE_DIR = os.path.expanduser('~/.claude')
PROJECTS_DIR = os.path.join(CLAUDE_DIR, 'projects')
FILE_HISTORY_DIR = os.path.join(CLAUDE_DIR, 'file-history')
SESSION_ENV_DIR = os.path.join(CLAUDE_DIR, 'session-env')
TASKS_DIR = os.path.join(CLAUDE_DIR, 'tasks')
PLANS_DIR = os.path.join(CLAUDE_DIR, 'plans')
WHITELIST_FILE = os.path.expanduser('~/.config/cc-cleaner/whitelist.conf')

TMP_DIR = '/tmp/cc-cleaner-previews'


def load_whitelist():
    """Load whitelist entries from config file."""
    rules = []
    if not os.path.exists(WHITELIST_FILE):
        return rules
    with open(WHITELIST_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            rules.append(os.path.expanduser(line))
    return rules


def is_whitelisted(path, whitelist):
    """Check if a path matches any whitelist rule."""
    resolved = os.path.realpath(path) if os.path.exists(path) else path
    for pattern in whitelist:
        if resolved == pattern or resolved.startswith(pattern.rstrip('/') + '/'):
            return True
    return False


def size_mb(path):
    """Get file or directory size in MB. Returns 0 if path doesn't exist."""
    if not os.path.exists(path):
        return 0
    if os.path.isfile(path):
        try:
            return round(os.path.getsize(path) / (1024 * 1024), 3)
        except OSError:
            return 0
    total = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            try:
                total += os.path.getsize(fp)
            except OSError:
                pass
    return round(total / (1024 * 1024), 3)


def mtime_iso(path):
    """Get mtime as ISO-like string."""
    try:
        ts = os.path.getmtime(path)
        return datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M')
    except OSError:
        return 'unknown'


def scan_projects(whitelist):
    """Scan all projects and return structured data."""
    projects = []

    if not os.path.exists(PROJECTS_DIR):
        return projects

    for name in sorted(os.listdir(PROJECTS_DIR)):
        proj_dir = os.path.join(PROJECTS_DIR, name)
        if not os.path.isdir(proj_dir):
            continue

        path, exists = decode(name)
        whitelisted = is_whitelisted(path, whitelist)

        sessions = []
        project_mb = 0

        # Collect sessions (jsonl files, not memory directory)
        for entry in os.listdir(proj_dir):
            entry_path = os.path.join(proj_dir, entry)
            if entry == 'memory':
                # Include memory dir in project size
                project_mb += size_mb(entry_path)
            elif entry.endswith('.jsonl'):
                sid = entry.replace('.jsonl', '')
                size = size_mb(entry_path)
                project_mb += size

                # Check for associated resources
                fh_path = os.path.join(FILE_HISTORY_DIR, sid)
                env_path = os.path.join(SESSION_ENV_DIR, sid)
                task_path = os.path.join(TASKS_DIR, sid)

                sessions.append({
                    'id': sid,
                    'size_mb': size,
                    'mtime': mtime_iso(entry_path),
                    'has_file_history': os.path.isdir(fh_path),
                    'file_history_mb': size_mb(fh_path),
                    'has_session_env': os.path.isdir(env_path),
                    'has_tasks': os.path.isdir(task_path),
                })

        # Compute resource totals
        file_history_mb = sum(s['file_history_mb'] for s in sessions)
        session_env_mb = sum(
            size_mb(os.path.join(SESSION_ENV_DIR, s['id']))
            for s in sessions if s['has_session_env']
        )
        tasks_mb = sum(
            size_mb(os.path.join(TASKS_DIR, s['id']))
            for s in sessions if s['has_tasks']
        )

        total_mb = round(project_mb + file_history_mb + session_env_mb + tasks_mb, 3)

        projects.append({
            'id': name,
            'path': path,
            'exists': exists,
            'whitelisted': whitelisted,
            'sessions': sessions,
            'session_count': len(sessions),
            'total_size_mb': total_mb,
            'resources': {
                'project_mb': round(project_mb, 3),
                'file_history_mb': round(file_history_mb, 3),
                'session_env_mb': round(session_env_mb, 3),
                'tasks_mb': round(tasks_mb, 3),
            }
        })

    return projects


def scan_plans():
    """Scan plans directory and return list of plan info."""
    plans = []
    if not os.path.exists(PLANS_DIR):
        return plans

    for name in sorted(os.listdir(PLANS_DIR)):
        fpath = os.path.join(PLANS_DIR, name)
        if name.endswith('.md') and os.path.isfile(fpath):
            plans.append({
                'filename': name,
                'path': fpath,
                'size_kb': round(os.path.getsize(fpath) / 1024, 1),
                'mtime': mtime_iso(fpath),
            })

    return plans


def generate_preview_text(project):
    """Generate preview text for a single project."""
    res = project['resources']

    status_char = '\033[32m●\033[0m' if project['exists'] else '\033[90m○\033[0m'
    status_text = '存在' if project['exists'] else '已删除'
    wh_text = '\033[31m[白名单]\033[0m' if project['whitelisted'] else ''

    lines = [
        f"  项目: {project['path']}",
        f"  状态: {status_char} {status_text} {wh_text}",
        "",
        f"  ── 会话 ─────────────────────────",
        f"  数量:     {project['session_count']} 个",
        f"  总大小:   {res['project_mb']} MB",
        "",
        f"  ── 文件编辑历史 ─────────────────",
        f"  占用:     {res['file_history_mb']} MB",
        "",
        f"  ── 其他资源 ─────────────────────",
        f"  会话环境: {res['session_env_mb']} MB",
        f"  任务数据: {res['tasks_mb']} MB",
        "",
        f"  ── 合计 ─────────────────────────",
        f"  总占用:   ~{project['total_size_mb']} MB",
    ]

    return '\n'.join(lines)


def main():
    whitelist = load_whitelist()
    projects = scan_projects(whitelist)
    plans = scan_plans()

    data = {
        'projects': projects,
        'plans': plans,
        'whitelist': whitelist,
        'claude_dir': CLAUDE_DIR,
    }

    # Write JSON data
    with open('/tmp/cc-cleaner-data.json', 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    # Write preview cache
    os.makedirs(TMP_DIR, exist_ok=True)
    for p in projects:
        preview_path = os.path.join(TMP_DIR, p['id'] + '.txt')
        with open(preview_path, 'w') as f:
            f.write(generate_preview_text(p))

    print(json.dumps(data, ensure_ascii=False))


if __name__ == '__main__':
    main()

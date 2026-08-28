#!/usr/bin/env python3
import sys
import json
import os
import subprocess
import time

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

ws = data.get('workspace') or {}
repo = ws.get('repo') or {}
pr = data.get('pr') or {}
vim_d = data.get('vim') or {}
agent_d = data.get('agent') or {}
ctx = data.get('context_window') or {}
model_d = data.get('model') or {}
rl = (data.get('rate_limits') or {}).get('five_hour') or {}

BOLD = '\033[1m'
DIM = '\033[2m'
CYAN = '\033[36m'
GREEN = '\033[32m'
YELLOW = '\033[33m'
MAGENTA = '\033[35m'
RED = '\033[31m'
BLUE = '\033[34m'
RESET = '\033[0m'

SEP = f'{DIM} | {RESET}'
parts = []

cwd = ws.get('current_dir', '')
if cwd:
    home = os.path.expanduser('~').replace('\\', '/')
    short = cwd.replace('\\', '/')
    if short.startswith(home):
        short = '~' + short[len(home):]
    parts.append(f'{CYAN}{BOLD}📁 {short}{RESET}')

model = model_d.get('display_name', '')
if model:
    parts.append(f'{DIM}{model}{RESET}')

used_pct = ctx.get('used_percentage')
if used_pct is not None:
    pct_int = round(float(used_pct))
    colour = RED if pct_int >= 80 else YELLOW if pct_int >= 50 else GREEN
    parts.append(f'{colour}ctx:{pct_int}%{RESET}')

# Git status (branch, uncommitted, sync)
git_part = ''
if cwd:
    try:
        def git(*args):
            r = subprocess.run(
                ['git', '-C', cwd] + list(args),
                capture_output=True, text=True, timeout=3
            )
            return r.stdout.strip() if r.returncode == 0 else None

        git_dir = git('rev-parse', '--git-dir')
        if git_dir is not None:
            branch = git('rev-parse', '--abbrev-ref', 'HEAD') or ''
            status_out = git('status', '--porcelain') or ''
            uncommitted_lines = [l for l in status_out.splitlines() if l]
            uncommitted = len(uncommitted_lines)

            sync_status = ''
            upstream = git('rev-parse', '--abbrev-ref', '@{u}')
            if upstream is not None:
                ahead_s = git('rev-list', '--count', '@{u}..HEAD')
                behind_s = git('rev-list', '--count', 'HEAD..@{u}')
                ahead = int(ahead_s) if ahead_s and ahead_s.isdigit() else 0
                behind = int(behind_s) if behind_s and behind_s.isdigit() else 0

                if ahead > 0 and behind > 0:
                    sync_status = f'↑{ahead} ↓{behind}'
                elif ahead > 0:
                    sync_status = f'↑{ahead}'
                elif behind > 0:
                    sync_status = f'↓{behind}'
                else:
                    abs_git_dir = git('rev-parse', '--absolute-git-dir')
                    if abs_git_dir:
                        fetch_head = os.path.join(abs_git_dir, 'FETCH_HEAD')
                        if os.path.exists(fetch_head):
                            fetch_ago_min = int((time.time() - os.path.getmtime(fetch_head)) / 60)
                            if fetch_ago_min < 60:
                                sync_status = f'synced {fetch_ago_min}m ago'
                            else:
                                sync_status = f'synced {fetch_ago_min // 60}h ago'
                        else:
                            sync_status = 'synced'

            if branch:
                if uncommitted > 0:
                    if uncommitted == 1:
                        single_file = uncommitted_lines[0][3:].strip()
                        git_status = f'{single_file} uncommitted'
                    else:
                        git_status = f'{uncommitted} uncommitted'
                    if sync_status:
                        git_status = f'{git_status}, {sync_status}'
                    git_part = f'{YELLOW}🔀 {branch} ({git_status}){RESET}'
                elif sync_status:
                    git_part = f'{YELLOW}🔀 {branch} ({sync_status}){RESET}'
                else:
                    git_part = f'{YELLOW}🔀 {branch}{RESET}'
    except Exception:
        pass

if git_part:
    parts.append(git_part)

owner = repo.get('owner', '')
name = repo.get('name', '')
if owner and name:
    parts.append(f'{BLUE}{owner}/{name}{RESET}')

pr_num = pr.get('number')
if pr_num:
    pr_state = pr.get('review_state', '')
    pr_colour = (GREEN if pr_state == 'approved'
                 else RED if pr_state == 'changes_requested'
                 else DIM if pr_state == 'draft'
                 else YELLOW)
    label = f'PR#{pr_num}({pr_state})' if pr_state else f'PR#{pr_num}'
    parts.append(f'{pr_colour}{label}{RESET}')

five_hr = rl.get('used_percentage')
if five_hr is not None:
    five_int = round(float(five_hr))
    rl_colour = RED if five_int >= 80 else YELLOW if five_int >= 50 else DIM
    parts.append(f'{rl_colour}5h:{five_int}%{RESET}')

vim_mode = vim_d.get('mode', '')
if vim_mode:
    vim_colour = (GREEN if vim_mode == 'INSERT'
                  else MAGENTA if vim_mode.startswith('VISUAL')
                  else YELLOW)
    parts.append(f'{vim_colour}[{vim_mode}]{RESET}')

agent_name = agent_d.get('name', '')
if agent_name:
    parts.append(f'{MAGENTA}agent:{agent_name}{RESET}')

print(SEP.join(parts))

# Last user message from transcript
transcript_path = data.get('transcript_path', '')
if transcript_path and os.path.exists(transcript_path):
    try:
        last_msg = None
        with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get('isSidechain') or entry.get('isApiErrorMessage'):
                    continue
                if entry.get('type') != 'human' and entry.get('role') != 'user':
                    continue

                msg = entry.get('message') or entry.get('text') or ''
                if isinstance(msg, dict):
                    content = msg.get('content', '')
                    if isinstance(content, str):
                        msg = content
                    elif isinstance(content, list):
                        msg = ' '.join(c.get('text', '') for c in content if c.get('type') == 'text')

                if isinstance(msg, str) and msg:
                    if not msg.startswith('[Request interrupted') and not msg.startswith('[Request cancelled'):
                        last_msg = msg

        if last_msg:
            first_line = last_msg.split('\n')[0]
            truncated = first_line[:80] + ('…' if len(first_line) > 80 or '\n' in last_msg else '')
            print(f'{DIM}💬 {truncated}{RESET}')
    except Exception:
        pass

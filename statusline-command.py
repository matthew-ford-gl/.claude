#!/usr/bin/env python3
import sys
import json
import os

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
    parts.append(f'{CYAN}{BOLD}{short}{RESET}')

model = model_d.get('display_name', '')
if model:
    parts.append(f'{DIM}{model}{RESET}')

used_pct = ctx.get('used_percentage')
if used_pct is not None:
    pct_int = round(float(used_pct))
    colour = RED if pct_int >= 80 else YELLOW if pct_int >= 50 else GREEN
    parts.append(f'{colour}ctx:{pct_int}%{RESET}')

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

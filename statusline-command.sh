#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

# Parse JSON fields using Python (jq not available)
_py() { python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
$1
" <<< "$input" 2>/dev/null; }

cwd=$(_py "
ws = d.get('workspace') or {}
print(ws.get('current_dir') or ws.get('cwd') or '', end='')
")
model=$(_py "print((d.get('model') or {}).get('display_name') or '', end='')")
used_pct=$(_py "print((d.get('context_window') or {}).get('used_percentage') or '', end='')")
repo=$(_py "
r = (d.get('workspace') or {}).get('repo') or {}
o, n = r.get('owner',''), r.get('name','')
print(f'{o}/{n}' if o and n else '', end='')
")
pr_num=$(_py "print((d.get('pr') or {}).get('number') or '', end='')")
pr_state=$(_py "print((d.get('pr') or {}).get('review_state') or '', end='')")
vim_mode=$(_py "print((d.get('vim') or {}).get('mode') or '', end='')")
agent_name=$(_py "print((d.get('agent') or {}).get('name') or '', end='')")
five_hr=$(_py "print(((d.get('rate_limits') or {}).get('five_hour') or {}).get('used_percentage') or '', end='')")
transcript_path=$(_py "print(d.get('transcript_path') or '', end='')")

# -- ANSI colours --
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'
RESET='\033[0m'

# -- Directory --
if [ -n "$cwd" ]; then
  short_cwd=$(python3 -c "
import os, sys
cwd = sys.argv[1].replace('\\\\', '/')
home = os.path.expanduser('~').replace('\\\\', '/')
print('~' + cwd[len(home):] if cwd.startswith(home) else cwd, end='')
" "$cwd" 2>/dev/null)
  dir_part=$(printf "${CYAN}${BOLD}📁 %s${RESET}" "$short_cwd")
else
  dir_part=""
fi

# -- Model --
[ -n "$model" ] && model_part=$(printf "${DIM}%s${RESET}" "$model") || model_part=""

# -- Context usage --
if [ -n "$used_pct" ]; then
  pct_int=$(python3 -c "print(round(float('$used_pct')))" 2>/dev/null)
  if [ "${pct_int:-0}" -ge 80 ]; then ctx_colour="$RED"
  elif [ "${pct_int:-0}" -ge 50 ]; then ctx_colour="$YELLOW"
  else ctx_colour="$GREEN"; fi
  ctx_part=$(printf "${ctx_colour}ctx:%d%%${RESET}" "$pct_int")
else
  ctx_part=""
fi

# -- Git status --
git_part=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  uncommitted=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  sync_status=""
  upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{u} 2>/dev/null)
  if [ -n "$upstream" ]; then
    ahead=$(git -C "$cwd" rev-list --count @{u}..HEAD 2>/dev/null)
    behind=$(git -C "$cwd" rev-list --count HEAD..@{u} 2>/dev/null)
    if [ "${ahead:-0}" -gt 0 ] && [ "${behind:-0}" -gt 0 ]; then
      sync_status="↑${ahead} ↓${behind}"
    elif [ "${ahead:-0}" -gt 0 ]; then
      sync_status="↑${ahead}"
    elif [ "${behind:-0}" -gt 0 ]; then
      sync_status="↓${behind}"
    else
      abs_git_dir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)
      fetch_head="${abs_git_dir}/FETCH_HEAD"
      if [ -f "$fetch_head" ]; then
        fetch_ago_min=$(python3 -c "
import os, sys, time
mt = os.path.getmtime(sys.argv[1])
print(int((time.time() - mt) / 60), end='')
" "$fetch_head" 2>/dev/null)
        if [ -n "$fetch_ago_min" ]; then
          if [ "$fetch_ago_min" -lt 60 ]; then
            sync_status="synced ${fetch_ago_min}m ago"
          else
            sync_status="synced $(( fetch_ago_min / 60 ))h ago"
          fi
        else
          sync_status="synced"
        fi
      else
        sync_status="synced"
      fi
    fi
  fi

  if [ "${uncommitted:-0}" -gt 0 ]; then
    if [ "$uncommitted" -eq 1 ]; then
      single_file=$(git -C "$cwd" status --porcelain 2>/dev/null | head -1 | sed 's/^...//')
      git_status_str="${single_file} uncommitted"
    else
      git_status_str="${uncommitted} uncommitted"
    fi
    [ -n "$sync_status" ] && git_status_str="${git_status_str}, ${sync_status}"
    git_part=$(printf "${YELLOW}🔀 %s (%s)${RESET}" "$branch" "$git_status_str")
  elif [ -n "$sync_status" ]; then
    git_part=$(printf "${YELLOW}🔀 %s (%s)${RESET}" "$branch" "$sync_status")
  elif [ -n "$branch" ]; then
    git_part=$(printf "${YELLOW}🔀 %s${RESET}" "$branch")
  fi
fi

# -- Repo --
[ -n "$repo" ] && repo_part=$(printf "${BLUE}%s${RESET}" "$repo") || repo_part=""

# -- PR --
if [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved)          pr_colour="$GREEN" ;;
    changes_requested) pr_colour="$RED" ;;
    draft)             pr_colour="$DIM" ;;
    *)                 pr_colour="$YELLOW" ;;
  esac
  [ -n "$pr_state" ] \
    && pr_part=$(printf "${pr_colour}PR#%s(%s)${RESET}" "$pr_num" "$pr_state") \
    || pr_part=$(printf "${pr_colour}PR#%s${RESET}" "$pr_num")
else
  pr_part=""
fi

# -- Vim mode --
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT)  vim_colour="$GREEN" ;;
    VISUAL*) vim_colour="$MAGENTA" ;;
    *)       vim_colour="$YELLOW" ;;
  esac
  vim_part=$(printf "${vim_colour}[%s]${RESET}" "$vim_mode")
else
  vim_part=""
fi

# -- Agent --
[ -n "$agent_name" ] && agent_part=$(printf "${MAGENTA}agent:%s${RESET}" "$agent_name") || agent_part=""

# -- Rate limit (5-hour) --
if [ -n "$five_hr" ]; then
  five_int=$(python3 -c "print(round(float('$five_hr')))" 2>/dev/null)
  if [ "${five_int:-0}" -ge 80 ]; then rl_colour="$RED"
  elif [ "${five_int:-0}" -ge 50 ]; then rl_colour="$YELLOW"
  else rl_colour="$DIM"; fi
  rl_part=$(printf "${rl_colour}5h:%d%%${RESET}" "$five_int")
else
  rl_part=""
fi

# -- Assemble main line --
SEP=$(printf "${DIM} | ${RESET}")
line=""
for part in "$dir_part" "$model_part" "$ctx_part" "$git_part" "$repo_part" "$pr_part" "$rl_part" "$vim_part" "$agent_part"; do
  if [ -n "$part" ]; then
    [ -n "$line" ] && line="${line}${SEP}${part}" || line="$part"
  fi
done
printf "%b\n" "$line"

# -- Last user message from transcript --
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  last_msg=$(python3 - "$transcript_path" <<'PYEOF'
import sys, json

path = sys.argv[1]
last = None
try:
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get('isSidechain') or e.get('isApiErrorMessage'):
                continue
            if e.get('type') != 'human' and e.get('role') != 'user':
                continue
            msg = e.get('message') or e.get('text') or ''
            if isinstance(msg, dict):
                c = msg.get('content', '')
                if isinstance(c, str):
                    msg = c
                elif isinstance(c, list):
                    msg = ' '.join(x.get('text','') for x in c if x.get('type')=='text')
            if isinstance(msg, str) and msg and \
               not msg.startswith('[Request interrupted') and \
               not msg.startswith('[Request cancelled'):
                last = msg
except Exception:
    pass

if last:
    first = last.split('\n')[0]
    truncated = first[:80] + ('…' if len(first) > 80 or '\n' in last else '')
    print(truncated, end='')
PYEOF
)
  if [ -n "$last_msg" ]; then
    printf "${DIM}💬 %s${RESET}\n" "$last_msg"
  fi
fi

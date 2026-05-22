#!/usr/bin/env bash
# Claude Code status line script
# Displays: dir | model | context% | repo | PR | vim mode | agent

input=$(cat)

# -- Fields --
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')
pr_num=$(echo "$input" | jq -r '.pr.number // empty')
pr_state=$(echo "$input" | jq -r '.pr.review_state // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# -- ANSI colours (dimmed-friendly) --
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'
RESET='\033[0m'

# -- Directory: shorten home to ~ --
if [ -n "$cwd" ]; then
  home_dir="$HOME"
  short_cwd="${cwd/#$home_dir/\~}"
  dir_part=$(printf "${CYAN}${BOLD}%s${RESET}" "$short_cwd")
else
  dir_part=""
fi

# -- Model --
if [ -n "$model" ]; then
  model_part=$(printf "${DIM}%s${RESET}" "$model")
else
  model_part=""
fi

# -- Context usage bar --
if [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  if [ "$pct_int" -ge 80 ]; then
    ctx_colour="$RED"
  elif [ "$pct_int" -ge 50 ]; then
    ctx_colour="$YELLOW"
  else
    ctx_colour="$GREEN"
  fi
  ctx_part=$(printf "${ctx_colour}ctx:%d%%${RESET}" "$pct_int")
else
  ctx_part=""
fi

# -- Repo --
if [ -n "$repo" ]; then
  repo_part=$(printf "${BLUE}%s${RESET}" "$repo")
else
  repo_part=""
fi

# -- PR --
if [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved)         pr_colour="$GREEN" ;;
    changes_requested) pr_colour="$RED" ;;
    draft)            pr_colour="$DIM" ;;
    *)                pr_colour="$YELLOW" ;;
  esac
  if [ -n "$pr_state" ]; then
    pr_part=$(printf "${pr_colour}PR#%s(%s)${RESET}" "$pr_num" "$pr_state")
  else
    pr_part=$(printf "${pr_colour}PR#%s${RESET}" "$pr_num")
  fi
else
  pr_part=""
fi

# -- Vim mode --
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT)      vim_colour="$GREEN" ;;
    VISUAL*)     vim_colour="$MAGENTA" ;;
    *)           vim_colour="$YELLOW" ;;
  esac
  vim_part=$(printf "${vim_colour}[%s]${RESET}" "$vim_mode")
else
  vim_part=""
fi

# -- Agent name --
if [ -n "$agent_name" ]; then
  agent_part=$(printf "${MAGENTA}agent:%s${RESET}" "$agent_name")
else
  agent_part=""
fi

# -- Rate limit (5-hour) --
if [ -n "$five_hr" ]; then
  five_int=$(printf "%.0f" "$five_hr")
  if [ "$five_int" -ge 80 ]; then
    rl_colour="$RED"
  elif [ "$five_int" -ge 50 ]; then
    rl_colour="$YELLOW"
  else
    rl_colour="$DIM"
  fi
  rl_part=$(printf "${rl_colour}5h:%d%%${RESET}" "$five_int")
else
  rl_part=""
fi

# -- Assemble parts with separator --
SEP=$(printf "${DIM} | ${RESET}")
line=""
for part in "$dir_part" "$model_part" "$ctx_part" "$repo_part" "$pr_part" "$rl_part" "$vim_part" "$agent_part"; do
  if [ -n "$part" ]; then
    if [ -n "$line" ]; then
      line="${line}${SEP}${part}"
    else
      line="$part"
    fi
  fi
done

printf "%b\n" "$line"

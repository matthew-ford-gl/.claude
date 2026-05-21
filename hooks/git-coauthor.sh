#!/bin/bash
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')

if echo "$cmd" | grep -qE 'git\s+commit' && ! echo "$cmd" | grep -q '\-\-amend'; then
  git -C "$cwd" commit --amend --no-edit \
    --trailer "Co-authored-by: Claude <claude@anthropic.com>" 2>/dev/null
fi
exit 0
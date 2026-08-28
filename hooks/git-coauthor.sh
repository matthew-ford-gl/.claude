#!/bin/bash
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))' 2>/dev/null)
cwd=$(printf '%s' "$input" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("cwd", ""))' 2>/dev/null)

if echo "$cmd" | grep -qE 'git\s+commit' && ! echo "$cmd" | grep -q '\-\-amend'; then
  git -C "$cwd" commit --amend --no-edit \
    --trailer "Co-authored-by: Claude <claude@anthropic.com>" 2>/dev/null
fi
exit 0

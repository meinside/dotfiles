#!/usr/bin/env bash
#
# ~/.claude/statusline-command.sh
#
# last update: 2026.03.18.

# Read JSON input from stdin
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
session_name=$(echo "$input" | jq -r '.session_name // empty')
user=$(whoami)
host=$(hostname -s)

# Directory display
dir=$(basename "$cwd")
if [ "$cwd" = "$HOME" ]; then
    dir="~"
fi

# Git info (matching starship git_branch=cyan, git_status=red)
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_info=" \033[36m${branch}\033[0m\033[31m*\033[0m"
    else
        git_info=" \033[36m${branch}\033[0m"
    fi
fi

# Session info
session_info=""
if [ -n "$session_name" ]; then
    session_info=" [${session_name}]"
fi

# Cost for this session
total_cost=$(printf '💰%.2f' "$(echo "$input" | jq -r '.cost.total_cost_usd // 0')")

# Model info (dimmed)
model=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')
model_info=""
if [ -n "$model" ]; then
    model_info=" \033[2m${model}\033[0m"
fi

# Context remaining (green >50%, yellow 20-50%, red <20%)
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_info=""
if [ -n "$context_remaining" ]; then
    context_int=${context_remaining%.*}
    if [ "$context_int" -lt 20 ]; then
        ctx_info=" \033[31m[ctx:${context_remaining}%]\033[0m"
    elif [ "$context_int" -lt 50 ]; then
        ctx_info=" \033[33m[ctx:${context_remaining}%]\033[0m"
    else
        ctx_info=" \033[32m[ctx:${context_remaining}%]\033[0m"
    fi
fi

# Output
#
# username=blue, hostname=bright-red, directory=dimmed green (matching starship)
printf "\033[34m%s\033[0m@\033[91m%s\033[0m \033[2;32m%s\033[0m%b\n%s%b%b%s" \
    "$user" "$host" "$dir" "$git_info" "$session_info" "$model_info" "$ctx_info" "$total_cost"

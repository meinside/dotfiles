#!/usr/bin/env bash
#
# ~/.config/claude/statusline.sh
#
# last update: 2026.04.02.

# Read JSON input from stdin
input=$(cat)

user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
session_name=$(echo "$input" | jq -r '.session_name // empty')

# Current directory name
dir=$(basename "$cwd")
if [ "$cwd" = "$HOME" ]; then
    dir="~"
fi
dir="📂${dir}"

# Session info
session_info=""
if [ -n "$session_name" ]; then
    session_info="[${session_name}] "
fi

# Git info (git_branch=cyan, git_status=red)
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_info="\033[36m${branch}\033[0m\033[31m*\033[0m"
    else
        git_info="\033[36m${branch}\033[0m"
    fi
    git_info=" ${git_info}"
fi

# Model info (dimmed)
# - if model is ARN, try to use model name from settings.json instead
model=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')
if [[ "$model" == arn:aws:bedrock:* ]]; then
    _settings_model=$(jq -r '.model // empty' ~/.config/claude/settings.json 2>/dev/null)
    if [ -n "$_settings_model" ]; then
        model="$_settings_model"
    fi
fi
model_info=""
if [ -n "$model" ]; then
    model_info=" \033[2m${model}\033[0m"
fi

# Remaining context (green >50%, yellow 20-50%, red <20%)
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
context_total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx_info=""
if [ -n "$context_remaining" ]; then
    context_int=${context_remaining%.*}
    # Format max context size (e.g. 200000 -> 200K, 1000000 -> 1M)
    ctx_max=""
    if [ -n "$context_total" ]; then
        if [ "$context_total" -ge 1000000 ]; then
            ctx_max="/$(echo "$context_total" | awk '{printf "%.0fM", $1/1000000}')"
        elif [ "$context_total" -ge 1000 ]; then
            ctx_max="/$(echo "$context_total" | awk '{printf "%.0fK", $1/1000}')"
        else
            ctx_max="/${context_total}"
        fi
    fi
    if [ "$context_int" -lt 20 ]; then
        ctx_info=" \033[31m[${context_remaining}%${ctx_max}]\033[0m"
    elif [ "$context_int" -lt 50 ]; then
        ctx_info=" \033[33m[${context_remaining}%${ctx_max}]\033[0m"
    else
        ctx_info=" \033[32m[${context_remaining}%${ctx_max}]\033[0m"
    fi
fi

# Cost for this session
cost_info=$(printf '💰%.2f' "$(echo "$input" | jq -r '.cost.total_cost_usd // 0')")

# Resulting statusline
#
# username=blue, hostname=bright-red, directory=dimmed-green
printf "%s\033[34m%s\033[0m@\033[91m%s\033[0m \033[2;32m%s\033[0m%b\n%b%b%s" \
    "$session_info" "$user" "$host" "$dir" "$git_info" \
    "$model_info" "$ctx_info" "$cost_info"

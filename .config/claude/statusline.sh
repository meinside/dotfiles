#!/usr/bin/env bash
#
# ~/.config/claude/statusline.sh
#
# Claude Code statusline, kept in sync with the pi footer extension
# (~/.config/pi/agent/extensions/statusline.ts) so both agents look identical:
#
#   [session] user@host 📂~/path (branch*) (+12/-3)
#   model • thinking • [24.3%/200k] 💰0.123 • ↑1.2k ↓340 CR45k CW2.3k CH92.7% • ⏱️1m02s/5m10s
#
# Colors, icons and grouping come from that extension:
#   user=blue(34), host=bright red(91), 📂dir=dim green(2;32), branch=cyan(36),
#   dirty=red(31), +added/-removed=green(32)/red(31),
#   context=green(32)/yellow(33)/red(31) by usage, groups joined by a muted " • ".
#
# The extension's dim(2) text is spelled out here with pi's theme colors instead:
# ANSI dim only fades the default foreground, and Claude Code dims the status
# line again on its own, so `2m` ends up nearly unreadable. Muted gray
# (#808080, pi's `muted`) and text white (#d4d4d4, pi's `text`) survive that.
#
# Token/cache numbers come from `context_window.current_usage`, i.e. the most
# recent API response (= what currently sits in the context window).
#
# Requires jq, awk and git; runs on bash 3.2, so macOS' stock /bin/bash is fine.
# Enable it by pointing `statusLine` in settings.json at this file:
#   "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
#
# last update: 2026.08.20.

# Icons - set any of them to "" if the terminal font lacks the glyph
ICON_DIR="📂"
ICON_COST="💰"
ICON_TIME="⏱️"
ICON_BRANCH=""

# Context usage percentages that switch the color to yellow / red
CTX_WARN=70
CTX_ERROR=90

# Read JSON input from stdin
input=$(cat)

# Without jq every field below would silently come out empty, so say so instead
if ! command -v jq >/dev/null 2>&1; then
    printf 'statusline.sh: jq not found (brew install jq / apt install jq)\n'
    exit 0
fi

# Single jq pass: everything we need, one value per line (empty lines kept).
# Read with a loop rather than mapfile, which bash 3.2 (macOS /bin/bash) lacks.
_f=()
while IFS= read -r _line; do
    _f+=("$_line")
done < <(
    jq -r '[
        (.workspace.current_dir // .cwd // ""),
        (.session_name // ""),
        (.model.display_name // .model.id // ""),
        (.context_window.current_usage.input_tokens // 0),
        (.context_window.current_usage.output_tokens // 0),
        (.context_window.current_usage.cache_creation_input_tokens // 0),
        (.context_window.current_usage.cache_read_input_tokens // 0),
        (.context_window.used_percentage // ""),
        (.context_window.context_window_size // 0),
        (.cost.total_cost_usd // 0),
        (.cost.total_api_duration_ms // 0),
        (.cost.total_duration_ms // 0),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.effort.level // ""),
        (if .thinking.enabled == null then "" else (.thinking.enabled | tostring) end),
        (.rate_limits.five_hour.used_percentage // ""),
        (.session_id // "nosession")
    ]
    | map(if type == "string" then gsub("[\r\n\t]"; " ") else tostring end)
    | .[]' <<<"$input"
)

cwd=${_f[0]}
session_name=${_f[1]}
model=${_f[2]}
tok_in=${_f[3]:-0}
tok_out=${_f[4]:-0}
tok_cw=${_f[5]:-0}
tok_cr=${_f[6]:-0}
ctx_used=${_f[7]}
ctx_total=${_f[8]:-0}
cost_usd=${_f[9]:-0}
api_ms=${_f[10]:-0}
wall_ms=${_f[11]:-0}
lines_added=${_f[12]:-0}
lines_removed=${_f[13]:-0}
effort=${_f[14]}
thinking=${_f[15]}
rl5=${_f[16]}
session_id=${_f[17]}

# ANSI codes, same ones the pi extension uses
RESET=$'\033[0m'
BLUE=$'\033[34m'
BRED=$'\033[91m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
DIMGREEN=$'\033[2;32m'
# from pi's dark theme (dist/modes/interactive/theme/dark.json)
MUTED=$'\033[38;2;128;128;128m' # muted / gray  #808080 - stats, bullets
TEXT=$'\033[38;2;212;212;212m'  # text          #d4d4d4 - cost

# ---------------------------------------------------------------- formatters

# pi's formatTokens(): 999 / 1.2k / 45k / 1.2M / 12M
fmt_tokens() {
    awk -v n="${1:-0}" 'BEGIN {
        if (n < 1000)       printf "%d", n;
        else if (n < 10000) printf "%.1fk", n / 1000;
        else if (n < 1000000)  printf "%.0fk", n / 1000;
        else if (n < 10000000) printf "%.1fM", n / 1000000;
        else printf "%.0fM", n / 1000000;
    }'
}

# pi's formatDuration(): 42s / 1m02s / 2h05m
fmt_duration() {
    local secs=${1:-0}
    if [ "$secs" -ge 3600 ]; then
        printf '%dh%02dm' $((secs / 3600)) $(((secs % 3600) / 60))
    elif [ "$secs" -ge 60 ]; then
        printf '%dm%02ds' $((secs / 60)) $((secs % 60))
    else
        printf '%ds' "$secs"
    fi
}

# ----------------------------------------------------------- line 1: location
#
#   [session] user@host 📂~/path (branch*) (+12/-3)

user=$(whoami)
host=$(hostname -s)

# cwd with $HOME collapsed to ~ (pi's shortenPath)
pwd_str="$cwd"
case "$cwd" in
"$HOME") pwd_str="~" ;;
"$HOME"/*) pwd_str="~${cwd#"$HOME"}" ;;
esac

loc=()

# session name, leftmost
[ -n "$session_name" ] && loc+=("${MUTED}[${session_name}]${RESET}")

loc+=("${BLUE}${user}${RESET}@${BRED}${host}${RESET}")
loc+=("${DIMGREEN}${ICON_DIR}${pwd_str}${RESET}")

# git branch + dirty flag, cached per session/cwd for 5s (git status is slow in big repos)
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    # key the cache by session *and* cwd: the working directory can change mid-session
    cwd_key=$(printf '%s' "$cwd" | cksum | tr -cd '0-9')
    cache_file="${TMPDIR:-/tmp}/claude-statusline-git-${session_id}-${cwd_key}"
    cache_age=999
    if [ -f "$cache_file" ]; then
        mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        cache_age=$(($(date +%s) - mtime))
    fi
    if [ "$cache_age" -ge 5 ]; then
        branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
        [ -z "$branch" ] && branch="detached"
        dirty=""
        [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ] && dirty="*"
        printf '%s\t%s\n' "$branch" "$dirty" >"$cache_file" 2>/dev/null
    else
        IFS=$'\t' read -r branch dirty <"$cache_file"
    fi
    if [ -n "$branch" ]; then
        if [ -n "$dirty" ]; then
            loc+=("${CYAN}${ICON_BRANCH}${branch}${RESET}${RED}*${RESET}")
        else
            loc+=("${CYAN}${ICON_BRANCH}${branch}${RESET}")
        fi
    fi
fi

# lines added/removed this session
if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
    loc+=("(${GREEN}+${lines_added}${RESET}/${RED}-${lines_removed}${RESET})")
fi

line1=$(
    IFS=' '
    printf '%s' "${loc[*]}"
)

# -------------------------------------------------------------- line 2: stats
#
#   model • thinking • [ctx%/window] 💰cost • ↑in ↓out CR.. CW.. CH..% • ⏱️api/wall

groups=()

# model, plus thinking effort
[ -z "$model" ] && model="no-model"
if [ "$thinking" = "false" ]; then
    groups+=("${MUTED}${model} • thinking off${RESET}")
elif [ -n "$effort" ]; then
    groups+=("${MUTED}${model} • ${effort}${RESET}")
else
    groups+=("${MUTED}${model}${RESET}")
fi

# context usage + session cost
usage=()
if [ -z "$ctx_used" ] && [ "${ctx_total:-0}" -gt 0 ] && [ $((tok_in + tok_cr + tok_cw)) -gt 0 ]; then
    ctx_used=$(awk -v i="$tok_in" -v r="$tok_cr" -v w="$tok_cw" -v t="$ctx_total" \
        'BEGIN{printf "%.1f", (i + r + w) / t * 100}')
fi
if [ "${ctx_total:-0}" -gt 0 ]; then
    if [ -n "$ctx_used" ]; then
        ctx_str="[$(awk -v p="$ctx_used" 'BEGIN{printf "%.1f", p}')%/$(fmt_tokens "$ctx_total")]"
    else
        # unknown right after /compact, until the next response
        ctx_str="[?/$(fmt_tokens "$ctx_total")]"
    fi
    ctx_int=${ctx_used%%.*}
    if [ "${ctx_int:-0}" -gt "$CTX_ERROR" ]; then
        usage+=("${RED}${ctx_str}${RESET}")
    elif [ "${ctx_int:-0}" -gt "$CTX_WARN" ]; then
        usage+=("${YELLOW}${ctx_str}${RESET}")
    else
        usage+=("${GREEN}${ctx_str}${RESET}")
    fi
fi
if [ "$(awk -v c="${cost_usd:-0}" 'BEGIN{print (c > 0) ? 1 : 0}')" = "1" ]; then
    usage+=("${TEXT}${ICON_COST}$(awk -v c="$cost_usd" 'BEGIN{printf "%.3f", c}')${RESET}")
fi
if [ ${#usage[@]} -gt 0 ]; then
    groups+=("$(
        IFS=' '
        printf '%s' "${usage[*]}"
    )")
fi

# tokens: input / output / cache read / cache write / cache hit rate
tokens=()
[ "${tok_in:-0}" -gt 0 ] && tokens+=("↑$(fmt_tokens "$tok_in")")
[ "${tok_out:-0}" -gt 0 ] && tokens+=("↓$(fmt_tokens "$tok_out")")
[ "${tok_cr:-0}" -gt 0 ] && tokens+=("CR$(fmt_tokens "$tok_cr")")
[ "${tok_cw:-0}" -gt 0 ] && tokens+=("CW$(fmt_tokens "$tok_cw")")
# cache hit rate = cacheRead / (input + cacheRead + cacheWrite)
if [ "${tok_cr:-0}" -gt 0 ] || [ "${tok_cw:-0}" -gt 0 ]; then
    prompt_total=$((tok_in + tok_cr + tok_cw))
    if [ "$prompt_total" -gt 0 ]; then
        tokens+=("CH$(awk -v r="$tok_cr" -v t="$prompt_total" 'BEGIN{printf "%.1f%%", r / t * 100}')")
    fi
fi
if [ ${#tokens[@]} -gt 0 ]; then
    groups+=("${MUTED}$(
        IFS=' '
        printf '%s' "${tokens[*]}"
    )${RESET}")
fi

# api/wall durations
if [ "${api_ms:-0}" -gt 0 ] || [ "${wall_ms:-0}" -gt 0 ]; then
    groups+=("${MUTED}${ICON_TIME}$(fmt_duration $((api_ms / 1000)))/$(fmt_duration $((wall_ms / 1000)))${RESET}")
fi

# 5h rate limit, only once it starts to matter (subscription sessions only)
if [ -n "$rl5" ]; then
    rl5_int=${rl5%%.*}
    if [ "${rl5_int:-0}" -ge 50 ]; then
        if [ "$rl5_int" -ge 90 ]; then
            groups+=("${RED}5h:${rl5_int}%${RESET}")
        else
            groups+=("${YELLOW}5h:${rl5_int}%${RESET}")
        fi
    fi
fi

# groups joined by a muted bullet
line2=""
for group in "${groups[@]}"; do
    if [ -z "$line2" ]; then
        line2="$group"
    else
        line2="${line2}${MUTED} • ${RESET}${group}"
    fi
done

# --------------------------------------------------------------------- output

printf '%s\n%s\n' "$line1" "$line2"

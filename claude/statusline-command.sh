#!/bin/bash
input=$(cat)

# --- Helper: draw a progress bar ---
# Usage: progress_bar <percentage> <width>
progress_bar() {
    local pct="${1:-0}"
    local width="${2:-10}"
    local filled=$(printf "%.0f" "$(echo "$pct $width" | awk '{printf "%f", $1 * $2 / 100}')")
    local empty=$((width - filled))
    local bar=""
    for ((i = 0; i < filled; i++)); do bar="${bar}#"; done
    for ((i = 0; i < empty; i++)); do bar="${bar}-"; done
    printf "%s" "$bar"
}

# --- Colors (256-color ANSI) ---
RESET="\033[0m"
BOLD="\033[1m"

# Model: cyan
C_MODEL="\033[36m"
# Context: yellow
C_CTX="\033[33m"
# Rate limit: magenta
C_RATE="\033[35m"
# CWD: blue
C_CWD="\033[34m"
# Dim separator
C_SEP="\033[2m"

# --- Extract values ---
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // "."')

ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Replace home directory prefix with ~
home_dir="$HOME"
cwd="${cwd/#$home_dir/\~}"

# --- Build output ---
out=""

# 1) Model
out="${out}${BOLD}${C_MODEL}${RESET}${C_MODEL}${model}${RESET}"

# 2) Context window (only when data is available)
out="${out} ${C_SEP}|${RESET} ${BOLD}${C_CTX}ctx: ${RESET}"
if [ -n "$ctx_used" ]; then
    bar=$(progress_bar "$ctx_used" 10)
    out="${out}${C_CTX}[${bar}] $(printf '%.0f' "$ctx_used")%${RESET}"
else
    out="${out}${C_CTX}n/a${RESET}"
fi

# 3) 5-hour rate limit (only when data is available)
out="${out} ${C_SEP}|${RESET} ${BOLD}${C_RATE}5h: ${RESET}"
if [ -n "$five_pct" ]; then
    bar=$(progress_bar "$five_pct" 10)
    out="${out}${C_RATE}[${bar}] $(printf '%.0f' "$five_pct")%${RESET}"
else
    out="${out}${C_RATE}n/a${RESET}"
fi

# 4) CWD
out="${out} ${C_SEP}|${RESET} ${BOLD}${C_CWD}${cwd}${RESET}"

printf "%b" "$out"

#!/bin/bash
# Shared logging for the claudesafe scripts. Source it, setting LOG_PREFIX
# first to name the message's source.

LOG_PREFIX="${LOG_PREFIX:-claudesafe}"

# Color only when the stream is a terminal, so a redirected log stays greppable.
LOG_WARN_TAG="[WARNING]"
LOG_ERROR_TAG="[ERROR]"
if [ -z "${NO_COLOR:-}" ]; then
    if [ -t 1 ]; then
        LOG_WARN_TAG=$'\033[1;33m[WARNING]\033[0m'
    fi
    if [ -t 2 ]; then
        LOG_ERROR_TAG=$'\033[1;31m[ERROR]\033[0m'
    fi
fi

# IFS is set locally because init-firewall.sh narrows it to newline/tab, which
# would otherwise join a multi-word message with newlines.
log_info() {
    local IFS=' '
    printf '[%s] %s\n' "$LOG_PREFIX" "$*"
}

log_warn() {
    local IFS=' '
    printf '[%s] %s %s\n' "$LOG_PREFIX" "$LOG_WARN_TAG" "$*"
}

log_error() {
    local IFS=' '
    printf '[%s] %s %s\n' "$LOG_PREFIX" "$LOG_ERROR_TAG" "$*" >&2
}

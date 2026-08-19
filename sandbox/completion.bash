#!/bin/bash
# Bash completion for claudesafe. Installed by install.sh as
# ~/.local/share/bash-completion/completions/claudesafe, which bash-completion
# loads on demand; source it from .bashrc instead if that package is missing.

# The flag list is scraped from the usage header rather than repeated here, so
# a new flag in launch.sh completes without touching this file.
_claudesafe_flags() {
    claudesafe --help 2> /dev/null \
        | sed -n 's/^#[[:space:]]*claudesafe[[:space:]]\{1,\}\(--[a-z-]\{1,\}\).*/\1/p'
}

_claudesafe() {
    local word="${COMP_WORDS[COMP_CWORD]}"
    local index

    # Everything after -- belongs to claude, not to us.
    index=1
    while [ "$index" -lt "$COMP_CWORD" ]; do
        if [ "${COMP_WORDS[index]}" = "--" ]; then
            COMPREPLY=()
            return 0
        fi
        index=$((index + 1))
    done

    if [ -z "${_CLAUDESAFE_FLAGS:-}" ]; then
        _CLAUDESAFE_FLAGS="$(_claudesafe_flags | tr '\n' ' ')"
    fi

    mapfile -t COMPREPLY < <(compgen -W "$_CLAUDESAFE_FLAGS" -- "$word")
}

complete -F _claudesafe claudesafe

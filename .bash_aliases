# Don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
HISTSIZE=4096
HISTFILESIZE=4096
shopt -s histappend

# ls aliases
if which exa >&/dev/null || which eza >&/dev/null; then
    if which eza >&/dev/null; then
        alias exa='eza'
    fi
    alias ls='exa'
    alias ll='exa -haal --git'
    alias lt='exa -hlT --git'
else
    alias ll='ls -alF'
    alias l='ls -CF'
fi

# Vim aliases
if which nvim >&/dev/null; then
    EDITOR=nvim
    VISUAL=nvim
    alias vi='nvim'
    alias vim='nvim'
else
    EDITOR=vim
    VISUAL=vim
    alias vi='vim'
fi

# Apt aliases
if which nala >&/dev/null; then
    alias apt=nala
    alias apt-get=nala
elif which apt-fast >&/dev/null; then
    alias apt=apt-fast
    alias apt-get=apt-fast
fi

# Misc aliases
alias sudo='sudo ' # Needed to make aliases work for sudo
alias ip='ip --color'

function mkcd() {
    if [ "$#" -eq 1 ]; then
        mkdir "$1"
        if [ "$?" = 0 ]; then
            cd "$1"
        fi
    else
        echo "Missing folder name, or wrong amount of arguments!"
    fi
}

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ "$?" = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Compute checksum of folder
sha1folder() {
    if [ "$#" -eq 1 ]; then
        find "$1" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum
    else
        echo "Missing folder parameter!"
    fi
}

# List ascending disk usage of all items in the folder, in user-readable format
alias folder_usage='du -hd 1 . | sort -h'

# Print all files in a folder
print_folder() {
    if [ "$#" -eq 1 ]; then
        find "$1" -name "*" -exec /usr/bin/lpr {} \;
    else
        echo "Missing folder parameter!"
    fi
}

# Layout aliases
alias layout_swerty='setxkbmap -layout se -variant swerty'
alias layout_se='setxkbmap -layout se'

# Add git aliases
alias gip='git pull'
alias gipu='git push'
alias gipuf='git push --force-with-lease'
alias gipud='git push -d origin '
alias gipuu='git push -u origin '

alias gis='git status'

alias gia='git add'
alias giau='git add -u'
alias giap='git add -p'

alias gicl='git clone'
alias gica='git commit --amend'
alias gicanv='git commit --no-verify --amend'

alias gil='git log'
alias gitk='gitk_background'
alias gig='git gui &'

alias gist='git stash'
alias gisp='git stash pop'

alias girc='git rebase --continue'

alias gisw='git switch'
alias gich='git checkout'
alias gichp='git checkout -p'

gitk_background() {
    \gitk "$@" &
}

giri() {
    if [ "$#" -eq 1 ]; then
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            git rebase --interactive "HEAD~$1"
        else
            git rebase --interactive "$1"
        fi
    else
        echo "Missing commit count/hash!"
    fi
}

gic() {
    if [ "$#" -eq 1 ]; then
        git commit -m "$1"
    elif [ "$#" -eq 2 ]; then
        git commit -m "$1" -m "$2"
    else
        echo "Missing message parameter!"
    fi
}

gicnv() {
    if [ "$#" -eq 1 ]; then
        git commit --no-verify -m "$1"
    elif [ "$#" -eq 2 ]; then
        git commit --no-verify -m "$1" -m "$2"
    else
        echo "Missing message parameter!"
    fi
}

SSH_ENV="$HOME/.ssh/environment"

function start_agent {
    echo "Initializing new SSH agent..."
    # spawn ssh-agent
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo "Initialization succeeded!"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add || {
        kill ${SSH_AGENT_PID}
        echo "Failed to add identity, forgot password?"
    }
}

gii() {
    if [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" > /dev/null
        ps -ef | grep "${SSH_AGENT_PID}" | grep ssh-agent$ > /dev/null || {
            start_agent
        }
    else
        start_agent
    fi
}

# Auto-completion for aliases
# TODO Auto-generate These type of functions. List with 'alias -p'.
# - Substitute 1 with amount of args to git
# - Substitute 'git stash' with actual command
# - Substitute 'gisw' with actual aliases
# - If necessary take inspiration from: https://superuser.com/a/437508
#
# To find existing auto-completions for a command run `complete -p <command>`
# If they don't exist you can force-load them with `_completion_loader`
_completion_loader git

function _alias_completion::gil {
    ((COMP_CWORD += 1))
    COMP_WORDS=(git switch ${COMP_WORDS[@]:1})
    ((COMP_POINT -= ${#COMP_LINE}))
    COMP_LINE=${COMP_LINE/gil/git log}
    ((COMP_POINT += ${#COMP_LINE}))
    __git_wrap__git_main
}
complete -o bashdefault -o default -o nospace -F _alias_completion::gil gil

function _alias_completion::gisw {
    ((COMP_CWORD += 1))
    COMP_WORDS=(git switch ${COMP_WORDS[@]:1})
    ((COMP_POINT -= ${#COMP_LINE}))
    COMP_LINE=${COMP_LINE/gisw/git switch}
    ((COMP_POINT += ${#COMP_LINE}))
    __git_wrap__git_main
}
complete -o bashdefault -o default -o nospace -F _alias_completion::gisw gisw

function _alias_completion::gich {
    ((COMP_CWORD += 1))
    COMP_WORDS=(git checkout ${COMP_WORDS[@]:1})
    ((COMP_POINT -= ${#COMP_LINE}))
    COMP_LINE=${COMP_LINE/gich/git checkout}
    ((COMP_POINT += ${#COMP_LINE}))
    __git_wrap__git_main
}
complete -o bashdefault -o default -o nospace -F _alias_completion::gich gich

# Set up fzf key bindings and fuzzy completion
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    . /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/fzf/key-bindings.bash ]; then
    . /usr/share/fzf/key-bindings.bash
fi
# NOTE: Disable completions because they have little gain and mess up autocomplete for
# my git aliases.
# if [ -f /usr/share/bash-completion/completions/fzf ]; then
#     . /usr/share/bash-completion/completions/fzf
# fi
# if [ -f /usr/share/fzf/completions.bash ]; then
#     . /usr/share/fzf/completions.bash
# fi

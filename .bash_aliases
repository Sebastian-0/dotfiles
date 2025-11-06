root_path="$(dirname -- "${BASH_SOURCE[0]}")"

. "$root_path/utils/ssh_env.sh"

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
elif which vim >&/dev/null; then
    EDITOR=vim
    VISUAL=vim
    alias vi='vim'
else
    EDITOR=vi
    VISUAL=vi
fi

# Kitty kitten aliases
if [ "$TERM" = "xterm-kitty" ]; then
    if [ -z "$SSH_TTY" ]; then
        # If we are NOT running an ssh session but think we are a Kitty terminal we are
        # probably a Kitty terminal, so use the ssh kitten. This makes sure the
        # xterm-kitty value of TERM doesn't break the remote terminal.
        alias ssh="kitten ssh"
        alias diff="kitten diff"
        alias icat="kitten icat"
    else
        # If we are in a remote session we don't know if we run Kitty or not on this
        # machine, so do the second best and change the TERM for the nested ssh session.
        # Note, if the first ssh session doesn't have this .bashrc script we will get a
        # broken terminal on the nested session, but not much to do about that.
        alias ssh="TERM=xterm ssh"
    fi
fi

# Misc aliases
alias sudo='sudo ' # Needed to make aliases work for sudo
alias ip='ip --color'
alias gnome-control-center='env XDG_CURRENT_DESKTOP=GNOME gnome-control-center'

# Nmtui color fixes, see:
# - Colorable objects: https://github.com/mlichvar/newt/blob/ecd43ab512e707f6e7873368871b517ed3206859/newt.c#L234
# - Possible colors: black, gray, red, brightred, green, brightgreen, brown, yellow, blue,
#                    brightblue, magenta, brightmagenta, cyan, brightcyan, lightgray, white
#                    See: https://www.jedsoft.org/slang/doc/html/cslang-8.html
# - Parsing of colors: https://github.com/NetworkManager/NetworkManager/blob/83d99669f53557aeed2934d0687339ba8adf64d1/src/libnmt-newt/nmt-newt-utils.c#L122
alias nmtui="NEWT_COLORS='entry=black,white;label=black,white' nmtui"

function mkcd() {
    if [ "$#" -eq 1 ]; then
        if mkdir -p "$1"; then
            cd "$1" || exit 1
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
folder_usage() {
    local TARGET="${1:-.}"
    sudo du -hd 1 "$TARGET" | sort -h
}

# Print all files in a folder
print_folder() {
    if [ "$#" -eq 1 ]; then
        find "$1" -name "*" -exec /usr/bin/lpr {} \;
    else
        echo "Missing folder parameter!"
    fi
}

# List all docker images and corresponding tags in a docker registry
docker_registry_list_tags() {
    if [ -z "$DOCKER_REGISTRY" ]; then
        echo "The DOCKER_REGISTRY environment variable must be set!"
        exit 1
    fi
    for repo in $(curl -sk "https://$DOCKER_REGISTRY/v2/_catalog" | jq -r '.repositories[]'); do
        echo "=== $repo ==="
        curl -sk "https://$DOCKER_REGISTRY/v2/$repo/tags/list" | jq -r '.tags[]?' | sort
    done
}

# Layout aliases
alias layout_swerty='setxkbmap -layout se -variant swerty'
alias layout_se='setxkbmap -layout se'

# Add git aliases

# Auto-completion for aliases
# TODO Auto-generate These type of functions. List with 'alias -p'.
# - If necessary take inspiration from: https://superuser.com/a/437508
#
# To find existing auto-completions for a command run `complete -p <command>`
# If they don't exist you can force-load them with `_completion_loader`
define_git_alias() {
    local alias_name="$1"
    shift
    local git_command="$1"
    shift
    local alias_command="$1"
    shift

    _completion_loader git

    eval "
    function _alias_completion::$alias_name {
        ((COMP_CWORD += 1))
        COMP_WORDS=($git_command \${COMP_WORDS[@]:1})
        ((COMP_POINT -= \${#COMP_LINE}))
        COMP_LINE=\${COMP_LINE/$alias_name/$git_command}
        ((COMP_POINT += \${#COMP_LINE}))
        __git_wrap__git_main
    }"
    complete -o bashdefault -o default -o nospace -F "_alias_completion::$alias_name" "$alias_name"

    if [ -n "$alias_command" ]; then
        alias "$alias_name=$alias_command"
    fi
}

define_git_alias gip 'git pull' 'git pull'
define_git_alias gipu 'git push' 'git push'
define_git_alias gipuf 'git push' 'git push --force-with-lease'
define_git_alias gipud 'git push' 'git push -d origin '
define_git_alias gipuu 'git push' 'git push -u origin '

define_git_alias gis 'git status' 'git status'
define_git_alias gil 'git log' 'git log'
define_git_alias gill 'git log' 'git log --pretty=oneline'
define_git_alias gid 'git diff' 'git diff'
define_git_alias gidw 'git diff' 'git diff --ignore-all-space --ignore-space-change'

define_git_alias gia 'git add' 'git add'
define_git_alias giau 'git add' 'git add -u'
define_git_alias giap 'git add' 'git add -p'

define_git_alias gicl 'git clone' 'git clone'
define_git_alias gica 'git commit' 'git commit --amend'
define_git_alias gicanv 'git commit' 'git commit --no-verify --amend'

define_git_alias gist 'git stash' 'git stash'
define_git_alias gisp 'git stash' 'git stash pop'

define_git_alias gicp 'git cherry-pick' 'git cherry-pick'
define_git_alias gicpc 'git cherry-pick' 'git cherry-pick --continue'
define_git_alias gicpa 'git cherry-pick' 'git cherry-pick --abort'

define_git_alias gisw 'git switch' 'git switch'
define_git_alias gich 'git checkout' 'git checkout'
define_git_alias gichp 'git checkout' 'git checkout -p'

alias gig='git gui &'
alias gitk='gitk_background'
gitk_background() {
    \gitk "$@" &
}

define_git_alias girc 'git rebase' 'git rebase --continue'
define_git_alias gira 'git rebase' 'git rebase --abort'
define_git_alias giri 'git rebase'
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
define_git_alias girib 'git rebase'
girib() {
    if [ "$#" -eq 1 ]; then
        git rebase --interactive "$(git merge-base "origin/$1" HEAD)"
    else
        echo "Missing target branch"
    fi
}

define_git_alias gic 'git commit'
gic() {
    if [ "$#" -eq 1 ]; then
        git commit --edit -m "$1"
    elif [ "$#" -eq 2 ]; then
        git commit --edit -m "$1" -m "$2"
    else
        git commit
    fi
}

define_git_alias gicnv 'git commit'
gicnv() {
    if [ "$#" -eq 1 ]; then
        git commit --no-verify --edit -m "$1"
    elif [ "$#" -eq 2 ]; then
        git commit --no-verify --edit -m "$1" -m "$2"
    else
        git commit --no-verify
    fi
}

ssh_start_agent() {
    launch() {
        echo "Initializing new SSH agent..."
        # spawn ssh-agent
        /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
        echo "Initialization succeeded!"
        chmod 600 "$SSH_ENV"
    }

    if [ -f "$SSH_ENV" ]; then
        . "$SSH_ENV" > /dev/null
        ps -ef | grep "$SSH_AGENT_PID" | grep ssh-agent$ > /dev/null || {
            launch
        }
    else
        launch
    fi
}

ssh_add_key() {
    . "$SSH_ENV" > /dev/null
    if ! ssh-add -l > /dev/null; then
        /usr/bin/ssh-add -t "$SSH_ADD_EXPIRY_SECONDS" || {
            kill "$SSH_AGENT_PID"
            echo "Failed to add identity, forgot password?"
        }
        date +%s%N > "$SSH_ADD_TIME"
    else
        start="$(cat "$SSH_ADD_TIME")"
        current="$(date +%s%N)"
        delta=$((SSH_ADD_EXPIRY_SECONDS * 1000000000 - (current - start)))
        echo "Time until key expiry: $( # Subshell to avoid leaking sourced symbols
            . "$root_path/utils/time.sh"
            nanos_to_str $delta
        )"
    fi
}

ssi() {
    ssh_start_agent
    ssh_add_key
}

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

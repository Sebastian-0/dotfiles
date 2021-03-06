# Don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Misc aliases
alias vi='vim'
alias sudo='sudo ' # Needed to make aliases work for sudo
alias ip='ip --color'

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

# Add git aliases
alias gip='git pull'
alias gipu='git push'

alias gis='git status'

alias gia='git add'
alias giau='git add -u'
alias giap='git add -p'

alias gicl='git clone'
alias gica='git commit --amend'

alias gil='git log'
alias gitk='gitk_background'
alias gig='git gui &'

alias gist='git stash'
alias gisp='git stash pop'

alias girc='git rebase --continue'

gitk_background() {
    \gitk "$@" &
}

giri() {
    if [ "$#" -eq 1 ]; then
        if [[ "$1" =~ [0-9]+ ]]; then
            git rebase --interactive "HEAD~$1"
        else
            echo "Commit count must be an integer"
        fi
    else
        echo "Missing commit count!"
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

SSH_ENV="$HOME/.ssh/environment"

function start_agent {
    echo "Initializing new SSH agent..."
    # spawn ssh-agent
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo "Initialization succeeded!"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add
}

gii() {
    if [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" > /dev/null
        ps -ef | grep "${SSH_AGENT_PID}" | grep ssh-agent$ > /dev/null || {
           start_agent;
        }
    else
        start_agent;
    fi
}

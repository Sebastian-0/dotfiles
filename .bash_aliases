# Don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Misc aliases
alias vi='vim'
alias sudo='sudo ' # Needed to make aliases work for sudo

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

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

gic() {
        if [ "$#" -eq 1 ]; then
                git commit -m "$1"
        elif [ "$#" -eq 2 ]; then
                git commit -m "$1" -m "$2"
        else
                echo "Missing message parameter!"
        fi
}

SSH_ENV=$HOME/.ssh/environment

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
        ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
           start_agent;
        }
    else
        start_agent;
    fi
}

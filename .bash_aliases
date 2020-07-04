alias vi=vim
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

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
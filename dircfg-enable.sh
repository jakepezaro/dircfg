#set -x

if [ -z "$ROOT_HISTFILE" ]; then
    ROOT_HISTFILE=$(readlink -f ~/.bash_history)
fi

function find-active-history-file() {
    path=$(pwd)
    while [ "$path" != "/" ]; do
        if [ -f "$path/.dircfg" ] && grep -q '^HISTFILE=' "$path/.dircfg"; then
            grep '^#HISTFILE=' "$path/.dircfg" | cut -d '=' -f 2
            return 0
        else
            path=$(dirname "$path")
        fi
    done
    echo "$ROOT_HISTFILE"
    
}

function find-first-history-file() {
    while read cfg; do
        if [ -e "$cfg" ] && grep '^#HISTFILE=' "$cfg" | cut -d '=' -f 2; then
            return 0
        fi
    done
    echo "$ROOT_HISTFILE"
}

function find-dirconfigs() {
    path=$(pwd)
    while [ "$path" != "/" ]; do
        if [ -f "$path/.dircfg" ]; then
            echo "$path/.dircfg"
        fi
        path=$(dirname "$path")
    done
}

function find-active-functions() {
    echo 'start'
    while read cfg; do
        echo ">>>$cfg"
        grep '^function ' $cfg
    done
    echo 'end'
}

function on-command() {
    old_history=$HISTFILE
    cfgs=$(find-dirconfigs)
    new_history=$(echo "$cfgs" | find-first-history-file)
    if [ "$old_history" != "$new_history" ]; then
        history -a
        export HISTFILE="$new_history"
        history -c
        history -r
    fi    
}

export PROMPT_COMMAND='on-command'
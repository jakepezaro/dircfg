if [ -z "$ROOT_HISTFILE" ]; then
    ROOT_HISTFILE=$(readlink -f ~/.bash_history)
fi

function find-dirconfigs() {
    i=0
    declare -a cfgs
    path=$(pwd)
    while [ "$path" != "/" ]; do
        if [ -f "$path/.dircfg" ]; then
            cfgs[$i]="$path/.dircfg"
            i=$(($i+1))
        fi
        path=$(dirname "$path")
    done
    if [ "${1:-}" == '--reverse' ]; then
        for ((j=0; j<i; j++)); do
            echo "${cfgs[$j]}"
        done
    else
        for ((j=i-1; j>=0; j--)); do
            echo "${cfgs[$j]}"
        done
    fi
}

function find-first-history-file() {
    while read cfg; do
        if [ -e "$cfg" ] && grep '^#HISTFILE=' "$cfg" | cut -d '=' -f 2; then
            return 0
        fi
    done
    echo "$ROOT_HISTFILE"
}

function on-command() {
    old_history=$HISTFILE
    cfgs=$(find-dirconfigs)
    new_history=$(echo "$cfgs" | find-first-history-file)
    if [ "$1" == '--debug' ]; then
        echo "DEBUG: old_history $old_history"
        echo "DEBUG: cfgs $cfgs"
        echo "DEBUG: new_history $new_history"
    fi    
    if [ "$old_history" != "$new_history" ]; then
        history -a
        export HISTFILE="$new_history"
        history -c
        history -r
    fi    
}

function dircfg() {
    if [ "$#" -eq 0 ] || [ "$1" == '--help' ] || [ "$1" == '--help' ]; then
        echo 'dircfg - create, edit and examine per-directory configs'
        echo '  --list:  list all directory configs that are active in your current directory'
    fi
    if [ "$1" == '--list' ]; then
        echo "HISTFILE=$ROOT_HISTFILE"
        find-dirconfigs -reverse | while read cfg; do
            if [ -e "$cfg" ]; then
                 grep '^#HISTFILE=' "$cfg" | sed 's/^#//g'
            fi            
        done
    fi
}

export PROMPT_COMMAND='on-command'

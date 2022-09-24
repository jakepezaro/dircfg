if [ -z "$ROOT_HISTFILE" ]; then
    ROOT_HISTFILE=$(readlink -f ~/.bash_history)
fi

DIRCFG_FUNCTIONS=''
DIRCFG_LASTDIR=''

function debug() {
    if [ ! -z "$DIRCFG_DEBUG" ]; then
        while read msg; do
            echo "DEBUG: $msg"
        done
    fi
}

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

function find-active-history-file() {
    while read cfg; do
        if [ -e "$cfg" ] && grep '^#HISTFILE=' "$cfg" | cut -d '=' -f 2; then
            return 0
        fi
    done
    echo "$ROOT_HISTFILE"
}

function initialise-history-file() {
    cfgs="$@"
    old_history="$HISTFILE"
    new_history=$(echo "$cfgs" | find-active-history-file)
    debug <<< "old_history=$old_history"
    debug <<< "cfgs=$cfgs"
    debug <<< "new_history=$new_history"
    if [ "$old_history" != "$new_history" ]; then
        debug <<< "Initialise HISTFILE $new_history"
        history -a
        export HISTFILE="$new_history"
        history -c
        history -r
    fi    
}

function list-functions() {
    cfg=$1
    grep -e '^function .*() {' "$cfg" | sed 's/^function \(.*\)() {$/\1/g'
}


function all-functions-loaded() {
    while read f; do
        if ! declare -F | grep -q -e "declare -f $f$"; then
            return 1
        fi
    done
}

function load-functions() {
    cfgs="$@"
    all_functions=''
    for cfg in "$cfgs"; do
        if [ -e "$cfg" ]; then
            cfg_functions="$(list-functions "$cfg")"
            if ! echo "$cfg_functions" | all-functions-loaded; then
                debug <<< "Sourcing $cfg"
                source "$cfg"
            fi
            all_functions="$all_functions $cfg_functions"
        fi
    done
    debug <<< "DIRCFG_FUNCTIONS [$DIRCFG_FUNCTIONS]"
    for prev_f in $DIRCFG_FUNCTIONS; do
        if ! echo "$all_functions" | grep -q "^$prev_f$"; then
            debug <<< "Removing $prev_f"
            unset -f "$prev_f"
        fi
    done
    DIRCFG_FUNCTIONS="$all_functions"
}

function on-command() {
    debug <<< "DIRCFG_LASTDIR=$DIRCFG_LASTDIR"
    debug <<< "PWD=$PWD"
    if [ "$DIRCFG_LASTDIR" != "$PWD" ]; then
        DIRCFG_LASTDIR="$PWD"
        cfgs=$(find-dirconfigs --reverse)
        debug <<< "configs: $cfgs"
        initialise-history-file "$cfgs"
        load-functions "$cfgs"
    fi
    debug <<< ''
}

function dircfg() {
    if [ "$#" -eq 0 ] || [ "$1" == '--help' ] || [ "$1" == '--help' ]; then
        echo 'dircfg - create, edit and examine per-directory configs'
        echo '  --list:  list all directory configs that are active in your current directory'
    fi
    if [ "$1" == '--list' ]; then
        echo "HISTFILE=$ROOT_HISTFILE"
        find-dirconfigs | while read cfg; do
            if [ -e "$cfg" ]; then
                 grep '^#HISTFILE=' "$cfg" | sed 's/^#//g'
            fi            
        done
    fi
}

export PROMPT_COMMAND='on-command'

if [ -z "$ROOT_HISTFILE" ]; then
    ROOT_HISTFILE=$(readlink -f ~/.bash_history)
fi

DIRCFG_FUNCTIONS=''
DIRCFG_LASTDIR=''

function debug() {
    if [ ! -z "$DIRCFG_DEBUG" ]; then
        while read -r msg; do
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
    debug <<< "initialise-history-file old_history=$old_history cfgs=$cfgs new_history=$new_history"
    if [ "$old_history" != "$new_history" ]; then
        debug <<< "initialise-history-file initialise HISTFILE $new_history"
        history -a
        export HISTFILE="$new_history"
        history -c
        history -r
    fi   
}

function is_loaded() {
    #return declare -F | grep -q "^declare -f $1$"
    if declare -F | grep -q "^declare -f $1$"; then
        echo 1
    else
        echo 0
    fi
}

function extract_functions() {
    cfg="$1"
    grep -e '^function .*() {' "$cfg" | sed 's/^function \(.*\)() {$/\1/g'
}

function load-functions() {
    local cfgs="$@"
    declare -A FUNCTIONS
    local LOADED=1     # function is currently loaded 
    local PREV=2       # function is in the previously loaded function list (DIRCFG_FUNCTIONS)
    local FILE=4       # function is present in the cfg file (.dircfg)
    local OVERWRITE=8  # this function was not loaded as it would have overwritten an existing function    

    debug <<< "load-functions args cfgs=[$cfgs] DIRCFG_FUNCTIONS=[$DIRCFG_FUNCTIONS]"
    
    # Function state is a combination of the LOADED + PREV + FILE bits
    #
    # F P L  DEC  ACTION
    # ------+---+--------------------------------------
    # 0 2 1 | 3 | function was loaded by a prev dircfg but is not longer needed, unload the function and remove it from the previously loaded function list
    # 4 0 0 | 4 | function is not loaded and needs to be loaded, source the current dircfg and add the function to the previously loaded function list
    # 4 0 1 | 5 | this is probably a name collision with a non-dircfg function, emit warning and cancel the load of the current dircfg
    # 4 2 1 | 7 | probably reloading the same dircfg, do nothing
    #
    # 0 0 0 | 0 | illegal - should never see this
    # 0 0 1 | 1 | illegal - should never see this
    # 0 2 0 | 2 | illegal - should never see this
    # 4 2 0 | 6 | illegal - should never see this    

    # check the previously loaded function list
    for f in $DIRCFG_FUNCTIONS; do
        FUNCTIONS["$f"]=$(($PREV | $(is_loaded "$f")))
        debug <<< "load-functions initialise $f ${FUNCTIONS[$f]}"
    done
    
    # go through each dircfg, if all functions in a dircfg are 4 then source the dircfg (load the functions)
    for cfg in $cfgs; do
        if [ -e "$cfg" ]; then
            debug <<< "load-functions parsing config $cfg"            
            local load_cfg='y'
            for f in $(extract_functions "$cfg"); do
                FUNCTIONS["$f"]=$(("${FUNCTIONS[$f]:-0}" | $FILE | $(is_loaded "$f")))
                debug <<< "load-functions configuring $f ${FUNCTIONS[$f]}"
                if [ "${FUNCTIONS[$f]}" == $(($FILE + $LOADED)) ]; then
                    FUNCTIONS["$f"]=$OVERWRITE
                    echo "WARN: function $f in $cfg not loaded as a function with than name already exists"
                fi
                if [ "${FUNCTIONS[$f]}" != $FILE ]; then load_cfg='n'; fi
            done
            if [ "$load_cfg" == 'y' ]; then
                debug <<< "load-functions sourcing $cfg"
                source "$cfg"
            fi
        else
            debug <<< "load-functions missing config $cfg"
        fi
    done
    
    # check the post-load function state, remove un-necessary functions and create the new previously loaded function list
    unset DIRCFG_FUNCTIONS
    for f in "${!FUNCTIONS[@]}"; do
        FUNCTIONS["$f"]=$(("${FUNCTIONS[$f]}" | $(is_loaded "$f")))
        debug <<< "load-functions finalizing $f ${FUNCTIONS[$f]}"
        case "${FUNCTIONS[$f]}" in
            [457])
                debug <<< "load-functions registering function $f"
                DIRCFG_FUNCTIONS="$DIRCFG_FUNCTIONS $f"
                ;;
            89)
                debug <<< "load-functions not registering function $f"
                ;;
            3)
                debug <<< "load-functions removing function $f"
                unset "$f"
                ;;
            *)
                debug <<< "load-functions function $f has an illegal state ${FUNCTIONS[$f]}"
        esac
    done
    unset FUNCTIONS
}

function on-command() {
    debug <<< "on-command DIRCFG_LASTDIR=$DIRCFG_LASTDIR PWD=$PWD"
    if [ "$DIRCFG_LASTDIR" != "$PWD" ]; then
        DIRCFG_LASTDIR="$PWD"
        cfgs=$(find-dirconfigs --reverse)
        debug <<< "on-command configs=[$cfgs]"
        initialise-history-file "$cfgs"
        load-functions "$cfgs"
    fi
    debug <<< '-------------------------------------------------'
}

function dircfg() {
    if [ "$#" -eq 0 ] || [ "$1" == '--help' ]; then
        echo 'Usage: dircfg [--help | <command> --help | <command> <args>]'
        echo 'Utilities for creating, managing and inspecting per-directory configs'
        echo ''
        echo 'Commands'
        echo '  list       : list all active dirconfigs and their history files and functions'
        echo '  create     : create an empty .dircfg file in the current directory'
        echo '  reload     : re-load all active dirconfigs'
        echo '  deactivate : deactivate the dirconfig in the current directory'
        return 0
    fi
    if [ "$1" == 'list' ]; then
        echo "HISTFILE=$ROOT_HISTFILE"
        find-dirconfigs | while read cfg; do
            if [ -e "$cfg" ]; then
                echo "$cfg"
                grep '^#HISTFILE=' "$cfg" | sed 's/^#/  /g'
                for f in $(extract_functions "$cfg"); do
                    echo "  $f"                
                done
            fi            
        done
    fi
}

export PROMPT_COMMAND="$PROMPT_COMMAND; on-command"

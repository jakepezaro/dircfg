if [ -z "$DIRCFG_ROOT_HISTFILE" ]; then
    DIRCFG_ROOT_HISTFILE=$(readlink -f ~/.bash_history)
fi

DIRCFG_FUNCTIONS=''
DIRCFG_LASTDIR=''

function debug() {
    if [ ! -z "$DIRCFG_DEBUG" ]; then
        while read -r msg; do
            echo "DEBUG: $msg" 1>&2
        done
    fi
}

function dircfg_find_configs() {
    local i=0
    declare -a cfgs
    local path=$(pwd)
    while [ "$path" != "/" ]; do
        if [ -f "$path/.dircfg" ]; then
            cfgs[$i]="$path/.dircfg"
            i=$(($i+1))
        fi
        path=$(dirname "$path")
    done
    # reverse the list so the root is first and current dir is last
    for ((j=i-1; j>=0; j--)); do
        echo "${cfgs[$j]}"
    done
}

function dircfg_find_active_history_file() {
    local last_history_file="$DIRCFG_ROOT_HISTFILE"
    while read cfg; do
        if [ -e "$cfg" ] && grep -q '^#HISTFILE=' "$cfg"; then
            last_history_file=$(grep '^#HISTFILE=' "$cfg" | cut -d '=' -f 2)
        fi
    done
    echo "$last_history_file"
}

function dircfg_initialise_history_file() {
    local cfgs="$@"
    local old_history="$HISTFILE"
    local new_history=$(echo "$cfgs" | dircfg_find_active_history_file)
    debug <<< "initialise_history_file old=$old_history new=$new_history cfgs=[$cfgs]"
    if [ "$old_history" != "$new_history" ]; then
        debug <<< "initialise_history_file HISTFILE $new_history"
        history -a
        export HISTFILE="$new_history"
        history -c
        history -r
    fi   
}

function dircfg_is_loaded() {
    #return declare -F | grep -q "^declare -f $1$"
    if declare -F | grep -q "^declare -f $1$"; then
        echo 1
    else
        echo 0
    fi
}

function dircfg_extract_functions() {
    cfg="$1"
    grep -e '^function .*() {' "$cfg" | sed 's/^function \(.*\)() {$/\1/g'
}

function dircfg_load_functions() {
    local cfgs="$@"
    declare -A FUNCTIONS
    local LOADED=1     # function is currently loaded 
    local PREV=2       # function is in the previously loaded function list (DIRCFG_FUNCTIONS)
    local FILE=4       # function is present in the cfg file (.dircfg)
    local OVERWRITE=8  # this function was not loaded as it would have overwritten an existing function    

    debug <<< "load_functions args cfgs=[$cfgs] DIRCFG_FUNCTIONS=[$DIRCFG_FUNCTIONS]"
    
    # Function state is a combination of the LOADED + PREV + FILE bits
    #
    # F P L  DEC  ACTION
    # ------+---+--------------------------------------
    # 0 2 0 | 2 | function was loaded previously but dircfg was inactivated or removed, unload the function and remove it from the prev loaded function list
    # 0 2 1 | 3 | function was loaded by a prev dircfg but is not longer needed, unload the function and remove it from the previously loaded function list
    # 4 0 0 | 4 | function is not loaded and needs to be loaded, source the current dircfg and add the function to the previously loaded function list
    # 4 0 1 | 5 | this is probably a name collision with a non-dircfg function, emit warning and cancel the load of the current dircfg
    # 4 2 1 | 7 | probably reloading the same dircfg, do nothing
    #
    # 0 0 0 | 0 | illegal - should never see this
    # 0 0 1 | 1 | illegal - should never see this
    # 4 2 0 | 6 | illegal - should never see this    

    # check the previously loaded function list
    for f in $DIRCFG_FUNCTIONS; do
        FUNCTIONS["$f"]=$(($PREV | $(dircfg_is_loaded "$f")))
        debug <<< "load_functions initialise '$f' ${FUNCTIONS[$f]}"
    done
    
    # go through each dircfg, if all functions in a dircfg are 4 then source the dircfg (load the functions)
    for cfg in $cfgs; do
        if [ -e "$cfg" ]; then
            debug <<< "load_functions parsing config $cfg"            
            local load_cfg='y'
            for f in $(dircfg_extract_functions "$cfg"); do
                FUNCTIONS["$f"]=$(("${FUNCTIONS[$f]:-0}" | $FILE | $(dircfg_is_loaded "$f")))
                debug <<< "load_functions configuring '$f' ${FUNCTIONS[$f]}"
                if [ "${FUNCTIONS[$f]}" == $(($FILE + $LOADED)) ]; then
                    FUNCTIONS["$f"]=$OVERWRITE
                    echo "WARN: function '$f' in $cfg not loaded as a function with than name already exists"
                fi
                if [ "${FUNCTIONS[$f]}" != $FILE ]; then load_cfg='n'; fi
            done
            if [ "$load_cfg" == 'y' ]; then
                debug <<< "load_functions sourcing $cfg"
                source "$cfg"
            fi
        else
            debug <<< "load_functions missing config $cfg"
        fi
    done
    
    # check the post-load function state, remove un-necessary functions and create the new previously loaded function list
    unset DIRCFG_FUNCTIONS
    for f in ${!FUNCTIONS[@]}; do
        FUNCTIONS["$f"]=$(("${FUNCTIONS[$f]}" | $(dircfg_is_loaded "$f")))
        debug <<< "load_functions finalizing '$f' ${FUNCTIONS[$f]}"
        case "${FUNCTIONS[$f]}" in
            [457])
                debug <<< "load_functions registering function '$f'"
                DIRCFG_FUNCTIONS=$(echo "$DIRCFG_FUNCTIONS $f" | sed 's/^ //g')
                ;;
            89)
                debug <<< "load_functions not registering function '$f'"
                ;;
            [32])
                debug <<< "load_functions removing function '$f'"
                unset "$f"
                ;;
            *)
                debug <<< "load_functions function '$f' has an illegal state ${FUNCTIONS[$f]}"
        esac
    done
    unset FUNCTIONS
}

function dircfg_on_command() {
    debug <<< "on_command LAST=$DIRCFG_LASTDIR PWD=$PWD"
    if [ "$DIRCFG_LASTDIR" != "$PWD" ]; then
        DIRCFG_LASTDIR="$PWD"
        local cfgs=$(dircfg_find_configs)
        debug <<< "on_command configs=[$cfgs]"
        dircfg_initialise_history_file "$cfgs"
        dircfg_load_functions "$cfgs"
    fi
    debug <<< '-------------------------------------------------'
}

function dircfg_help() {
    echo 'Usage: dircfg [--help | <command> --help | <command> <args>]'
    echo 'Utilities for creating, managing and inspecting per-directory configs'
    echo ''
    echo 'Commands'
    echo '  list       : list all active dirconfigs and their history files and functions'
    echo '  create     : create an empty .dircfg file in the current directory'
    echo '  reload     : re-load all active dirconfigs'
    echo '  deactivate : deactivate the dirconfig in the current directory'
    echo '  reactivate : reactivate the dirconfig in the current directory'
}

function dircfg_list() {
    echo "HISTFILE=$DIRCFG_ROOT_HISTFILE"
    dircfg_find_configs | while read cfg; do
        if [ -e "$cfg" ]; then
            echo "$cfg"
            grep '^#HISTFILE=' "$cfg" | sed 's/^#/  /g'
            for f in $(dircfg_extract_functions "$cfg"); do
                echo "  $f"                
            done
        fi            
    done    
}

function dircfg_force_reload() {
    unset DIRCFG_LASTDIR
}

function dircfg_deactivate() {
    if [ -e "$PWD/.dircfg-inactive" ]; then
        echo "WARN: config already inactivated $PWD/.dircfg-inactive"    
    elif [ ! -e "$PWD/.dircfg" ]; then
        echo "ERROR: no config present in $PWD, try 'dircfg list' instead"                
    else                
        mv "$PWD/.dircfg" "$PWD/.dircfg-inactive"
        dircfg_force_reload
    fi
}

function dircfg_create() {
    if [ -e "$PWD/.dircfg-inactive" ]; then
        echo "ERROR: found inactivated config $PWD/.dircfg-inactive, try 'dircfg reactivate' instead"            
    elif [ -e "$PWD/.dircfg" ]; then
        echo "WARN: config already exists $PWD/.dircfg"
    else
        local cfg="$PWD/.dircfg"
        local histfile="$PWD/.histfile"
        touch "$histfile"
        echo "#HISTFILE=$histfile" > "$cfg"
        echo "Created: $cfg with histfile: $histfile"
        dircfg_force_reload
    fi    
}

function dircfg_reactivate() {
    if [ -e "$PWD/.dircfg" ]; then
        echo "WARN: config is already active $PWD/.dircfg"
    elif [ ! -e "$PWD/.dircfg-inactive" ]; then
        echo "ERROR: no config present in $PWD, try 'dircfg create' instead"
    else
        mv "$PWD/.dircfg-inactive" "$PWD/.dircfg"
        dircfg_force_reload
        echo "Configuration $PWD/.dircfg reactivated"
    fi    
}

function dircfg() {
    if [ "$#" -eq 0 ]; then
        local arg='--help'
    else
        local arg=$1
    fi
    case $arg in
        '--help')
            dircfg_help
            ;;
        'list')
            dircfg_list
            ;;
        'create')
            dircfg_create
            ;;
        'reload')
            dircfg_force_reload
            ;;
        'deactivate')
            dircfg_deactivate
            ;;
        'reactivate')
            dircfg_reactivate
            ;;
    esac
}

export PROMPT_COMMAND=$(echo "$PROMPT_COMMAND; dircfg_on_command" | sed 's/^; //g')

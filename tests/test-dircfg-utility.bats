setup() {
    DIRCFG_DEBUG=1
    project_dir=$(dirname $(dirname "$BATS_TEST_FILENAME"))
    load "$project_dir/bats/bats-support/load.bash"
    load "$project_dir/bats/bats-assert/load.bash"
    load "$project_dir/bats/bats-file/load.bash"
    load "$project_dir/tests/test-tools.sh"
    temp=$(temp_make)
    cd "$temp" # make sure that there are no .dircfg files in the test parent directories
    load "$project_dir/dircfg-enable.sh"
}

@test 'dircfg --help' {
    help_string=$(multiline '
        |Usage: dircfg [--help | <command> --help | <command> <args>]
        |Utilities for creating, managing and inspecting per-directory configs
        |
        |Commands
        |  list       : list all active dirconfigs and their history files and functions
        |  create     : create an empty .dircfg file in the current directory
        |  reload     : re-load all active dirconfigs
        |  deactivate : deactivate the dirconfig in the current directory
        |  reactivate : reactivate the dirconfig in the current directory
    ')
    run dircfg
    assert_output "$help_string"
    run dircfg --help
    assert_output "$help_string"
}

@test 'dircfg list (no configs)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    dircfg_on_command
    run dircfg list
    assert_output $(multiline "
        |HISTFILE=$ROOT_HISTFILE
    ")
}

@test 'dircfg list (1 config)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    active_histfile=$(mkfile active_histfile <<< '')
    cfg=$(mkfile .dircfg <<< $(multiline "
        |#HISTFILE=$active_histfile
        |function test1() {
        |  echo test1
        |}
    "))
    dircfg_on_command
    run dircfg list
    expected=$(multiline "
        |HISTFILE=$ROOT_HISTFILE
        |$cfg
        |  HISTFILE=$active_histfile
        |  test1
    ")
    assert_output "$expected"
}

@test 'dircfg list (2 configs)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    parent_histfile=$(mkfile parent_histfile <<< '')
    cfg1=$(mkfile .dircfg <<< $(multiline "
        |#HISTFILE=$parent_histfile
        |function test1() {
        | echo test1
        |}
        |function test2() {
        | echo test2
        |}
    "))
    active_histfile=$(mkfile a/active_histfile <<< '')
    cfg2=$(mkfile a/.dircfg <<< $(multiline "
        |#HISTFILE=$active_histfile
        |function test3() {
        | echo test3
        |}
    "))
    cd "$temp/a"
    dircfg_on_command
    run dircfg list
    expected=$(multiline "
        |HISTFILE=$ROOT_HISTFILE
        |$cfg1
        |  HISTFILE=$parent_histfile
        |  test1
        |  test2
        |$cfg2
        |  HISTFILE=$active_histfile
        |  test3
    ")
    assert_output "$expected"
}

@test 'create in empty directory' {
    cd "$temp"
    unset HISTFILE
    DIRCFG_LASTDIR="$temp"
    PWD="$temp"
    dircfg create
    # assert_output "Created: $temp/.dircfg with histfile: $temp/.histfile"
    assert_file_exists "$temp/.dircfg"
    assert_file_exists "$temp/.histfile"
    dircfg_on_command
    assert_equal "$HISTFILE" "$temp/.histfile"
}

@test 'reload a new function' {
    #setup    
    ROOT_HISTFILE=$(mkfile .histfile <<< '')
    touch "$temp/.dircfg"    
    dircfg_on_command
    mkfile .dircfg <<< $(multiline "
        |function test1() {
        | echo test1
        |}
    ")

    # verify that function is not loaded
    dircfg_on_command
    run declare -F
    refute_output --partial 'declare -f test1'

    # execute reload
    dircfg reload

    # verify that function is now loaded
    dircfg_on_command
    run declare -F
    assert_output --partial 'declare -f test1'
}

@test 'deactivate config' {
    ROOT_HISTFILE=$(mkfile .root <<< '')
    hist=$(mkfile .hist <<< '')
    mkfile .dircfg <<< $(multiline "
        |#HISTFILE=$hist
        |function test1() {
        | echo test1
        |}
    ")
    dircfg_on_command
    run declare -F
    assert_output --partial 'declare -f test1'
    assert_equal "$HISTFILE" "$hist"

    dircfg deactivate
    dircfg_on_command
    run declare -F
    refute_output --partial 'declare -f test1'
    assert_equal "$HISTFILE" "$ROOT_HISTFILE"
    assert_file_exists "$temp/.dircfg-inactive"        
}

@test 'deactivate warns when dircfg already inactive' {
    mkfile .dircfg-inactive <<< ''
    run dircfg deactivate
    assert_output "WARN: config already inactivated $temp/.dircfg-inactive"
}

@test 'deactivate fails when dircfg does not exist' {
    run dircfg deactivate
    assert_output "ERROR: no config present in $temp, try 'dircfg list' instead"    
}

@test 'create fails when dircfg is inactive' {
    mkfile .dircfg-inactive <<< ''
    run dircfg create
    assert_output "ERROR: found inactivated config $temp/.dircfg-inactive, try 'dircfg reactivate' instead"
}

@test 'create warns when dircfg already exists' {
    mkfile .dircfg <<< ''
    run dircfg create
    assert_output "WARN: config already exists $temp/.dircfg"
}

@test 'reactive config' {
    ROOT_HISTFILE=$(mkfile .root <<< '')
    hist=$(mkfile .hist <<< '')
    mkfile .dircfg-inactive <<< $(multiline "
        |#HISTFILE=$hist
        |function test1() {
        | echo test1
        |}
    ")
    dircfg_on_command
    
    dircfg reactivate
    dircfg_on_command
    #assert_output "Configuration $temp/.dircfg reactivated"
    assert_equal "$HISTFILE" "$hist"
    run declare -F
    assert_output --partial 'declare -f test1'
}

@test 'reactivate warns if config already active' {
    mkfile .dircfg <<< ''
    run dircfg reactivate
    assert_output "WARN: config is already active $temp/.dircfg"    
}

@test 'reactivate fails when config does not exist' {
    run dircfg reactivate
    assert_output "ERROR: no config present in $temp, try 'dircfg create' instead"
}

teardown() {
    temp_del "$temp"    
}
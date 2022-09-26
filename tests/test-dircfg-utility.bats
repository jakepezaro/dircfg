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
    ')
    run dircfg
    assert_output "$help_string"
    run dircfg --help
    assert_output "$help_string"
}

@test 'dircfg list (no configs)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    on-command
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
    on-command
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
    on-command
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
    run dircfg create
    assert_output "Created: $temp/.dircfg"
    assert_file_exists "$temp/.dircfg"
}

teardown() {
    temp_del "$temp"    
}
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
        |dircfg - create, edit and examine per-directory configs
        |  --list:  list all directory configs that are active in your current directory
    ')
    run dircfg
    assert_output "$help_string"
    run dircfg --help
    assert_output "$help_string"
}

@test 'dircfg --list (no configs)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    on-command
    run dircfg --list
    assert_output $(multiline "
        |HISTFILE=$ROOT_HISTFILE
    ")
}

@test 'dircfg --list (1 config)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    active_histfile=$(mkfile active_histfile <<< '')
    mkfile .dircfg <<< "#HISTFILE=$active_histfile"
    on-command
    run dircfg --list
    expected=$(multiline "
        |HISTFILE=$ROOT_HISTFILE
        |HISTFILE=$active_histfile
    ")
    assert_output "$expected"
}

@test 'dircfg --list (2 configs)' {
    ROOT_HISTFILE=$(mkfile histfile <<< '')
    parent_histfile=$(mkfile parent_histfile <<< '')
    mkfile .dircfg <<< "#HISTFILE=$parent_histfile"
    active_histfile=$(mkfile a/active_histfile <<< '')
    mkfile a/.dircfg <<< "#HISTFILE=$active_histfile"
    cd "$temp/a"
    on-command
    run dircfg --list
    expected=$(multiline "
        |HISTFILE=$ROOT_HISTFILE
        |HISTFILE=$parent_histfile
        |HISTFILE=$active_histfile
    ")
    assert_output "$expected"
}

teardown() {
    temp_del "$temp"    
}
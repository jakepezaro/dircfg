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

@test "use default histfile when DIRCFG_ROOT_HISTFILE not set" {
    assert_equal "$(readlink -f ~/.bash_history)" "$DIRCFG_ROOT_HISTFILE"
}

@test "default histfile not used when DIRCFG_ROOT_HISTFILE is set" {
    unset DIRCFG_ROOT_HISTFILE
    DIRCFG_ROOT_HISTFILE=/some/file.txt
    assert_equal "/some/file.txt" "$DIRCFG_ROOT_HISTFILE"
}

@test "bash history changes when switching histfiles" {
    DIRCFG_ROOT_HISTFILE=$(mkfile history.txt <<< 'abc')
    history -c
    run history
    assert_output ""
    dircfg_on_command
    run history
    assert_output "    1  abc"
}

@test 'switching between directories' {
    mkfile a/.dircfg <<< "#HISTFILE=$(mkfile a/histfile <<< 'a')"
    mkfile a/b/.dircfg <<< "#HISTFILE=$(mkfile a/b/histfile <<< 'b')"
    mkfile a/c/.dircfg <<< "#HISTFILE=$(mkfile a/c/histfile <<< 'c')"
    history -c

    cd "$temp/a"
    dircfg_on_command
    run history
    assert_output "    1  a"
    
    cd "$temp/a/b"
    dircfg_on_command --debug
    run history
    assert_output "    1  b"
    
    cd "$temp/a/c"
    dircfg_on_command
    run history
    assert_output "    1  c"    
}

@test 'PROMPT_COMMAND does not overwrite' {
    unset PROMPT_COMMAND    
    PROMPT_COMMAND='echo hi'
    load "$project_dir/dircfg-enable.sh"
    assert_equal 'echo hi; dircfg_on_command' "$PROMPT_COMMAND"
    
}

teardown() {
    temp_del "$temp"    
}
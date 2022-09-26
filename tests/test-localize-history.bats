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

@test "use default histfile when ROOT_HISTFILE not set" {
    assert_equal "$(readlink -f ~/.bash_history)" "$ROOT_HISTFILE"
}

@test "default histfile not used when ROOT_HISTFILE is set" {
    unset ROOT_HISTFILE
    ROOT_HISTFILE=/some/file.txt
    assert_equal "/some/file.txt" "$ROOT_HISTFILE"
}

@test "bash history changes when switching histfiles" {
    ROOT_HISTFILE=$(mkfile history.txt <<< 'abc')
    history -c
    run history
    assert_output ""
    on-command
    run history
    assert_output "    1  abc"
}

@test 'switching between directories' {
    mkfile a/.dircfg <<< "#HISTFILE=$(mkfile a/histfile <<< 'a')"
    mkfile a/b/.dircfg <<< "#HISTFILE=$(mkfile a/b/histfile <<< 'b')"
    mkfile a/c/.dircfg <<< "#HISTFILE=$(mkfile a/c/histfile <<< 'c')"
    history -c

    cd "$temp/a"
    on-command
    run history
    assert_output "    1  a"
    
    cd "$temp/a/b"
    on-command --debug
    run history
    assert_output "    1  b"
    
    cd "$temp/a/c"
    on-command
    run history
    assert_output "    1  c"    
}

@test 'PROMPT_COMMAND does not overwrite' {
    unset PROMPT_COMMAND    
    PROMPT_COMMAND='echo hi'
    load "$project_dir/dircfg-enable.sh"
    assert_equal 'echo hi; on-command' "$PROMPT_COMMAND"
    
}

teardown() {
    temp_del "$temp"    
}
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

@test 'load functions when entering directory' {
    mkfile .dircfg <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
        |function test2() {
        |    echo test2
        |}        
    ')
    run declare -F
    refute_output --partial 'declare -f test1'
    refute_output --partial 'declare -f test2'
    cd "$temp"
    dircfg_on_command
    run declare -F
    assert_output --partial 'declare -f test1'
    assert_output --partial 'declare -f test2'
    assert_equal "$DIRCFG_FUNCTIONS" "test2 test1"
}

@test 'remove functions when leaving directory' {
    mkfile a/.dircfg <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
        |function test2() {
        |    echo test2
        |}      
    ')
    mkfile b/.dircfg <<< ''
    cd "$temp/a"
    dircfg_on_command
    cd "$temp/b"
    dircfg_on_command    
    run declare -F
    refute_output --partial 'declare -f test1'
    refute_output --partial 'declare -f test2'
    assert_equal "$DIRCFG_FUNCTIONS" ""
}

@test 'functions cannot be overwritten' {
    mkfile test1.sh <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
    ')
    cfg=$(mkfile a/.dircfg <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
    '))
    load "$temp/test1.sh"
    cd "$temp/a"
    unset DIRCFG_DEBUG
    run dircfg_on_command
    assert_output "WARN: function 'test1' in $cfg not loaded as a function with than name already exists"
    # cannot check DIRCFG_FUNCTIONS because run executes dircfg_on_command in a subshell and env var changes are not visible in this shell
}


@test 'functions that cannot be overwritten do not go on the prev functions list' {
    mkfile test1.sh <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
    ')
    cfg=$(mkfile a/.dircfg <<< $(multiline '
        |function test1() {
        |    echo test1
        |}
    '))
    load "$temp/test1.sh"
    cd "$temp/a"
    unset DIRCFG_DEBUG
    dircfg_on_command
    assert_equal "$DIRCFG_FUNCTIONS" ""
}

teardown() {
    temp_del "$temp"    
}

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
    on-command
    run declare -F
    assert_output --partial 'declare -f test1'
    assert_output --partial 'declare -f test2'
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
    on-command
    cd "$temp/b"
    on-command    
    run declare -F
    refute_output --partial 'declare -f test1'
    refute_output --partial 'declare -f test2'
}


teardown() {
    temp_del "$temp"    
}

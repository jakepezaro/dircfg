setup() {
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
    mkfile .dircfg << EOF
    function test1() {
        echo test1
    }
EOF
    cd "$temp"
    on-command
    run declare -F
}    

teardown() {
    temp_del "$temp"    
}

setup() {
    project_dir=$(dirname $(dirname "$BATS_TEST_FILENAME"))
    load "$project_dir/bats/bats-support/load.bash"
    load "$project_dir/bats/bats-assert/load.bash"
    load "$project_dir/bats/bats-file/load.bash"
    temp=$(temp_make)
    cd "$temp" # make sure that there are no .dircfg files in the test parent directories
}

function mkfile() {
    file="$temp/$1"
    mkdir -p "$(dirname $file)"
    rm -f "$file"
    while read -r line; do
        echo "$line" >> "$file"
    done
    echo $file
}

@test "use default histfile when ROOT_HISTFILE not set" {
    load "$project_dir/dircfg-enable.sh"
    assert_equal "$(readlink -f ~/.bash_history)" "$ROOT_HISTFILE"
}

@test "default histfile not used when ROOT_HISTFILE is set" {
    ROOT_HISTFILE=/some/file.txt
    load "$project_dir/dircfg-enable.sh"
    assert_equal "/some/file.txt" "$ROOT_HISTFILE"
}

@test "bash history changes when switching histfiles" {
    ROOT_HISTFILE="$temp/history.txt"
    echo 'abc' > $ROOT_HISTFILE
    echo 'de f' >> $ROOT_HISTFILE
    history -c
    run history
    assert_output ""
    load "$project_dir/dircfg-enable.sh"
    on-command
    run history
    assert_output "    1  abc
    2  de f"
}

@test 'test switching between directories' {
    mkfile a/.dircfg <<< "#HISTFILE=$(mkfile a/histfile <<< 'a')"
    mkfile a/b/.dircfg <<< "#HISTFILE=$(mkfile a/b/histfile <<< 'b')"
    mkfile a/c/.dircfg <<< "#HISTFILE=$(mkfile a/c/histfile <<< 'c')"
    history -c
    load "$project_dir/dircfg-enable.sh"

    cd "$temp/a"
    on-command
    run history
    assert_output "    1  a"
    
    cd "$temp/a/b"
    on-command
    run history
    assert_output "    1  b"
    
    cd "$temp/a/c"
    on-command
    run history
    assert_output "    1  c"    
}

teardown() {
    temp_del "$temp"    
}
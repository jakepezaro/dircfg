function mkfile() {
    file="$temp/$1"
    mkdir -p "$(dirname $file)"
    rm -f "$file"
    while read -r line; do
        echo "$line" >> "$file"
    done
    echo $file
}

function multiline() {
    echo "$*" | grep -e '^[ ]*|' | sed 's/^[ ]*|//g'
}
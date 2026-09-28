#!/bin/bash
dir="${1:-$HOME/exam1}"
echo "Auditing: $dir"
results=$(find "$dir" -type f -perm -o=w)
counts=$(find "$dir" -type f -perm -o=w | wc -l)
if [ "$counts" -eq 0 ]; then
    echo "Clean"
else
    echo "Found $counts world-writable file(s):"
    echo "$results"
fi
echo "Done at $(date)"

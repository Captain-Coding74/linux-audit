#!/bin/bash
dir="${1:-$HOME/exam1}"
passwd_file="${3:-/etc/passwd}"
cron_paths="${2:-/etc/crontab /etc/cron.d}"
echo "Auditing: $dir"
results=$(find "$dir" -type f -perm -o=w)
counts=$(find "$dir" -type f -perm -o=w | wc -l)
root_owned_writable=$(find "$dir" -type f -user root -perm -o=w)
count_root_writable=$(find "$dir" -type f -user root -perm -o=w | wc -l)
# shellcheck disable=SC2086
cron_results_reboot=$(sudo grep -rn '@reboot' $cron_paths 2> /dev/null)
# shellcheck disable=SC2086
cron_results_reboot_count=$(sudo grep -rn '@reboot' $cron_paths 2> /dev/null | wc -l)
uid0_users=$(cut -d: -f1,3 "$passwd_file" | grep ':0$' | grep -v "^root:")
uid0_counts=$(cut -d: -f1,3 "$passwd_file" | grep ':0$' | grep -v "^root:" | wc -l)
if [ "$counts" -eq 0 ]; then
    echo "Clean"
else
    echo "Found $counts world-writable file(s):"
    echo "$results"
fi
if [ "$count_root_writable" -eq 0 ]; then
    echo "Clean"
else
    echo "Found $count_root_writable root-owned scripts others can write file(s):"
    echo "$root_owned_writable"
fi
if [ "$cron_results_reboot_count" -eq 0 ]; then
    echo "No @reboot existed"
else
    echo "Found $cron_results_reboot_count @reboot logs:"
    echo "$cron_results_reboot"
fi
if [ "$uid0_counts" -eq 0 ]; then
    echo "No UID 0 others than root"
else
    echo "Found $uid0_counts backdoor account:"
    echo "$uid0_users"
fi
echo "Done at $(date)"

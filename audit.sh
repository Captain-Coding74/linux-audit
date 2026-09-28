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
uid0_counts=$(cut -d: -f1,3 "$passwd_file" | grep ':0$' | grep -vc "^root:")
if [ "$counts" -eq 0 ]; then
    echo "World-writable files: Clean"
else
    echo "Wold-writable files: $counts found"
    echo "$results"
fi
if [ "$count_root_writable" -eq 0 ]; then
    echo "Root-owned files writable by others: Clean"
else
    echo "Root-owned files writable by others: $count_root_writable found"
    echo "$root_owned_writable"
fi
if [ "$cron_results_reboot_count" -eq 0 ]; then
    echo "@reboot cron entries: none"
else
    echo "@reboot cron entries: $cron_results_reboot_count"
    echo "$cron_results_reboot"
fi
if [ "$uid0_counts" -eq 0 ]; then
    echo "Extra UID 0 accounts: none"
else
    echo "Extra UID 0 accounts: $uid0_counts"
    echo "$uid0_users"
fi
echo "Done at $(date)"

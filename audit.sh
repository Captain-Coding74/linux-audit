#!/bin/bash
dir="${1:-$HOME/exam1}"
echo "Auditing: $dir"
results=$(find "$dir" -type f -perm -o=w)
counts=$(find "$dir" -type f -perm -o=w | wc -l)
root_owned_writable=$(find "$dir" -type f -user root -perm -o=w)
count_root_writable=$(find "$dir" -type f -user root -perm -o=w | wc -l)
cron_results_reboot=$(sudo grep -rn '@reboot' /etc/crontab /etc/cron.d 2> /dev/null)
cron_results_reboot_count=$(sudo grep -rn '@reboot' /etc/crontab /etc/cron.d 2> /dev/null | wc -l)
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
echo "Done at $(date)"

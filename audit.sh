#!/bin/bash
dir="${1:-$HOME/exam1}"
passwd_file="${3:-/etc/passwd}"
cron_paths="${2:-/etc/crontab /etc/cron.d}"
suid_paths="${4:-/usr}"
suid_baseline="${5:-$HOME/linux-audit/suid-baseline.txt}"
cap_paths="${6:-/usr}"
cap_baseline="${7:-$HOME/linux-audit/capabilities_baseline.txt}"
group_file="${8:-/etc/group}"
sudoers_paths="${9:-/etc/sudoers /etc/sudoers.d}"
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
# shellcheck disable=SC2086
comm_suid=$(comm -13 "$suid_baseline" <(find $suid_paths -type f -perm -4000 2> /dev/null | sort))
# shellcheck disable=SC2086
comm_suid_count=$(comm -13 "$suid_baseline" <(find $suid_paths -type f -perm -4000 2> /dev/null | sort) | wc -l)
# shellcheck disable=SC2086
comm_cap=$(comm -13 "$cap_baseline" <(getcap -r $cap_paths 2> /dev/null | sort))
# shellcheck disable=SC2086
comm_cap_count=$(comm -13 "$cap_baseline" <(getcap -r $cap_paths 2> /dev/null | sort) | wc -l)
sudo_members=$(grep "^sudo:" "$group_file" | cut -d: -f4)
sudo_member_count=$(grep "^sudo:" "$group_file" | cut -d: -f4 | tr ',' '\n' | grep -c .)
# shellcheck disable=SC2086
sudoers_nopasswd=$(sudo grep -rn "^[^#]*NOPASSWD" $sudoers_paths 2> /dev/null)
# shellcheck disable=SC2086
nopasswd_count=$(sudo grep -rn "^[^#]*NOPASSWD" $sudoers_paths 2> /dev/null | wc -l)
tmp_procs=$(for p in /proc/[0-9]*; do
    echo "$p $(sudo readlink "$p/exe")"
done | grep -E ' (/tmp|/var/tmp|/dev/shm)')

if [ "$counts" -eq 0 ]; then
    echo "World-writable files: Clean"
else
    echo "World-writable files: $counts found"
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
if [ "$comm_suid_count" -eq 0 ]; then
    echo "Extra suid: none"
else
    echo "Extra suid: $comm_suid_count"
    echo "$comm_suid"
fi
if [ "$comm_cap_count" -eq 0 ]; then
    echo "Extra capabilities: none"
else
    echo "Extra capabilities: $comm_cap_count"
    echo "$comm_cap"
fi
if [ "$sudo_member_count" -eq 0 ]; then
    echo "Sudo group members: none"
else
    echo "Sudo group members: $sudo_member_count"
    echo "$sudo_members"
fi
if [ "$nopasswd_count" -eq 0 ]; then
    echo "nopasswd: none"
else
    echo "nopasswd: $nopasswd_count"
    echo "$sudoers_nopasswd"
fi
if [ -z "$tmp_procs" ]; then
    echo "Processes running from writable folders: none"
else
    echo "Processes running from writable folders: "
    echo "$tmp_procs"
fi
echo "Done at $(date)"

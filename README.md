# linux-audit

A small Bash tool that audits a Linux system for common privilege escalation and persistence tricks.

Usage: 
```bash
./audit.sh [folder] [cron paths] [passwd file] [suid paths] [baseline file] [capabilities paths] [cap_baseline file] [group file] [sudoers paths]
```

## Checks

### 1. World-writable files
**What:** Files inside the target folder that any user can edit.
**Why it matters:**  If a config or script is world-writable, any user on the system can edit it. For example, they could add their own commands.
**How:** `find "$dir" -type f -perm -o=w`

### 2. Root-owned files writable by others
**What:** Files owned by root that any user can edit.
**Why it matters:** Root often runs these files automatically, for example from cron. If a normal user adds a command to one, that command runs **as root**. This is privilege escalation.
**How:** `find "$dir" -type f -user root -perm -o=w`

### 3. `@reboot` cron entries
**What:** Cron jobs that run automatically every time the system starts.
**Why it matters:** Attackers use `@reboot` for persistence. Their code runs again after every restart, and can bring back access even after the admin removes it.
**How:** `sudo grep -rn '@reboot' $cron_paths 2> /dev/null`

### 4. Extra UID 0 accounts
**What:** Any account other than root that has UID 0. UID 0 is root, the user with full power over the system.
**Why it matters:** Linux grants full power based on the UID number, not the name. An account like `sysupdate` with UID 0 **is** root, and gives an attacker a hidden way back in.
**How:** `cut -d: -f1,3 "$passwd_file" | grep ':0$' | grep -v "^root:"`

### 5. Extra SUID
**What:** SUID is a special permission that lets users run a file with the permissions of the file's owner.
**Why it matters:** If a SUID-root program lets you do more than its one job, like editing files or running other commands, a normal user just got root. 
**How:** `comm -13 "$suid_baseline" <(find $suid_paths -type f -perm -4000 | sort)`

### 6. Extra capabilities
**What:** Capabilities break root's power into small pieces that can be given to individual programs. This check finds files whose capabilities aren't in the baseline, including new capabilities added to existing files.
**Why it matters:** An attacker who gets root once can give a file a powerful capability like `cap_setuid`. Even after the admin removes their access, the attacker can run that file as a normal user and become root again. This is called persistence. 
**How:** `comm -13 "$cap_baseline" <(getcap -r $cap_paths 2> /dev/null | sort)`

### 7. Sudo group members and NOPASSWD rules
**What:** The sudo group is a group whose members can run commands with sudo. This check lists every member of the sudo group. NOPASSWD lets a user run sudo with no password prompt. This check searches `/etc/sudoers` and `/etc/sudoers.d` for NOPASSWD rules, ignoring commented lines.
**Why it matters:** An attacker who gets root once can add their account to the sudo group, or give it a NOPASSWD rule, which lets it run sudo with no password prompt. Later, even after the admin removes their access, they can log in as that normal account and become root again. This is called persistence.
**How:**
- Sudo members: `grep "^sudo:" "$group_file" | cut -d: -f4`
- NOPASSWD rules: `sudo grep -rn "^[^#]*NOPASSWD" $sudoers_paths 2> /dev/null`

**Note:** Sudo group members are listed for review, not as proof of an attack.

### 8. Processes running from writable folders
**What:** Running processes whose program file is stored in a folder that is writable by non-root users, like `/tmp`, `/var/tmp` or `/dev/shm`. The check reads each process's `exe` link in `/proc` to find where its program really lives.
**Why it matters:** Attackers often drop their programs in `/tmp`, `/var/tmp` or `/dev/shm` because anyone can write to them, even without root. Real system programs live in folders like `/usr/bin` or `/usr/sbin`. Attackers can give a program a harmless-looking name like `kworker`, but they can't hide the program's real path, which the `exe` link in `/proc` reveals. So a process running from a writable folder is a strong warning sign.
**How:** 
```bash
tmp_procs=$(for p in /proc/[0-9]*; do
    echo "$p $(sudo readlink "$p/exe")"
done | grep -E ' (/tmp|/var/tmp|/dev/shm)')
```

## Baseline setup
Run it inside linux-audit, on a system you trust is clean
```bash
cd ~/linux-audit
find /usr -type f -perm -4000 2>/dev/null | sort > suid-baseline.txt
getcap -r /usr 2> /dev/null | sort > capabilities_baseline.txt
```

## Testing
```bash
chmod 666 ~/exam1/tmp/upload.php
printf 'root:x:0:0:root:/root:/bin/bash\nsysupdate:x:0:0::/home/sysupdate:/bin/bash\n' > ~/fake-passwd
mkdir -p ~/cron-test && echo "@reboot /tmp/.update.sh" > ~/cron-test/fake-job
mkdir -p ~/suid-test
echo 'echo hi' > ~/suid-test/fake-tool
chmod 4755 ~/suid-test/fake-tool
mkdir -p ~/fake-ping
echo 'echo hi' >  ~/fake-ping/fake-tools
sudo setcap cap_net_raw+ep ~/fake-ping/fake-tools
echo "sudo:x:27:user,hacker" > ~/fake_group
mkdir -p ~/sudoers-test
printf "hacker ALL=(ALL) NOPASSWD: ALL \n# user ALL=(ALL) NOPASSWD: ALL \n %%sudo ALL=(ALL:ALL) ALL\n" > ~/sudoers-test/fake-rule
cp /usr/bin/bash /tmp/fake-bash
/tmp/fake-bash -c 'sleep 3600; true' &
./audit.sh ~/exam1 ~/cron-test ~/fake-passwd "/usr $HOME/suid-test" "" "/usr $HOME/fake-ping" "" "$HOME/fake_group" "$HOME/sudoers-test"
```
**Cleanup note:** Don't forget to stop the fake and its sleep child, then delete `/tmp/fake-bash`. Otherwise every future `./audit.sh` would flag it.

## Roadmap
- [x] SUID binaries check
- [ ] Named options (`--passwd`, `--cron`) instead of positional arguments
- [x] Users in the `sudo` group
- [x] Capabilities check
- [x] Check for processes running from writable folders

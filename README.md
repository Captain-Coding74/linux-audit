# linux-audit

A small Bash tool that audits a Linux system for common privilege escalation and persistence tricks.

Usage: 
```bash
./audit.sh [folder] [cron paths] [passwd file] [suid paths] [baseline file]
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

## Baseline setup
Run it inside linux-audit, on a system you trust is clean
```bash
cd ~/linux-audit
find /usr -type f -perm -4000 2>/dev/null | sort > suid-baseline.txt
```

## Testing
```bash
chmod 666 ~/exam1/tmp/upload.php
printf 'root:x:0:0:root:/root:/bin/bash\nsysupdate:x:0:0::/home/sysupdate:/bin/bash\n' > ~/fake-passwd
mkdir -p ~/cron-test && echo "@reboot /tmp/.update.sh" > ~/cron-test/fake-job
mkdir -p ~/suid-test
echo 'echo hi' > ~/suid-test/fake-tool
chmod 4755 ~/suid-test/fake-tool
./audit.sh ~/exam1 ~/cron-test ~/fake-passwd "/usr $HOME/suid-test"

```

## Roadmap
- [x] SUID binaries check
- [ ] Named options (`--passwd`, `--cron`) instead of positional arguments
- [ ] Users in the `sudo` group

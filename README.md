# linux-audit

A small Bash tool that audits a Linux system for common privilege escalation and persistence tricks.

Usage: 
```bash
./audit.sh [folder] [cron paths] [passwd file]
```

## Checks

### World-writable files
**What: ** Files inside the target folder that any user can edit.
**Why it matters: ***  If a config or script is a world writable, any user on the system can edit it, for example They could add their own commands.
**How: ** `find "$dir" -type f -perm -o=w`

### 2.root-owned files writable by others
**What: ** Files own by root that any user can edit it.
**Why it matters: ** Root often runs these files automatically, for example from cron. If a normal user adds a command to one, that command runs **as root**. This is privilege escalation.
**How: ** `find "$dir" -type f -user root -perm -o=w`

### 3.`@reboot` cron entries
**What: ** @reboot cron entries means automate every startup.
**Why it matters: ** Attackers use `@reboot` for persistence. Their code runs again after every restart, and can bring back access even after the admin removes it.
**How: ** `sudo grep -rn '@reboot' $cron_paths 2> /dev/null`

### 4. Extra UID 0 accounts
**What: ** UID 0 is the user that owned root and can use sudo commands.
**Why it matters: ** Linux grants full power based on the UID number, not the name. An account like `sysupdate` with UID 0 **is** root, and gives an attacker a hidden way back in.
**How: ** `cut -d: -f1,3 "$passwd_file" | grep ':0$' | grep -v "^root:"`

## Testing
```bash
chmod 666 ~/exam1/tmp/upload.php
printf 'root:x:0:0:root:/root:/bin/bash\nsysupdate:x:0:0::/home/sysupdate:/bin/bash\n' > ~/fake-passwd
mkdir -p ~/cron-test && echo "@reboot /tmp/.update.sh" > ~/cron-test/fake-job
./audit.sh ~/exam1 ~/cron-test ~/fake-passwd
```

## Roadmap
- [ ] SUID binaries check
- [ ] Named options (`--passwd`, `--cron`) instead of positional arguments
- [ ] Users in the `sudo` group

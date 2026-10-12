# TODO

Pre-existing `script-lint` violations found while linting an unrelated
diff (2026-09-04, casjay-base/rhel AUDIT.AI.md #25 companion commit).
None of these are in code touched by that commit — logged here rather
than fixed inline to keep that commit's diff scoped to its actual change.

## scripts/min.sh

- [ ] Rename internal functions to the required `__` prefix: `devnull`,
      `port_in_use`, `system_service_exists`, `system_service_active`,
      `system_service_enable`, `system_service_disable`, `does_user_exist`,
      `does_group_exist`, `test_pkg`, `remove_pkg`, `install_pkg`,
      `detect_selinux`, `disable_selinux`, `get_user_ssh_key`,
      `run_init_check` (rename definition + every call site for each)
- [ ] Add `--` before the grep query at lines 526, 548, 890
- [ ] Split lines exceeding 180 chars: 187, 259, 702, 986, 1306, 1307
- [ ] Bare `return` with no code at line 448 — use `return 0`/`1`/`"$?"`
- [ ] Bare `exit` with no code at line 1706 — use `exit 0`/`1`/`"$?"`

## scripts/server.sh

- [ ] Rename internal functions to the required `__` prefix: `port_in_use`,
      `system_service_exists`, `system_service_active`,
      `system_service_enable`, `system_service_disable`, `does_user_exist`,
      `does_group_exist`, `test_pkg`, `remove_pkg`, `install_pkg`,
      `detect_selinux`, `disable_selinux`, `get_user_ssh_key`,
      `run_init_check`, `grab_remote_file` (rename definition + every call
      site for each)
- [ ] Add `--` before the grep query at lines 54, 81 (x2), 88, 135, 304,
      399, 400, 455, 474, 903
- [ ] Split lines exceeding 180 chars: 142, 208, 574, 848, 907, 908, 919,
      992, 1127, 1128
- [ ] Bare `return` with no code at line 384 — use `return 0`/`1`/`"$?"`
- [ ] Bare `exit` with no code at line 1468 — use `exit 0`/`1`/`"$?"`

## Pre-existing `script-lint` violations found 2026-09-09 (fail2ban
jail.local conditional-enable companion commit)

Broader `grep` missing-`--` sweep found by the same script-lint agent;
supersedes the narrower line lists above for this category (the two new
occurrences this commit introduced were fixed inline, not logged here).

- [ ] scripts/min.sh: add `--` before the grep query at lines 155, 161,
      228, 230–236, 329, 367, 474–490 (and other matches — re-run
      `script-lint` for the full current list before fixing)
- [ ] scripts/server.sh: add `--` before the grep query at lines 98, 104,
      144, 155–167, 181, 183–189, 193, 240 (and other matches — re-run
      `script-lint` for the full current list before fixing)

## Pre-existing `script-lint` violations found 2026-09-13 (centos->rhel
RELEASE_TYPE semantic-tag rename companion commit — none on lines that
commit touched)

- [ ] pkmgr-sync.sh: UUOC quote spacing, grep missing `--`, internal
      functions not using the required `__` prefix, bare `exit` codes
      (re-run `script-lint` for exact line numbers before fixing)
- [ ] scripts/template: add `--` before the grep query (4 occurrences),
      UUOC grepping for non-empty result instead of a direct test, inline
      comments that must move above the line, bare `return` with no code
      (re-run `script-lint` for exact line numbers before fixing; the `__`
      prefix naming rule's hook-name exception applies here)

## Correctness findings from the 2026-10-12 review of scripts/min.sh
(logged during the config-rsync / SYSTEM_TYPE commit — none of these were on
lines that commit touched, so none were fixed inline). Line numbers are as of
b258f8b; re-verify before starting any item. scripts/server.sh was not
reviewed at the same depth and likely shares several of these.

- [ ] `__install_pkg` (460) reports failure for a successful install:
      `__test_pkg` returns 1 when the package IS present, so the trailing
      `__test_pkg "$*" && statusCode=1 || statusCode=0` inverts the result
- [ ] `__dnf_yum` (436) ends with `rpm -q "$pkg"`, so it returns that
      check's status instead of the package manager's; `$pkg` is not local
      and is normally unset — the PHP install block sets a global `pkg=php`
      to work around this, which is the bug, not the fix
- [ ] `[ -z "$IS_INSTALLED_HTTPD" ] || [ -z "$IS_INSTALLED_NGINX" ]` (1659)
      uses OR, so a host with only httpd installed still gets
      `gen-nginx php $HOSTNAME` run — probably wants AND
- [ ] `__detect_selinux` (472) fallback is inverted: `selinuxenabled` exits 0
      when enabled, yet that branch returns 1, which `__disable_selinux`
      reads as "already disabled"; `SELINUX=permissive` is likewise treated
      as disabled
- [ ] `PKMGR_INSTALL_HTTPD` / `PKMGR_INSTALL_NGINX` are compared only
      against the exact lowercase string `no` (1078, 1166) — `NO` or `0`
      still install; normalize the case before comparing
- [ ] ntpd stays in the base `SERVICES_ENABLE` (344) while chrony is
      appended for every non-dns host (1157); both bind 123, so one fails to
      start in the enable/restart loop
- [ ] `PKMGR_INSTALL_*` compare against `no` is also reused for the web
      files block (1166) where OR-ing the two vars means the block runs when
      only one stack is installed — confirm intent

## Safety and ergonomics findings from the 2026-10-12 review

- [ ] `--help` (355) is parsed after the `yum update` + reboot block (48-50),
      the hostname prompt (172), the root-password prompt (191), swap
      creation and the casjay-scripts clone — `min.sh --help` can reboot the
      host first. `${GREEN}`/`${NC}` used by that line are never defined
- [ ] No root check despite the `@@sudo/root : yes` header, and both prompts
      are unconditional `read -r -t 30`, so unattended (cloud-init/ssh/cron)
      runs either block or silently take defaults — add an `[ "$(id -u)" ]`
      gate and a non-interactive switch
- [ ] `__get_user_ssh_key` (502) checks `$HOME/.ssh/authorized_keys` (512)
      but writes `/root/.ssh/authorized_keys` (515): `$HOME` is
      `${USER_HOME:-${HOME}}`, so the check and the write target differ, and
      the /root target directory is never created
- [ ] `PKMGR_SETUP_ACCOUNT_ADMIN` defaults to `administrator:random` (316,
      1901): every run creates a wheel admin with a random password unless
      opted out, resets an existing `administrator` password, prints the
      credential to stdout, and writes `/etc/sudoers.d/$user` with no
      `visudo -c`
- [ ] Destructive or surprising side effects: `chattr +i /etc/resolv.conf`
      (1339) permanently blocks NetworkManager and cloud-init; `chmod 777
      /var/log/munin` (1618); `tee /etc/subuid /etc/subgid` (1406) clobbers
      existing container subuid/subgid mappings; `find /etc /usr /var
      -iname '*.rpmnew' -exec rm -Rf` deletes pending merge candidates; the
      fstab blank line and NFS entries are appended on every run
- [ ] `curl … default-web-assets/raw/main/setup.sh | sudo bash` (1185)
      executes remote code as root with no checksum or pinned ref
- [ ] `##@Version` / `VERSION=` are still `202609131048-git` (3, 30) while
      version.txt is stamped by gitcommit on every commit — the in-script
      stamp never advances; decide whether min.sh should be stamped too

#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202609131048-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  min.sh --help
# @@Copyright        :  Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, Nov 07, 2022 12:39 EST
# @@File             :  min.sh
# @@Description      :  Script to setup min for CentOS/AlmaLinux/RockyLinux
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  yes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC2016
# shellcheck disable=SC2031
# shellcheck disable=SC2120
# shellcheck disable=SC2155
# shellcheck disable=SC2199
# shellcheck disable=SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="min"
VERSION="202609131048-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
CONFIG_TEMP_DIR="${TMPDIR:-/tmp}/minConfigFiles"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [ "$1" = "--debug" ]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -d "/etc/casjaysdev" ]; then
  if yum makecache && yum update -yy; then
    echo "Rebooting your system: Please rerun this script after reboot"
    mkdir -p "/etc/casjaysdev"
    sleep 20 && reboot
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -z "$(type -P ifconfig)" ] && [ -z "$(type -P hostname)" ]; then
  echo "Installing net-tools package"
  yum install -yy net-tools -q
fi
for pkg in sudo git curl wget; do
  command -v $pkg &>/dev/null || { echo "Installing $pkg" && yum install -yy -q $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
read -t 30 -p "Enter your full hostname: (default: $HOSTNAME) " set_hostname
set_hostname="${set_hostname:-$(hostname -f | grep -- '^' || echo "$HOSTNAME")}"
if [ -n "$set_hostname" ]; then
  hostnamectl set-hostname $set_hostname && echo "$set_hostname" >/etc/hostname || false
  [ $? -eq 0 ] && [ -n "$(type -P hostname)" ] && hostname -F /etc/hostname
  MY_HOST_NAME="$set_hostname"
  unset set_hostname
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -n "$(type systemd-ask-password)" ]; then
  root_pass_1="$(systemd-ask-password --emoji=no --echo=masked --timeout=30 "Enter your root password: ")"
  root_pass_2="$(systemd-ask-password --emoji=no --echo=masked --timeout=30 "Confirm your root password: ")"
else
  stty -echo
  printf "Enter your root password: " && read -t 30 -s root_pass_1
  printf '\n'
  printf "Confirm your root password: " && read -t 30 -s root_pass_2
  printf '\n'
  stty echo
fi
if [ -n "$root_pass_1" ]; then
  if [ "$root_pass_1" = "$root_pass_2" ]; then
    echo "$root_pass_1" | passwd --stdin root >/dev/null
  fi
fi
unset root_pass_1 root_pass_2
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$(ls -A /var/cache/swaps 2>/dev/null | wc -l)" -eq 0 ]; then
  SWAP_SIZE="$(swapon --show=SIZE --noheadings | sed 's/[0-9]//g' | head -n1 | grep -- 'M' || swapon --show=SIZE --noheadings | sed 's/[0-9]//g' | head -n1 | grep -- 'G' || false)"
  if [ "$SWAP_SIZE" != "G" ]; then
    swap_file_size="4096"
    swap_file="swapFile"
    swap_dir="/var/cache/swaps"
    kilobit="2000000"
    gigabit=$((kilobit / 1000))
    mem="$(free | grep -- ':' | awk '{print $2}' | head -n1 | grep -- '^' || echo "1")"
    if [ $mem -le $kilobit ] && [ ! -f "$swap_dir/$swap_file" ]; then
      echo "Setting up swap in $swap_dir/$swap_file"
      echo "This may take a few minutes so enjoy your coffee"
      mkdir -p "$swap_dir"
      if dd if=/dev/zero of=$swap_dir/$swap_file bs=1MB count=$swap_file_size &>/dev/null; then
        echo "swap size is: ${swap_file_size}MB"
        chmod 600 $swap_dir/$swap_file
        mkswap $swap_dir/$swap_file >/dev/null
        swapon $swap_dir/$swap_file >/dev/null
        if ! grep -qs -- "$swap_dir/$swap_file" /etc/fstab; then
          echo "$swap_dir/$swap_file          swap        swap             defaults          0 0" | tee -a /etc/fstab >/dev/null
        fi
      fi
    fi
    unset SWAP_SIZE swap_file_size swap_file swap_dir kilobit gigabit mem
    swapon --show 2>/dev/null | grep -v -- '^NAME ' | grep -q -- '^' && echo "Swap has been enabled"
    sleep 5
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# epel-release must be enabled before the casjay-dotfiles/scripts installer
# runs below - that installer's package list includes EPEL-only packages
# (nethogs, iftop, iperf, pass, html2text) which silently fail to install
# if epel is not yet available
{ yum makecache &>/dev/null && yum install -yy -q epel-release &>/dev/null; } || true
if [ ! -d "/usr/local/share/CasjaysDev/scripts" ]; then
  git clone "https://github.com/casjay-dotfiles/scripts" "/usr/local/share/CasjaysDev/scripts" -q
  eval "/usr/local/share/CasjaysDev/scripts/install.sh" || { echo "Failed to initialize" && exit 1; }
  export PATH="/usr/local/share/CasjaysDev/scripts/bin:$PATH"
  sleep 5
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Vendored from casjay-dotfiles/scripts system-installer.bash (self-contained,
# no network fetch) - only the functions this script actually calls.
if [ -n "${NO_COLOR+x}" ] || [ "$SHOW_RAW" = "true" ]; then
  __printf_color() { printf '%b' "$1" | tr -d '\t'; }
else
  __printf_color() { printf "%b" "$(tput setaf "$2" 2>/dev/null)" "$1" "$(tput sgr0 2>/dev/null)"; }
fi
__printf_green() { __printf_color "$1\n" 2; }
__printf_red() { __printf_color "$1\n" 208; }
__printf_yellow() { __printf_color "$1\n" 3; }
__printf_blue() { __printf_color "$1\n" 33; }
__printf_cyan() { __printf_color "$1\n" 6; }
__printf_exit() {
  __printf_color "$1\n" 208 1>&2
  exit 1
}
__printf_execute_success() { __printf_color "[ ✔ ] $1 \n" 2; }
__printf_execute_error() { __printf_color "[ ✖ ] $1 $2 \n" 1; }
__printf_execute_error_stream() { while read -r line; do __printf_execute_error "↳ ERROR: $line"; done; }
__printf_execute_result() {
  if [ "$1" -eq 0 ]; then __printf_execute_success "$2"; else __printf_execute_error "$2"; fi
  return "$1"
}
__printf_return() {
  test -n "$1" && test -z "${1//[0-9]/}" && local color="$1" && shift 1 || local color="208"
  test -n "$1" && test -z "${1//[0-9]/}" && local exitCode="$1" && shift 1 || local exitCode="1"
  local msg="$*"
  [ ${#msg} = 0 ] || { __printf_color "$msg" "$color" 1>&2 && printf "\n"; }
  return ${exitCode:-2}
}
__devnull() { "$@" >/dev/null 2>&1; }
__set_trap() { trap -p "$1" | grep -- "$2" &>/dev/null || trap "$2" "$1"; }
__urlcheck() { __devnull curl --output /dev/null --silent --head --fail "$1"; }
__urlinvalid() {
  if [ -z "$1" ]; then
    __printf_red "Invalid URL\n"
  else
    __printf_red "Can't find $1\n"
  fi
  exit 1
}
__urlverify() { __urlcheck $1 || __urlinvalid $1; }
__setexitstatus() {
  EXIT="${EXIT:-$?}"
  local EXITSTATUS+="$EXIT"
  if [ -z "$EXITSTATUS" ] || [ "$EXITSTATUS" -ne 0 ]; then
    BG_EXIT="${BG_RED}"
    return 1
  else
    BG_EXIT="${BG_GREEN}"
    return 0
  fi
}
__execute() {
  __kill_all_subprocesses() {
    local i=""
    for i in $(jobs -p); do
      kill "$i"
      wait "$i" &>/dev/null
    done
  }
  __show_spinner() {
    local -r FRAMES='/-\|'
    local -r NUMBER_OR_FRAMES=${#FRAMES}
    local -r CMDS="$2"
    local -r MSG="$3"
    local -r PID="$1"
    local i=0
    local frameText=""
    if [ "$TRAVIS" != "true" ]; then
      printf "\n\n\n"
      tput cuu 3
      tput sc
    fi
    while kill -0 "$PID" &>/dev/null; do
      frameText="[ ${FRAMES:i++%NUMBER_OR_FRAMES:1} ] $MSG"
      if [ "$TRAVIS" != "true" ]; then
        printf "%s\n" "$frameText"
      else
        printf "%s" "$frameText"
      fi
      sleep 0.2
      if [ "$TRAVIS" != "true" ]; then
        tput rc
      else
        printf "\r"
      fi
    done
  }
  local -r CMDS="$1"
  local -r MSG="${2:-$1}"
  local -r TMP_FILE="$(mktemp /tmp/XXXXX)"
  local exitCode=0
  local cmdsPID=""
  __set_trap "EXIT" "__kill_all_subprocesses"
  eval "$CMDS" >/dev/null 2>"$TMP_FILE" &
  cmdsPID=$!
  __show_spinner "$cmdsPID" "$CMDS" "$MSG"
  wait "$cmdsPID" &>/dev/null
  exitCode=$?
  __printf_execute_result $exitCode "$MSG"
  if [ $exitCode -ne 0 ]; then
    __printf_execute_error_stream <"$TMP_FILE"
  fi
  rm -rf "$TMP_FILE"
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SCRIPT_OS="RHEL/AlmaLinux/Rocky/Oracle/CentOS"
SCRIPT_DESCRIBE="Minimal"
GITHUB_USER="${GITHUB_USER:-casjay}"
SYSTEMMGR_CONFIGS="cron ssh ssl"
DFMGR_CONFIGS="misc vim bash git tmux"
SET_HOSTNAME="$([ -n "$(command -v hostname)" ] && hostname -s 2>/dev/null | grep -- '^' || echo "${MY_HOST_NAME//.*/}")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SCRIPT_NAME="$APPNAME"
SCRIPT_NAME="${SCRIPT_NAME%.*}"
RELEASE_VER="$(grep -s --no-filename -- 'VERSION_ID=' /etc/*-release | awk -F '=' '{print $2}' | sed 's#"##g' | awk -F '.' '{print $1}' | grep -- '^')"
RELEASE_NAME="$(grep -s --no-filename -- '^NAME=' /etc/*-release | awk -F'=' '{print $2}' | sed 's|"||g;s| .*||g' | tr '[:upper:]' '[:lower:]' | grep -- '^')"
RELEASE_ID="$(grep -s --no-filename -- '^ID=' /etc/*-release | awk -F'=' '{print $2}' | sed 's|"||g' | tr '[:upper:]' '[:lower:]' | grep -- '^')"
RELEASE_TYPE="$(i="$RELEASE_ID"; l=" $(grep -s --no-filename -- '^ID_LIKE=' /etc/*-release | awk -F'=' '{print $2}' | sed 's|"||g' | tr '[:upper:]' '[:lower:]') "; if [ "$i" = "rhel" ] || [ "$i" = "centos" ] || [ "$i" = "ol" ] || [[ "$l" == *" rhel "* ]] || [[ "$l" == *" centos "* ]]; then echo "rhel"; fi)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DEFAULT_KERNEL="${DEFAULT_KERNEL:-kernel-ml}"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
BACKUP_DIR="$HOME/Documents/backups/$(date +'%Y/%m/%d')"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SSH_KEY_LOCATION="${SSH_KEY_LOCATION:-https://github.com/$GITHUB_USER.keys}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^pbx'; then
  SYSTEM_TYPE="pbx"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^dns'; then
  SYSTEM_TYPE="dns"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^vpn'; then
  SYSTEM_TYPE="vpn"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^mail'; then
  SYSTEM_TYPE="mail"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^server'; then
  SYSTEM_TYPE="server"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^sql|^db'; then
  SYSTEM_TYPE="sql"
elif echo "${SET_HOSTNAME:-$HOSTNAME}" | grep -qE -- '^devel|^build|^ci|^testing'; then
  SYSTEM_TYPE="devel"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SERVICES_ENABLE="cockpit cockpit.socket docker fail2ban firewalld httpd munin-node nginx ntpd php-fpm postfix proftpd rsyslog snmpd sshd uptimed downtimed "
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SERVICES_DISABLE="avahi-daemon.service avahi-daemon.socket cups.path cups.service cups.socket dhcpd dhcpd6 dm-event.socket "
SERVICES_DISABLE+="import-state.service irqbalance.service iscsi iscsid.socket iscsiuio.socket kdump loadmodules.service lvm2-lvmetad.socket "
SERVICES_DISABLE+="lvm2-lvmpolld.socket lvm2-monitor mdmonitor multipathd.service multipathd.socket named nfs-client.target nis-domainname.service "
SERVICES_DISABLE+="nmb radvd rpcbind.service rpcbind.socket shorewall shorewall6 smb sssd-kcm.socket timedatex.service tuned.service udisks2.service"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$RELEASE_TYPE" = "rhel" ] || __printf_exit "This installer is meant to be run on a $SCRIPT_OS based system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$1" == "--help" ] && __printf_exit "${GREEN}${SCRIPT_DESCRIBE} installer for $SCRIPT_OS${NC}"
__port_in_use() { netstatg 2>&1 | awk '{print $4}' | grep -- ':[0-9]' | awk -F':' '{print $2}' | grep -- '[0-9]' | grep -q -- "^$1$" || return 2; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__system_service_exists() { systemctl status "$1" 2>&1 | grep -- 'Loaded:' | grep -iq -- "$1" && return 0 || return 1; }
__system_service_active() { (systemctl is-enabled "$1" || systemctl is-active "$1") | grep -qiE -- 'enabled|active' || return 1; }
__system_service_enable() { systemctl is-enabled --quiet "$1" 2>/dev/null || __execute "systemctl enable --now $1" "Enabling service: $1" || return 1; }
__system_service_disable() { systemctl is-active --quiet "$1" && __execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__does_user_exist() { grep -qs -- "^$1:" "/etc/passwd" || return 1; }
__does_group_exist() { grep -qs -- "^$1:" "/etc/group" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_user() {
  local user=""
  user="$(grep -sh -- "www-data" "/etc/passwd" || grep -sh -- "apache" "/etc/passwd" || grep -sh -- "nginx" "/etc/passwd")"
  [ -n "$user" ] && echo "$user" | awk -F ':' '{print $1}' || return 9
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_group() {
  local group=""
  group="$(grep -sh -- "www-data" "/etc/group" || grep -sh -- "apache" "/etc/group" || grep -sh -- "nginx" "/etc/group")"
  [ -n "$group" ] && echo "$group" | awk -F ':' '{print $1}' || return 9
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__copy_ca_certs() {
  local ssl_cn="" ssl_key="/etc/ssl/CA/CasjaysDev/private/localhost.key" ssl_crt="/etc/ssl/CA/CasjaysDev/certs/localhost.crt"
  if [ ! -d "/etc/letsencrypt/live/domain" ] || [ ! -L "/etc/letsencrypt/live/domain" ]; then
    __printf_red "letsencrypt seemed to have failed: Installing self-signed certificates"
    mkdir -p "/etc/letsencrypt/live/domain" "/etc/ssl/CA/CasjaysDev/private" "/etc/ssl/CA/CasjaysDev/certs"
    # casjay-base ships a committed key/cert pair at this path - this is only a
    # fallback for the rare case it's missing on the deployed host
    if [ ! -s "$ssl_key" ] || [ ! -s "$ssl_crt" ]; then
      ssl_cn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo 'localhost')"
      __printf_cyan "Generating a self-signed certificate for $ssl_cn"
      __devnull openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout "$ssl_key" -out "$ssl_crt" -subj "/CN=$ssl_cn" -addext "subjectAltName=DNS:$ssl_cn,DNS:localhost,IP:127.0.0.1" ||
        __printf_red "Failed to generate a self-signed certificate"
    fi
    chmod -f 600 "$ssl_key"
    chmod -f 644 "$ssl_crt"
    [ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/letsencrypt/live/domain/cert.pem"
    [ -f "$ssl_crt" ] && cp -Rf "$ssl_crt" "/etc/letsencrypt/live/domain/chain.pem"
    [ -f "$ssl_crt" ] && cp -Rf "$ssl_crt" "/etc/letsencrypt/live/domain/fullchain.pem"
    [ -f "$ssl_key" ] && cp -Rf "$ssl_key" "/etc/letsencrypt/live/domain/privkey.pem"
    find "/etc/letsencrypt" -type f -exec chmod 644 {} \;
    find "/etc/letsencrypt" -type d -exec chmod 755 {} \;
    chmod -f 600 "/etc/letsencrypt/live/domain/privkey.pem"
    # Cockpit loads every pair in ws-certs.d - the key must stay owner-only
    if [ -d "/etc/cockpit/ws-certs.d" ] && [ -s "$ssl_key" ]; then
      cp -f "$ssl_crt" "/etc/cockpit/ws-certs.d/1-my-cert.cert"
      cp -f "$ssl_key" "/etc/cockpit/ws-certs.d/1-my-cert.key"
      chmod -f 644 "/etc/cockpit/ws-certs.d/1-my-cert.cert"
      chmod -f 600 "/etc/cockpit/ws-certs.d/1-my-cert.key"
    fi
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__dnf_yum() {
  local rhel_pkgmgr="" opts="--skip-broken"
  rhel_pkgmgr="$(builtin type -P dnf || builtin type -P yum || false)"
  [ "$RELEASE_VER" -lt 8 ] || opts="--allowerasing --nobest --skip-broken"
  $rhel_pkgmgr $opts "$@"
  if rpm -q "$pkg" | grep -v -- 'is not installed' | grep -q -- '^'; then exitCode=0; else exitCode=1; fi
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__test_pkg() {
  for pkg in "$@"; do
    if rpm -q "$pkg" | grep -v -- 'is not installed' | grep -q -- '^'; then
      __printf_blue "[ ✔ ] $pkg is already installed"
      return 1
    else
      return 0
    fi
  done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__remove_pkg() {
  __test_pkg "$*" &>/dev/null || __execute "__dnf_yum remove -q -y $*" "Removing: $*"
  __test_pkg "$*" &>/dev/null || return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__install_pkg() {
  local statusCode=0
  excludes="$exclude_packages"
  if __test_pkg "$*"; then
    __execute "__dnf_yum install -q -yy $* $excludes" "Installing: $*"
    __test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
  else
    statusCode=0
  fi
  return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__detect_selinux() {
  if [ -f "/etc/selinux/config" ]; then
    grep -s -- 'SELINUX=' "/etc/selinux/config" | grep -q -- 'enabled' || return 1
  elif [ -f "$(type -P selinuxenabled 2>/dev/null)" ]; then
    selinuxenabled && return 1 || return 0
  else
    return 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__disable_selinux() {
  if __detect_selinux; then
    __printf_blue "selinux is now disabled"
    if [ -f "/etc/selinux/config" ]; then
      __devnull setenforce 0
      sed -i 's|SELINUX=.*|SELINUX=disabled|g' "/etc/selinux/config"
    else
      mkdir -p "/etc/selinux"
      cat <<EOF | tee "/etc/selinux/config" >/dev/null
#
SELINUX=disabled
SELINUXTYPE=targeted

EOF
    fi
  else
    __printf_green "selinux is already disabled"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_user_ssh_key() {
  local ssh_key=""
  local col=${COLUMNS:-120}
  local col=$(($col - 40))
  [ -n "$SSH_KEY_LOCATION" ] || return 0
  [ -d "$HOME/.ssh" ] || mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  get_keys="$(curl -q -LSsf "$SSH_KEY_LOCATION" 2>/dev/null | grep -- '^' || false)"
  if [ -n "$get_keys" ]; then
    echo "$get_keys" | while read -r key; do
      key_value="$(echo "$key" | awk -F ' ' '{print $2}')"
      if grep -qs -- "$key" "$HOME/.ssh/authorized_keys"; then
        __printf_cyan "Key exists in ~/.ssh/authorized_keys: ${key_value:0:$col}"
      else
        echo "$key" | tee -a "/root/.ssh/authorized_keys" &>/dev/null
        __printf_green "Successfully added key: ${key_value:0:$col}"
      fi
    done
  else
    __printf_return "Can not get key from $SSH_KEY_LOCATION"
    return 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_init_check() {
  { printf '%b\n' "${YELLOW}Updating cache and installing epel-release${NC}" && yum makecache &>/dev/null && __dnf_yum install epel-release -yy -q &>/dev/null; } || true
  if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
    git -C /usr/local/share/CasjaysDev/scripts pull -q
    if [ $? -ne 0 ]; then
      rm -Rf "/usr/local/share/CasjaysDev/scripts"
      git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
    fi
  fi
  yum clean all &>/dev/null || true
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__yum() { yum "$@" $yum_opts &>/dev/null || return 1; }
__grab_remote_file() { __urlverify "$1" && curl -q -SLs "$1" || exit 1; }
__backup_repo_files() { cp -Rf "/etc/yum.repos.d/." "$BACKUP_DIR" 2>/dev/null || return 0; }
__rm_repo_files() { [ "${1:-$YUM_DELETE}" = "yes" ] && rm -Rf "/etc/yum.repos.d"/* &>/dev/null || return 0; }
__run_external() { __printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
__save_remote_file() { __urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
__retrieve_version_file() { __grab_remote_file "https://github.com/casjay-base/rhel/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
__domain_name() { hostname -d | grep -Fv -- '(none)' | grep -- '^' || hostname -f | awk -F'.' '{$1="";OFS="." ; print $0}' | sed 's/^.//;s| |.|g' | grep -- '^' || echo "$HOSTNAME"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__printf_head() {
  printf '%b##################################################\n' "$CYAN"
  printf '%b%s%b\n' $GREEN "$*" $CYAN
  printf '##################################################%b\n' $NC
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__printf_clear() {
  clear
  __printf_head "$*"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__rm_if_exists() {
  local file_loc=("$@") && shift $#
  for file in "${file_loc[@]}"; do
    if [ -e "$file" ]; then
      __execute "rm -Rf $file" "Removing $file"
    fi
  done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__retrieve_repo_file() {
  local statusCode="0"
  local YUM_DELETE="true"
  yum clean all &>/dev/null
  if [ "$RELEASE_TYPE" = "rhel" ] && [ "$SET_HOSTNAME" != "pbx" ]; then
    YUM_DELETE="yes"
    case "$RELEASE_ID" in
    almalinux) RELEASE_FILE_NAME="almalinux.$RELEASE_VER.repo" ;;
    rocky) RELEASE_FILE_NAME="rockylinux.$RELEASE_VER.repo" ;;
    ol) RELEASE_FILE_NAME="oraclelinux.$RELEASE_VER.repo" ;;
    centos)
      if [ "$RELEASE_VER" -le 7 ]; then
        RELEASE_FILE_NAME="centos.$RELEASE_VER.repo"
      else
        RELEASE_FILE_NAME="almalinux.$RELEASE_VER.repo"
      fi
      ;;
    *) RELEASE_FILE_NAME="almalinux.$RELEASE_VER.repo" ;;
    esac
    RELEASE_FILE="https://github.com/rpm-devel/casjay-release/raw/main/$RELEASE_FILE_NAME"
  else
    yum makecache &>/dev/null
    return 0
  fi
  if [ -n "$RELEASE_FILE" ]; then
    printf '%b\n' "${YELLOW}Updating yum repos: This may take some time${NC}"
    __backup_repo_files
    __rm_repo_files "$YUM_DELETE"
    __save_remote_file "$RELEASE_FILE" "/etc/yum.repos.d/casjay.repo"
    yum makecache &>/dev/null || statusCode=1
  fi
  [ "$statusCode" -ne 0 ] || printf '%b\n' "${YELLOW}Done updating repos${NC}"
  return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_grub() {
  local cfg="" efi="" grub_cfg="" grub_efi="" grub_bin="" grub_bin_name=""
  grub_cfg="$(find /boot/grub*/* -name 'grub*.cfg' 2>/dev/null | grep -- '^' || false)"
  grub_efi="$(find /boot/efi/EFI/* -name 'grub*.cfg' 2>/dev/null | grep -- '^' || false)"
  grub_bin="$(builtin type -P grub-mkconfig 2>/dev/null || builtin type -P grub2-mkconfig 2>/dev/null || false)"
  grub_bin_name="$(basename "$grub_bin" 2>/dev/null || false)"
  if [ -n "$grub_bin" ]; then
    if [ -f "/etc/default/grub" ]; then
      for opt in 'biosdevname' 'net.ifnames'; do
        if grep -shq -- "$opt" '/etc/default/grub'; then
          __devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/'$opt'=[01]/'$opt'=0/' /etc/default/grub
        else
          __devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ '$opt'=0"/' /etc/default/grub
        fi
      done
      if ! stat -fc %T '/sys/fs/cgroup' | grep -q -- 'cgroup2fs' && ! grep -sq -- 'systemd.unified_cgroup_hierarchy' /etc/default/grub; then
        __devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
      fi
    fi
    if grep -sq -- 'GRUB_ENABLE_BLSCFG' "/etc/default/grub"; then
      sed -i 's|GRUB_ENABLE_BLSCFG=.*|GRUB_ENABLE_BLSCFG=false|g' '/etc/default/grub'
    else
      echo "GRUB_ENABLE_BLSCFG=false" >>'/etc/default/grub'
    fi
    # if grep -sq -- 'crashkernel=' '/etc/default/grub'; then
    #   sed -i '/^GRUB_CMDLINE_LINUX=/s/crashkernel=.*[KMG][, ]//' '/etc/default/grub'
    # fi
    __rm_if_exists /boot/*rescue*
    __rm_if_exists /boot/loader/entries/*
    if [ -n "$grub_cfg" ]; then
      for cfg in $grub_cfg; do
        if [ -e "$cfg" ]; then
          __devnull $grub_bin -o "$cfg" && __printf_green "Updated $cfg" || __printf_return "Failed to update $cfg"
        fi
      done
    fi
    if [ -n "$grub_efi" ]; then
      for efi in $grub_efi; do
        if [ -e "$efi" ]; then
          # EL9+/Fedora/Debian ship /boot/efi/EFI/{distro}/grub.cfg as a stub that only chainloads the real grub.cfg - grub-mkconfig refuses to overwrite it, so skip it
          if grep -qs -- 'configfile' "$efi" && ! grep -qs -- 'BEGIN /etc/grub.d/' "$efi"; then
            continue
          fi
          __devnull $grub_bin -o "$efi" && __printf_green "Updated $efi" || __printf_return "Failed to update $efi"
        fi
      done
    fi
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_post() {
  local e="$*"
  local m="${e//__devnull /}"
  __execute "$e" "${run_post_message:-executing: $m}"
  __setexitstatus
  set --
  unset run_post_message
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_ml() {
  local exitC=0
  local kernel="$(uname -r 2>/dev/null | grep -F -- 'elrepo')"
  local kernel_avail="$(yum search kernel-ml 2>&1 | awk '{print $1}' | grep -- '^kernel-ml-.*[.]' || return)"
  if [ -n "$kernel" ]; then
    __printf_green "You are already running kernel-ml: $kernel"
  elif [ -n "$kernel_avail" ]; then
    __printf_cyan "Switching to the newest kernel from elrepo - This may take a few minutes"
    pkgs="$(rpm -qa | grep -v -- 'kernel-ml' | grep -- '^kernel')"
    [ -n "$pkgs" ] && for pkg in $pkgs; do rpm -ev --nodeps $pkg >/dev/null 2>&1; done
    yum install -yyq kernel-ml kernel-core kernel-ml-modules kernel-ml-modules-extra kernel-ml-tools >/dev/null || exitC=1
    __run_grub
  else
    __printf_yellow "kernel-ml doesn't seem to be avaliable"
    exitC=1
  fi
  return $exitC
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_lt() {
  local exitC=0
  local kernel="$(uname -r 2>/dev/null | grep -F -- 'elrepo')"
  local kernel_avail="$(yum search kernel-lt 2>&1 | awk '{print $1}' | grep -- '^kernel-lt-.*[.]' || return)"
  if [ -n "$kernel" ]; then
    __printf_green "You are already running kernel-lt: $kernel"
  elif [ -n "$kernel_avail" ]; then
    __printf_cyan "Switching to the newest LTS kernel from elrepo - This may take a few minutes"
    pkgs="$(rpm -qa | grep -v -- 'kernel-lt' | grep -- '^kernel')"
    [ -n "$pkgs" ] && for pkg in $pkgs; do rpm -ev --nodeps $pkg >/dev/null 2>&1; done
    yum install -yyq kernel-lt kernel-lt-core kernel-lt-modules kernel-lt-modules-extra kernel-lt-tools >/dev/null || exitC=1
    __run_grub
  else
    __printf_yellow "kernel-lt doesn't seem to be avaliable"
    exitC=1
  fi
  return $exitC
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__fix_network_device_name() {
  local device=""
  device="$(ip -4 route ls 2>/dev/null | grep -- default | grep -Po -- '(?<=dev )(\S+)' | head -n1 | grep -- '^' || echo 'eth0')"
  __printf_green "Setting network device name to $device in $1"
  find "$1" -type f -exec sed -i 's|eth0|'$device'|g' {} +
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##################################################################################################################
__printf_clear "Initializing the installer for $RELEASE_NAME using $SCRIPT_DESCRIBE script"
##################################################################################################################
[ -d "/etc/casjaysdev/updates/versions" ] || mkdir -p "/etc/casjaysdev/updates/versions"
if [ -f "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt" ]; then
  __printf_red "$(<"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt")"
  __printf_red "To reinstall please remove the version file in"
  __printf_red "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
  exit 1
elif [ -f "/etc/casjaysdev/updates/versions/installed.txt" ]; then
  __printf_red "$(<"/etc/casjaysdev/updates/versions/installed.txt")"
  __printf_red "To reinstall please remove the version file in"
  __printf_red "/etc/casjaysdev/updates/versions/installed.txt"
  exit 1
else
  __run_init_check
  if ! __retrieve_repo_file; then
    __devnull __rm_if_exists "/etc/casjaysdev/updates/versions/installed.txt"
    __devnull __rm_if_exists "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
    __printf_red "The script has failed to initialize"
    exit 2
  fi
  if [ ! -f "/etc/casjaysdev/updates/versions/os_version.txt" ]; then
    echo "$RELEASE_VER" >"/etc/casjaysdev/updates/versions/os_version.txt"
  fi
fi
if [ -n "$(type -P systemmgr)" ]; then
  __run_external /usr/local/share/CasjaysDev/scripts/install.sh
  __run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr --config
  __run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr update scripts
  __run_external "__yum clean all"
fi
__printf_green "Installer has been initialized"
##################################################################################################################
__printf_head "Fixing initscripts"
##################################################################################################################
__devnull rpm -ev --nodeps initscripts
__devnull yum -yy --allowerasing install initscripts net-tools
##################################################################################################################
__printf_head "Installing vnstat"
##################################################################################################################
__install_pkg vnstat
__system_service_enable vnstat && systemctl restart vnstat &>/dev/null
##################################################################################################################
__printf_head "Configuring the kernel"
##################################################################################################################
if [ "$DEFAULT_KERNEL" = "ml" ] || [ "$DEFAULT_KERNEL" = "kernel-ml" ]; then
  __kernel_ml
  __install_pkg kernel-ml-modules
  __install_pkg kernel-ml-modules-extra
elif [ "$DEFAULT_KERNEL" = "lt" ] || [ "$DEFAULT_KERNEL" = "kernel-lt" ]; then
  # elrepo publishes no kernel-lt for EL10+ - fall back to kernel-ml
  if [ "$RELEASE_VER" -ge 10 ]; then
    __printf_yellow "kernel-lt is not published for EL$RELEASE_VER - using kernel-ml instead"
    DEFAULT_KERNEL="kernel-ml"
    __kernel_ml
    __install_pkg kernel-ml-modules
    __install_pkg kernel-ml-modules-extra
  else
    __kernel_lt
    __install_pkg kernel-lt-modules
    __install_pkg kernel-lt-modules-extra
  fi
else
  DEFAULT_KERNEL="kernel"
fi
##################################################################################################################
__printf_head "Disabling selinux"
##################################################################################################################
__disable_selinux
##################################################################################################################
__printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c -- ^processor /proc/cpuinfo)
__printf_yellow "Total cores avaliable: $numberofcores"
if [ $numberofcores -gt 1 ]; then
  if [ -f "/etc/makepkg.conf" ]; then
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(($numberofcores + 1))'"/g' /etc/makepkg.conf
    sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
  else
    cat <<EOF >"/etc/makepkg.conf"
#########################################################################
# ARCHITECTURE, COMPILE FLAGS
#########################################################################
CARCH="x86_64"
CHOST="x86_64-pc-linux-gnu"
CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
CXXFLAGS="\$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
RUSTFLAGS="-Cforce-frame-pointers=yes"
MAKEFLAGS="-j$(($numberofcores + 1))"
DEBUG_CFLAGS="-g"
DEBUG_CXXFLAGS="\$DEBUG_CFLAGS"
DEBUG_RUSTFLAGS="-C debuginfo=2"
#########################################################################
# BUILD ENVIRONMENT
#########################################################################
BUILDENV=(!distcc color !ccache check !sign)
#DISTCC_HOSTS=""
#BUILDDIR=/tmp/makepkg
#########################################################################
# GLOBAL PACKAGE OPTIONS
#########################################################################
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)
INTEGRITY_CHECK=(sha256)
STRIP_BINARIES="--strip-all"
STRIP_SHARED="--strip-unneeded"
STRIP_STATIC="--strip-debug"
MAN_DIRS=({usr{,/local}{,/share},opt/*}/{man,info})
DOC_DIRS=(usr/{,local/}{,share/}{doc,gtk-doc} opt/*/{doc,gtk-doc})
PURGE_TARGETS=(usr/{,share}/info/dir .packlist *.pod)
DBGSRCDIR="/usr/src/debug"
LIB_DIRS=('lib:usr/lib' 'lib32:usr/lib32')
#########################################################################
# COMPRESSION DEFAULTS
#########################################################################
COMPRESSGZ=(gzip -c -f -n)
COMPRESSBZ2=(bzip2 -c -f)
COMPRESSXZ=(xz -c -T $numberofcores -z -)
COMPRESSZST=(zstd -c -T0 --ultra -20 -)
COMPRESSLRZ=(lrzip -q)
COMPRESSLZO=(lzop -q)
COMPRESSZ=(compress -c -f)
COMPRESSLZ4=(lz4 -q)
COMPRESSLZ=(lzip -c -f)
#########################################################################
# END
#########################################################################
EOF
  fi
fi
##################################################################################################################
__printf_head "Grabbing ssh key[s]: from $SSH_KEY_LOCATION for $USER"
##################################################################################################################
__get_user_ssh_key
##################################################################################################################
__printf_head "Configuring the system"
##################################################################################################################
__retrieve_repo_file
__run_external timedatectl set-timezone America/New_York
for oci in 'oci*' 'cloud*' 'oracle*'; do __yum remove -yy -q "$oci" &>/dev/null; done
for rpms in echo chrony cronie-anacron sendmail sendmail-cf esmtp; do rpm -ev --nodeps $rpms &>/dev/null; done
__install_pkg cronie-noanacron
__install_pkg postfix
__install_pkg net-tools
__install_pkg wget
__install_pkg curl
__install_pkg git
__install_pkg s-nail
__install_pkg e2fsprogs
[ "$RELEASE_VER" -le 8 ] && __install_pkg redhat-lsb || true
__install_pkg vim-enhanced
__install_pkg unzip
__install_pkg bind
__install_pkg bind-utils
__rm_if_exists /tmp/dotfiles
__rm_if_exists /root/anaconda-ks.cfg /var/log/anaconda
__run_external yum update -q -yy --skip-broken
[ "$RELEASE_VER" -ge 9 ] && __install_pkg glibc-langpack-en || true
# EL9-and-earlier packages (dropped from EL10 repos)
if [ "$RELEASE_VER" -le 9 ]; then
  __install_pkg awstats
  __install_pkg fortune-mod
  __install_pkg perl-DBD-Firebird
  __install_pkg python3-future
fi
# mlocate was replaced by plocate in EL10
if [ "$RELEASE_VER" -le 9 ]; then
  __install_pkg mlocate
else
  __install_pkg plocate
fi
# zlib was replaced by zlib-ng-compat in EL10
if [ "$RELEASE_VER" -le 9 ]; then
  __install_pkg zlib
else
  __install_pkg zlib-ng-compat
fi
##################################################################################################################
__printf_head "Enabling ip forwarding"
##################################################################################################################
for sysctlconf in /etc/sysctl.conf /etc/sysctl.d/*; do
  if grep -qsF -- 'net.ipv4.ip_forward' "$sysctlconf"; then
    __devnull sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' "$sysctlconf"
  else
    sysctl_ip4_forward=0
  fi
  if grep -qsFR -- 'net.ipv6.conf.all.forwarding' "$sysctlconf"; then
    __devnull sed -i 's/net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' "$sysctlconf"
  else
    sysctl_ip6_forward=0
  fi
done
if [ "$sysctl_ip4_forward" = 0 ]; then
  unset sysctl_ip4_forward
  echo "net.ipv4.ip_forward=1" >>'/etc/sysctl.conf'
fi
if [ "$sysctl_ip6_forward" = 0 ]; then
  unset sysctl_ip6_forward
  echo "net.ipv6.conf.all.forwarding=1" >>'/etc/sysctl.conf'
fi
##################################################################################################################
__printf_head "Installing the packages for $RELEASE_NAME"
##################################################################################################################
__install_pkg basesystem
__install_pkg bash
__install_pkg bash-completion
__install_pkg biosdevname
__install_pkg certbot
__install_pkg cockpit
__install_pkg cockpit-packagekit
__install_pkg cockpit-storaged
__install_pkg cockpit-bridge
__install_pkg cockpit-system
__install_pkg cockpit-ws
__install_pkg coreutils
__install_pkg cowsay
__install_pkg cracklib
__install_pkg cracklib-dicts
__install_pkg cronie
__install_pkg cronie-noanacron
__install_pkg crontabs
__install_pkg curl
__install_pkg ctags
__install_pkg deltarpm
__install_pkg dialog
__install_pkg docker-ce
__install_pkg ethtool
__install_pkg findutils
__install_pkg gawk
__install_pkg gc
__install_pkg gcc
__install_pkg git
__install_pkg gnupg2
__install_pkg gnutls
__install_pkg grub2-tools
__install_pkg grub2-tools-extra
__install_pkg grubby
__install_pkg gzip
__install_pkg util-linux-core
__install_pkg harfbuzz
__install_pkg hdparm
__install_pkg hostname
__install_pkg htop
__install_pkg httpd
__install_pkg less
__install_pkg logrotate
__install_pkg lsof
__install_pkg make
__install_pkg man-db
__install_pkg man-pages
__install_pkg mod_fcgid
__install_pkg mod_geoip
__install_pkg mod_http2
__install_pkg mod_maxminddb
__install_pkg mod_perl
__install_pkg mod_ssl
__install_pkg mod_wsgi
__install_pkg mod_proxy_html
__install_pkg mod_proxy_uwsgi
__install_pkg mosh
__install_pkg mrtg
__install_pkg munin
__install_pkg munin-common
__install_pkg munin-node
__install_pkg ncurses
__install_pkg ncurses-base
__install_pkg ncurses-libs
__install_pkg net-tools
__install_pkg nginx
__install_pkg ntp
__install_pkg oddjob-mkhomedir
__install_pkg openssh-server
__install_pkg openssl
__install_pkg shadow-utils
__install_pkg perl-CPAN
__install_pkg perl-CPAN-Meta
__install_pkg perl-DBD-Pg
__install_pkg perl-DBD-MySQL
__install_pkg perl-DBD-SQLite
__install_pkg perl-DBD-MariaDB
__install_pkg php
__install_pkg php-cli
__install_pkg php-common
__install_pkg php-fpm
__install_pkg php-gd
__install_pkg php-gmp
__install_pkg php-intl
__install_pkg php-mbstring
__install_pkg php-mysqlnd
__install_pkg php-pdo
__install_pkg php-pgsql
__install_pkg php-xml
__install_pkg pinentry
__install_pkg postfix
__install_pkg postfix-pcre
__install_pkg python3-certbot-dns-rfc2136
__install_pkg python3-configargparse
__install_pkg python3-cryptography
__install_pkg python3-idna
__install_pkg python3-josepy
__install_pkg python3-neovim
__install_pkg python3-parsedatetime
__install_pkg python3-pbr
__install_pkg python3-pip
__install_pkg python3-psutil
__install_pkg python3-pyasn1
__install_pkg python3-pyrfc3339
__install_pkg python3-pysocks
__install_pkg python3-requests
__install_pkg python3-six
__install_pkg python3-virtualenv
__install_pkg readline
__install_pkg rootfiles
__install_pkg rsync
__install_pkg rsyslog
__install_pkg screen
__install_pkg sed
__install_pkg sqlite
__install_pkg sudo
__install_pkg symlinks
__install_pkg tar
__install_pkg tzdata
__install_pkg unzip
__install_pkg wget
__install_pkg which
__install_pkg whois
__install_pkg xz
__install_pkg xz-libs
__install_pkg yum-utils
__install_pkg zip
##################################################################################################################
if [ "$SYSTEM_TYPE" = "dns" ]; then
  if __devnull __install_pkg ntp || __devnull __install_pkg ntpsec; then
    __printf_cyan "Installed ntp"
    SERVICES_ENABLE="$SERVICES_ENABLE ntpd"
    [ -d "/var/lib/ntp/stats" ] || mkdir -p "/var/lib/ntp/stats"
  fi
else
  __install_pkg chrony
  SERVICES_ENABLE="$SERVICES_ENABLE chrony"
fi
##################################################################################################################
__printf_head "Fixing grub"
##################################################################################################################
__run_grub
##################################################################################################################
__printf_head "Installing custom web server files"
##################################################################################################################
[ -d "$CONFIG_TEMP_DIR" ] && __devnull __rm_if_exists "$CONFIG_TEMP_DIR"
__devnull git clone -q "https://github.com/casjay-base/rhel" "$CONFIG_TEMP_DIR"
if [ -d "/var/www/html/sysinfo/.git" ]; then
  __devnull git -C "/var/www/html/sysinfo" reset --hard
  __run_post git -C "/var/www/html/sysinfo" pull -q
else
  __devnull __rm_if_exists "/var/www/html/sysinfo"
  __run_post git clone -q "https://github.com/phpsysinfo/phpsysinfo" "/var/www/html/sysinfo"
fi
if [ -d "/var/www/html/vnstat/.git" ]; then
  __devnull git -C "/var/www/html/vnstat" reset --hard
  __run_post git -C "/var/www/html/vnstat" pull -q
else
  __devnull __rm_if_exists "/var/www/html/vnstat"
  __run_post git clone -q "https://github.com/solbu/vnstat-php-frontend" "/var/www/html/vnstat"
fi
run_post_message="Installing default server files" __run_post sudo -HE STATICSITE="$(hostname -f)" bash -c "$(curl -LSs "https://github.com/casjay-templates/default-web-assets/raw/main/setup.sh")"
[ -f "/etc/httpd/modules/mod_wsgi_python3.so" ] && ln -sf /etc/httpd/modules/mod_wsgi_python3.so /etc/httpd/modules/mod_wsgi.so
##################################################################################################################
__printf_head "Deleting files"
##################################################################################################################
if __system_service_active named || __port_in_use "53"; then
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/named*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/var/named*
else
  __devnull __rm_if_exists /etc/named* /var/named/*
fi
if [ -z "$(type -p ntp || type -p ntpd || type -p ntpq)" ]; then
  IS_INSTALLED_NTP=no
  __devnull __rm_if_exists /etc/ntp*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/ntp*
fi
if [ -z "$(type -p chronyd)" ]; then
  IS_INSTALLED_CHRONY=no
  __devnull __rm_if_exists /etc/chrony*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/chrony*
fi
if [ -z "$(type -P httpd)" ]; then
  IS_INSTALLED_HTTPD=no
  __devnull __rm_if_exists /etc/httpd*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/httpd*
fi
if [ -z "$(type -P nginx)" ]; then
  IS_INSTALLED_NGINX=no
  __devnull __rm_if_exists /etc/nginx*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/nginx*
fi
if [ -z "$(type -P named)" ]; then
  IS_INSTALLED_BIND=no
  __devnull __rm_if_exists /etc/named*
  __devnull __rm_if_exists /var/named*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/named*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/var/named*
fi
if [ -z "$(type -P proftpd)" ]; then
  IS_INSTALLED_PROFTPD=no
  __devnull __rm_if_exists /etc/proftpd*
  __devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/proftpd*
fi
if [ -f "/etc/certbot/dns.conf" ]; then
  __devnull __rm_if_exists "$CONFIG_TEMP_DIR/etc/certbot/dns.conf"
fi
for rm_file in /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/httpd/conf.d/ssl.conf; do
  __run_post __devnull __rm_if_exists "$rm_file"
done
##################################################################################################################
__printf_head "setting up config files"
##################################################################################################################
set_domainname="$(__domain_name)"
myhostnameshort="$SET_HOSTNAME"
myserverdomainname="$(hostname -f)"
NETDEV="$(ip route | grep -- 'default' | sed -e "s/^.*dev.//" -e "s/.proto.*//")"
does_lo_have_ipv6="$(ifconfig lo | grep -- 'inet6' | grep -q -- '::1' && echo yes || false)"
GET_WEB_USER="$(__get_www_user)"
GET_WEB_GROUP="$(__get_www_group)"
[ -n "$NETDEV" ] && mycurrentipaddress_6="$(ifconfig $NETDEV | grep -E -- 'venet|inet' | grep -v -- 'docker' | grep -- inet6 | grep -i -- 'global' | awk '{print $2}' | head -n1 | grep -- '^' || hostname -I | tr ' ' '\n' | grep -Ev -- '^::1|^$' | grep -- ':.*:' | head -n1 | grep -- '^' || echo '::1')"
[ -n "$NETDEV" ] && mycurrentipaddress_4="$(ifconfig $NETDEV | grep -E -- 'venet|inet' | grep -v -- '127.0.0.' | grep -- inet | grep -v -- 'inet6' | awk '{print $2}' | sed 's#addr:##g' | head -n1 | grep -- '^' || hostname -I | tr ' ' '\n' | grep -vE -- '|127\.0\.0|172\.17\.0|:.*:|^$' | head -n1 | grep -- '[0-9]\.[0-9]' || echo '127.0.0.1')"
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.sh" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.pl" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.cgi" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname ".gitkeep" -exec rm -Rf {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mydomainname#$set_domainname#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myhostnameshort#$myhostnameshort#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myserverdomainname#$myserverdomainname#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_6#$mycurrentipaddress_6#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_4#$mycurrentipaddress_4#g" {} \;
if [ -n "$NETDEV" ]; then
  __devnull find -L $CONFIG_TEMP_DIR -type f -exec sed -i "s#mynetworkdevice#$NETDEV#g" {} \; || __devnull find -L $CONFIG_TEMP_DIR -type f -exec sed -i "s#mynetworkdevice#eth0#g" {} \;
  if [ -f "/etc/sysconfig/network-scripts/ifcfg-eth0.sample" ]; then
    __devnull mv -f "/etc/sysconfig/network-scripts/ifcfg-eth0.sample" "/etc/sysconfig/network-scripts/ifcfg-$NETDEV.sample"
  fi
fi
if [ -z "$does_lo_have_ipv6" ]; then
  sed -i 's|inet_interfaces.*|inet_interfaces = 127.0.0.1|g' $CONFIG_TEMP_DIR/etc/postfix/main.cf
fi
__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/{fail2ban,shorewall,shorewall6}
__devnull mkdir -p /etc/rsync.d /var/log/named
__devnull rsync -avhP $CONFIG_TEMP_DIR/{etc,root,usr,var}* /
# mod_geoip has no installable package on EL9/10 (the legacy Apache GeoIP
# module was retired); guard the deployed httpd.conf so httpd can still
# start when it's missing, without touching hosts where it's installed
if [ -f /etc/httpd/conf/httpd.conf ] && [ ! -e /usr/lib64/httpd/modules/mod_geoip.so ] && [ ! -e /etc/httpd/modules/mod_geoip.so ]; then
  __devnull sed -i '/^LoadModule geoip_module/s/^/#/' /etc/httpd/conf/httpd.conf
  __devnull sed -i '/^GeoIPEnable\|^GeoIPDBFile/s/^/#/' /etc/httpd/conf/httpd.conf
fi
if [ -f /etc/fail2ban/jail.local ]; then
  # Every jail in jail.local is permanently enabled - server.sh only runs
  # once, at bootstrap, so a jail could never be enabled later if it
  # depended on detecting the service at bootstrap time. Instead we just
  # make sure each jail's logpath exists (as an empty file, if needed) so
  # fail2ban never errors on a missing log; once the real service is
  # installed and starts writing to that same path, the already-running
  # jail picks it up immediately with no further changes here.
  __devnull mkdir -p /var/log/proftpd /var/log/httpd /var/log/nginx /var/log/named /var/log/mysql /var/opt/mssql/log
  __devnull touch /var/log/proftpd/auth.log /var/log/httpd/error_log /var/log/nginx/error.log /var/log/nginx/access.log /var/log/named/security.log /var/log/mysql/mysql.log /var/opt/mssql/log/errorlog /var/log/maillog /var/log/secure /var/log/fail2ban.log
fi
__devnull sed -i "s#myserverdomainname#$HOSTNAME#g" /etc/sysconfig/network
__devnull sed -i "s#mydomain#$set_domainname#g" /etc/sysconfig/network
__devnull chmod 644 -Rf /etc/cron.d/* /etc/logrotate.d/*
__devnull touch /etc/postfix/mydomains.pcre
__devnull chattr +i /etc/resolv.conf
if [ -z "$IS_INSTALLED_BIND" ]; then
  if __does_user_exist 'named'; then
    __devnull mkdir -p /etc/named /var/named /var/log/named
    __devnull chown -Rf named:named /etc/named* /var/named /var/log/named
  fi
fi
if [ -z "$(type -P postfix)" ]; then
  __rm_if_exists /etc/postfix
else
  for postfix_proto in "/etc/postfix"/*.proto; do
    __devnull __rm_if_exists $postfix_proto
  done
  __devnull chgrp postdrop /usr/sbin/postqueue
  __devnull chgrp postdrop /usr/sbin/postdrop
  __devnull chgrp postdrop /var/spool/postfix/maildrop
  __devnull chgrp postdrop /var/spool/postfix/public
  __devnull chown root /var/spool/postfix/pid
  __devnull chmod g+s /usr/sbin/postqueue
  __devnull chmod g+s /usr/sbin/postdrop
  __devnull killall -9 postdrop
  __devnull postfix set-permissions create-missing
  __devnull postmap /etc/postfix/transport /etc/postfix/canonical /etc/postfix/virtual /etc/postfix/mydomains /etc/postfix/sasl/passwd
  __devnull newaliases &>/dev/null || newaliases.postfix -I &>/dev/null
fi
if ! grep -sq -- 'kernel.domainname' "/etc/sysctl.conf"; then
  echo "kernel.domainname=$set_domainname" >>/etc/sysctl.conf
fi
__devnull systemctl daemon-reload
unset postfix_proto
##################################################################################################################
__printf_head "Installing incus"
##################################################################################################################
incus_setup_failed="no"
incus_setup_message="Initializing incus has failed"
exclude_packages="--exclude=qemu*-9*"
__devnull crb enable
__devnull yum clean packages
if ! grep -Rqsi -- 'copr.*incus' '/etc/yum.repos.d'; then
  __printf_green "Enabling the dnf incus repo"
  __devnull dnf -y install epel-release
  __devnull dnf -y copr enable neil/incus
  __devnull dnf -y config-manager --enable crb
  __yum makecache
fi
# the incus copr does not publish incus for every EL release - skip cleanly when it is missing
if ! __devnull yum -q info incus; then
  __printf_yellow "incus is not available for EL$RELEASE_VER - skipping incus setup"
  unset exclude_packages incus_setup_failed incus_setup_message
else
  __install_pkg incus
  __install_pkg incus-tools
  __install_pkg incus-selinux
  unset exclude_packages
  [ -n "$(type -p setupmgr)" ] && setupmgr incus
  echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
  if __system_service_exists "incus"; then
    __devnull systemctl start "incus"
    __devnull systemctl restart "incus"
    __devnull systemctl enable --now incus || incus_setup_failed="yes"
  else
    incus_setup_failed=yes
  fi
  [ "$(ls -A /var/lib/incus/* 2>/dev/null | wc -l)" != "0" ] && incus_setup_message="incus seems to be initialized" || { incus_setup_failed="yes" && incus_setup_message="incus seems to have already been initialized"; }
  if [ "$incus_setup_failed" = "no" ]; then
    if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
      __devnull incus network set incusbr0 ipv4.firewall false
      __devnull incus network set incusbr0 ipv6.firewall false
      __devnull systemctl restart incus
      __printf_blue "incus has been initialized"
      unset incus_setup_failed incus_setup_message
    else
      incus_setup_failed="yes"
    fi
  fi
fi
##################################################################################################################
__printf_head "Configuring the firewall"
##################################################################################################################
if type -P firewall-cmd >/dev/null 2>&1 && __system_service_active firewalld; then
	__devnull systemctl start firewalld
	# firewalld stays wide open (fail2ban's firewallcmd-ipset banaction does
	# the actual blocking) - see etc/firewalld/zones/public.xml and
	# etc/fail2ban/jail.d/00-firewalld.conf
	__devnull firewall-cmd --permanent --zone=public --set-target=ACCEPT
	# docker-ce auto-manages its own "docker" firewalld zone for docker0 at
	# runtime (D-Bus, target=ACCEPT) - a manual --change-interface=docker0
	# binding here collides with it (ZONE_CONFLICT: interface already bound
	# to a zone), so it has been dropped. incus does NOT self-manage a
	# zone (ipv4.firewall/ipv6.firewall=false on its networks - it
	# deliberately leaves firewalling to the host), so incusbr0 keeps its
	# explicit bind.
	if type -P incus >/dev/null 2>&1; then
		__devnull firewall-cmd --permanent --zone=trusted --change-interface=incusbr0
	fi
	__devnull firewall-cmd --reload
	__devnull systemctl stop firewalld
fi
##################################################################################################################
__printf_head "Configuring applications"
##################################################################################################################
__devnull timedatectl set-ntp true
##################################################################################################################
__printf_head "Configuring cloudflare dns for $SET_HOSTNAME"
##################################################################################################################
CLOUDFLARE_PROXY="${CLOUDFLARE_PROXY:-false}"
if [ -f "$HOME/.config/secure/cloudflare.txt" ]; then
  . "$HOME/.config/secure/cloudflare.txt"
  CLOUDFLARE_DEFAULT_ZONE="${CLOUDFLARE_DEFAULT_ZONE:-internal2.me}"
  if [ -n "${CLOUDFLARE_ZONE_KEY:-$CLOUDFLARE_API_KEY}" ] && [ -n "$CLOUDFLARE_DEFAULT_ZONE" ] && [ -n "$CLOUDFLARE_EMAIL" ]; then
    if [ -n "$(type -P "cloudflare")" ]; then
      if __devnull cloudflare update $SET_HOSTNAME --proxy $CLOUDFLARE_PROXY; then
        CLOUDFLARE_DOMAIN="yes"
        __devnull cloudflare update "*.$SET_HOSTNAME" --proxy $CLOUDFLARE_PROXY
        __printf_blue "Successfully updated $SET_HOSTNAME in $CLOUDFLARE_DEFAULT_ZONE"
      elif __devnull cloudflare create $SET_HOSTNAME --proxy $CLOUDFLARE_PROXY; then
        CLOUDFLARE_DOMAIN="yes"
        __devnull cloudflare create "*.$SET_HOSTNAME" --proxy $CLOUDFLARE_PROXY
        __printf_blue "Created $SET_HOSTNAME for $CLOUDFLARE_DEFAULT_ZONE"
      else
        __printf_red "Failed to create record $SET_HOSTNAME for zone $CLOUDFLARE_DEFAULT_ZONE"
      fi
    fi
  fi
else
  __printf_yellow "Can no load $HOME/.config/secure/cloudflare.txt"
fi
if [ "$CLOUDFLARE_DOMAIN" = "yes" ] && [ "$CLOUDFLARE_PROXY" = "true" ]; then
  if [ -d "/etc/nginx/vhosts.d" ]; then
    cat <<EOF >"/etc/nginx/vhosts.d/$SET_HOSTNAME.$CLOUDFLARE_DEFAULT_ZONE.conf"
server {
    listen                                  80;
    server_name                             $SET_HOSTNAME.$CLOUDFLARE_DEFAULT_ZONE *.$SET_HOSTNAME.$CLOUDFLARE_DEFAULT_ZONE;
    access_log                              /var/log/nginx/access.$SET_HOSTNAME.$CLOUDFLARE_DEFAULT_ZONE.log;
    error_log                               /var/log/nginx/error.$SET_HOSTNAME.$CLOUDFLARE_DEFAULT_ZONE.log info;

  location / {
    proxy_ssl_verify                        off;
    send_timeout                            3600;
    proxy_connect_timeout                   3600;
    proxy_send_timeout                      3600;
    proxy_read_timeout                      3600;
    proxy_http_version                      1.1;
    proxy_request_buffering                 off;
    proxy_buffering                         off;
    proxy_set_header                        Host               \$host;
    proxy_set_header                        X-Real-IP          \$remote_addr;
    proxy_set_header                        X-Forwarded-Proto  \$scheme;
    proxy_set_header                        X-Forwarded-Scheme \$scheme;
    proxy_set_header                        X-Forwarded-For    \$remote_addr;
    proxy_set_header                        X-Forwarded-Port   \$server_port;
    proxy_set_header                        Upgrade            \$http_upgrade;
    proxy_set_header                        Connection         \$connection_upgrade;
    proxy_set_header                        Accept-Encoding "";
    proxy_pass                              https://$HOSTNAME;
    }
}
EOF
  fi
  unset CLOUDFLARE_DOMAIN
fi
##################################################################################################################
__printf_head "Setting up ssl certificates"
##################################################################################################################
## If using letsencrypt certificates
[ -f "$HOME/.config/myscripts/acme-cli/settings.conf" ] && . "$HOME/.config/myscripts/acme-cli/settings.conf"
le_primary_domain="$(echo "$(hostname -d 2>/dev/null | grep -- '^' || hostname -f 2>/dev/null)" | grep -E -- '.*[a-zA-Z0-9][.][a-zA-Z0-9]' | grep -- '^' || false)"
if [ -n "$le_primary_domain" ]; then
  le_certs="yes"
  le_options="--primary $le_primary_domain"
  le_domain_list="${ACME_CLI_DOMAIN_LIST:-$le_domains}"
  [ "$le_primary_domain" = "$HOSTNAME" ] || le_options=""
  if [ -f "/etc/certbot/dns.conf" ]; then
    chmod -f 600 "/etc/certbot/dns.conf"
    if [ -n "$(command -v acme-cli 2>/dev/null)" ]; then
      if [ -z "$le_domain_list" ]; then
        __printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and *.$le_primary_domain"
        __run_post acme-cli --init $le_options
      else
        __printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and all domains in var: le_domain_list"
        __run_post acme-cli --init --no-test --no-subs
      fi
    fi
  fi
  if [ -d "/etc/letsencrypt/live/$le_primary_domain" ] || [ -d "/etc/letsencrypt/live/domain" ]; then
    [ -d "/etc/letsencrypt/live/domain" ] || ln -sf "/etc/letsencrypt/live/$le_primary_domain" /etc/letsencrypt/live/domain
    find /etc/postfix /etc/httpd /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \;
    find /etc/postfix /etc/httpd /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \;
    if [ -d "/etc/cockpit/ws-certs.d" ]; then
      __devnull __rm_if_exists "/etc/cockpit/ws-certs.d"/*
      cat /etc/letsencrypt/live/domain/fullchain.pem >/etc/cockpit/ws-certs.d/1-my-cert.cert
      cat /etc/letsencrypt/live/domain/privkey.pem >/etc/cockpit/ws-certs.d/1-my-cert.key
      chmod -f 644 /etc/cockpit/ws-certs.d/1-my-cert.cert
      chmod -f 600 /etc/cockpit/ws-certs.d/1-my-cert.key
    fi
    find "/etc/postfix" "/etc/httpd" "/etc/nginx" /etc/proftpd* -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \; 2>/dev/null
    find "/etc/postfix" "/etc/httpd" "/etc/nginx" /etc/proftpd* -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \; 2>/dev/null
    if [ -d "/etc/letsencrypt/renewal-hooks/post" ]; then
      if [ ! -f "/etc/letsencrypt/renewal-hooks/post/exec.sh" ]; then
        cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/system.sh" >/dev/null
#!/usr/bin/env sh
# Insert any custom commands you want executed after a new cert or upon renewal

EOF
      fi
      cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/system.sh" >/dev/null
#!/usr/bin/env sh
cat "/etc/letsencrypt/live/domain/privkey.pem" >"/etc/ssl/certs/\$HOSTNAME.key"
cat "/etc/letsencrypt/live/domain/fullchain.pem" >"/etc/ssl/certs/\$HOSTNAME.cert"
chmod -f 600 "/etc/ssl/certs/\$HOSTNAME.key"
chmod -f 644 "/etc/ssl/certs/\$HOSTNAME.cert"
EOF

      cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/cockpit.sh" >/dev/null
#!/usr/bin/env sh
cat "/etc/letsencrypt/live/domain/privkey.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.key"
cat "/etc/letsencrypt/live/domain/fullchain.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.cert"
chmod -f 600 "/etc/cockpit/ws-certs.d/1-my-cert.key"
chmod -f 644 "/etc/cockpit/ws-certs.d/1-my-cert.cert"
systemctl is-enabled cockpit >/dev/null 2>&1 && systemctl restart cockpit >/dev/null 2>&1

EOF
      cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/nginx.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled nginx >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1

EOF

      cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/httpd.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled httpd >/dev/null 2>&1 && systemctl reload httpd >/dev/null 2>&1

EOF

      cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/postfix.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled postfix >/dev/null 2>&1 && systemctl reload postfix >/dev/null 2>&1

EOF
      if [ -d "/opt/openfire/resources/security" ]; then
        cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/openfire.sh" >/dev/null
#!/usr/bin/env sh
privkey="\$(realpath "/etc/letsencrypt/live/domain/privkey.pem")"
fullchain="\$(realpath "/etc/letsencrypt/live/domain/fullchain.pem")"
openfireSSL="/opt/openfire/resources/security/hotdeploy"
[ -d "\$openfireSSL" ] || mkdir -p "\$openfireSSL"
cat "\$fullchain" >"\$openfireSSL/casjay-social-cert.pem"
cat "\$privkey" >"\$openfireSSL/casjay-social-privkey.pem"
chown -R daemon /opt/openfire/resources/security/hotdeploy
systemctl is-enabled openfire >/dev/null 2>&1 && systemctl restart openfire >/dev/null 2>&1

EOF
      fi
      chmod +x "/etc/letsencrypt/renewal-hooks/post"/*
    fi
    __printf_blue "letsencrypt certificates have been created"
  else
    __copy_ca_certs
  fi
else
  __copy_ca_certs
fi
if [ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ]; then
  if [ -d "/usr/local/share/ca-certificate" ]; then
    cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/usr/local/share/ca-certificate/"
  elif [ -d "/etc/pki/ca-trust/source/anchors" ]; then
    cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/pki/ca-trust/source/anchors/"
  elif [ -d "/etc/pki/ca-trust/source" ]; then
    cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/pki/ca-trust/source/"
  fi
fi
[ -n "$(type -P update-ca-trust)" ] && __devnull update-ca-trust && __devnull update-ca-trust extract
[ -n "$(type -P dpkg-reconfigure)" ] && __devnull dpkg-reconfigure ca-certificates
##################################################################################################################
__printf_head "Setting up rsyncd"
##################################################################################################################
# The [backup] module requires an auth secret - generate one on first run only,
# it is never shipped in casjay-base
if [ -f "/etc/rsyncd.conf" ] && [ ! -s "/etc/rsyncd.secrets" ]; then
  printf "backup:%s\n" "$(openssl rand -base64 24 | tr -d '\n')" >"/etc/rsyncd.secrets"
  __printf_cyan "Generated rsync credentials in /etc/rsyncd.secrets"
fi
chown -f root:root "/etc/rsyncd.secrets" 2>/dev/null
chmod -f 600 "/etc/rsyncd.secrets" 2>/dev/null
##################################################################################################################
__printf_head "Setting up munin-node"
##################################################################################################################
mkdir -p "/var/log/munin"
chmod -f 777 "/var/log/munin"
__does_user_exist 'munin' && chown -Rf "munin" "/var/log/munin"
__does_group_exist "munin" && chgrp -Rf "munin" "/var/log/munin"
__does_user_exist 'munin-node' && chown -Rf "munin" "/var/log/munin-node"
__does_group_exist "munin-node" && chgrp -Rf "munin" "/var/log/munin-node"
__run_post "munin-node-configure --remove-also --shell" >/dev/null 2>/dev/null
# Plugin credentials ship as the non-functional token CHANGEME_AT_BOOTSTRAP so a
# real password is never committed - say so loudly instead of failing silently
if grep -q -- 'CHANGEME_AT_BOOTSTRAP' "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null; then
  __printf_yellow "Placeholder credentials remain in /etc/munin/plugin-conf.d/munin-node"
  __printf_yellow "Set the real passwords there, or delete the sections you do not monitor"
fi
# This file holds credentials once they are filled in - keep it off world-read
chown -f root:munin "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null
chmod -f 640 "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null
##################################################################################################################
__printf_head "Setting up tor"
##################################################################################################################
if [ -n "$(type -P tor 2>/dev/null)" ]; then
  __devnull systemctl restart tor && sleep 5
  tor_hostnames="$(find "/var/lib/tor/hidden_service" -type f -name 'hostname' 2>/dev/null | grep -- '^' || false)"
  if [ -n "$tor_hostnames" ]; then
    __devnull __rm_if_exists "/var/www/html/tor_hostname"
    for f in $tor_hostnames; do
      cat "$f" >>"/var/www/html/tor_hostname" 2>/dev/null
    done
  fi
  printf '%s\n\%s\n' "# Generate tor hostnames" "#30 * * * * root " >"/etc/cron.d/tor_hostname"
fi
##################################################################################################################
__printf_head "Setting up bind dns [named]"
##################################################################################################################
if [ -z "$(command -v named)" ]; then
  __devnull __rm_if_exists /etc/named
  __devnull __rm_if_exists /var/named
  __devnull __rm_if_exists /var/log/named
  __devnull __rm_if_exists /etc/logrotate.d/named
fi
##################################################################################################################
__printf_head "Generating default webserver for $HOSTNAME"
##################################################################################################################
if [ -z "$IS_INSTALLED_HTTPD" ] || [ -z "$IS_INSTALLED_NGINX" ]; then
  if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
    __printf_blue "Server directory already exists"
  else
    __devnull gen-nginx --config
    __devnull gen-nginx php $HOSTNAME
    if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
      __printf_green "Created server in /var/www/nginx/domains/$HOSTNAME"
    else
      __printf_red "Failed to create default server"
    fi
  fi
fi
if [ -f "/etc/httpd/conf/httpd.conf" ]; then
  sed -i 's|ServerTokens .*|ServerTokens Prod|g' "/etc/httpd/conf/httpd.conf"
fi
if [ -n "$GET_WEB_USER" ]; then
  if [ -f "/etc/nginx/nginx.conf" ]; then
    sed -i '0,/^user .*/s//user  '$GET_WEB_USER';/' "/etc/nginx/nginx.conf"
    grep -sqh -- "^user  $GET_WEB_USER" "/etc/nginx/nginx.conf" || echo "Failed to change the user in /etc/nginx/nginx.conf"
  fi
  if [ -f "/etc/php-fpm.d/www.conf" ]; then
    sed -i '0,/^user .*/s//user = '$GET_WEB_USER'/' "/etc/php-fpm.d/www.conf"
    grep -sqh -- "^user = $GET_WEB_USER" "/etc/php-fpm.d/www.conf" || echo "Failed to change the user in /etc/php-fpm.d/www.conf"
  fi
  if [ -f "/etc/httpd/conf/httpd.conf" ]; then
    sed -i '0,/^User .*/s//User '$GET_WEB_USER'/' "/etc/httpd/conf/httpd.conf"
    grep -sqh -- "^User $GET_WEB_USER" "/etc/httpd/conf/httpd.conf" || echo "Failed to change the user in /etc/httpd/conf/httpd.conf"
  fi
  for apache_dir in "/usr/local/share/httpd" "/var/www"; do
    [ -d "$apache_dir" ] && chown -Rf $GET_WEB_USER "$apache_dir"
  done
fi
if [ -n "$GET_WEB_GROUP" ]; then
  if [ -f "/etc/php-fpm.d/www.conf" ]; then
    sed -i '0,/^group .*/s//group = '$GET_WEB_GROUP'/' "/etc/php-fpm.d/www.conf"
    grep -sqh -- "^group = $GET_WEB_GROUP" "/etc/php-fpm.d/www.conf" || echo "Failed to change the group in /etc/php-fpm.d/www.conf"
  fi
  if [ -f "/etc/httpd/conf/httpd.conf" ]; then
    sed -i '0,/^Group .*/s//Group '$GET_WEB_GROUP'/' "/etc/httpd/conf/httpd.conf"
    grep -sqh -- "^Group $GET_WEB_GROUP" "/etc/httpd/conf/httpd.conf" || echo "Failed to change the group in /etc/httpd/conf/httpd.conf"
  fi
  for apache_dir in "/usr/local/share/httpd" "/var/www"; do
    [ -d "$apache_dir" ] && chgrp -Rf $GET_WEB_GROUP "$apache_dir"
  done
fi
##################################################################################################################
__printf_head "Setting up the reverse proxy for cockpit"
##################################################################################################################
if [ -d "/etc/nginx/vhosts.d" ]; then
  cat <<EOF | tee "/etc/nginx/vhosts.d/cockpit.$set_domainname.conf" >/dev/null
# reverse proxy for cockpit.$set_domainname
# upstream cockpit { server https://localhost:41443 fail_timeout=0; }

server {
  listen                                    443 ssl;
  listen                                    [::]:443 ssl;
  server_name                               cockpit.$set_domainname;
  access_log                                /var/log/nginx/access.cockpit.$set_domainname.log;
  error_log                                 /var/log/nginx/error.cockpit.$set_domainname.log info;
  keepalive_timeout                         75 75;
  client_max_body_size                      0;
  chunked_transfer_encoding                 on;
  add_header Strict-Transport-Security      "max-age=7200";
  ssl_protocols                             TLSv1.1 TLSv1.2;
  ssl_ciphers                               'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
  ssl_prefer_server_ciphers                 on;
  ssl_session_cache                         shared:SSL:10m;
  ssl_session_timeout                       1d;
  ssl_certificate                           /etc/letsencrypt/live/domain/fullchain.pem;
  ssl_certificate_key                       /etc/letsencrypt/live/domain/privkey.pem;

  location / {
    proxy_ssl_verify                        off;
    send_timeout                            3600;
    proxy_connect_timeout                   3600;
    proxy_send_timeout                      3600;
    proxy_read_timeout                      3600;
    proxy_http_version                      1.1;
    proxy_request_buffering                 off;
    proxy_buffering                         off;
    proxy_set_header                        Host               \$host;
    proxy_set_header                        X-Real-IP          \$remote_addr;
    proxy_set_header                        X-Forwarded-Proto  \$scheme;
    proxy_set_header                        X-Forwarded-Scheme \$scheme;
    proxy_set_header                        X-Forwarded-For    \$remote_addr;
    proxy_set_header                        X-Forwarded-Port   \$server_port;
    proxy_set_header                        Upgrade            \$http_upgrade;
    proxy_set_header                        Connection         \$connection_upgrade;
    proxy_set_header                        Accept-Encoding "";
    proxy_redirect                          http:// https://;
    proxy_pass                              https://localhost:41443;
    }
}

EOF
fi
##################################################################################################################
__printf_head "Creating directories"
##################################################################################################################
mkdir -p "/mnt/backups" "/var/www/html/.well-known" "/etc/letsencrypt/live"
echo "" >>/etc/fstab
if [ -n "$IS_NETWORK_INTERNAL" ] && __devnull ping -q -W 1 -c 2 -t 1 10.0.254.1; then
  echo "10.0.254.1:/mnt/Volume_1/backups         /mnt/backups                 nfs defaults,rw 0 0" >>/etc/fstab
  echo "10.0.254.1:/etc/letsencrypt              /etc/letsencrypt             nfs defaults,rw 0 0" >>/etc/fstab
  echo "10.0.254.1:/var/www/html/.well-known     /var/www/html/.well-known    nfs defaults,rw 0 0" >>/etc/fstab
fi
mount -a
##################################################################################################################
__printf_head "Installing custom system configs"
##################################################################################################################
__run_post "systemmgr install $SYSTEMMGR_CONFIGS"
##################################################################################################################
__printf_head "Installing custom dotfiles"
##################################################################################################################
__run_post "dfmgr update $DFMGR_CONFIGS"
##################################################################################################################
__printf_head "Updating personal dotfiles"
##################################################################################################################
if [ -x "$HOME/.local/dotfiles/personal/install.sh" ]; then
  __run_external "$HOME/.local/dotfiles/personal/install.sh"
fi
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
##################################################################################################################
if [ "$SYSTEM_TYPE" = "vpn" ]; then
  __printf_head "Disabling services: httpd,nginx"
  __system_service_disable httpd
  __system_service_disable nginx
fi
if [ "$SYSTEM_TYPE" = "mail" ]; then
  if [ -x "$HOME/Projects/github/dfprivate/email/install.sh" ]; then
    __printf_head "Running installer script for email server"
    eval "$HOME/Projects/github/dfprivate/email/install.sh" >/dev/null 2>&1
  fi
elif [ "$SYSTEM_TYPE" = "db" ] || [ "$set_domainname" = "sqldb.us" ]; then
  if [ -x "$HOME/Projects/github/dfprivate/sql/install.sh" ]; then
    __printf_head "Running installer script for database server"
    eval "$HOME/Projects/github/dfprivate/sql/install.sh" >/dev/null 2>&1
  fi
elif [ "$SYSTEM_TYPE" = "dns" ] || [ "$set_domainname" = "casjaydns.com" ]; then
  if [ -x "$HOME/Projects/github/dfprivate/dns/install.sh" ]; then
    __printf_head "Running installer script for dns server"
    eval "$HOME/Projects/github/dfprivate/dns/install.sh" >/dev/null 2>&1
  fi
fi
##################################################################################################################
__printf_head "Enabling services"
##################################################################################################################
for service_enable in $SERVICES_ENABLE; do
  if [ -n "$service_enable" ] && __system_service_exists "$service_enable"; then
    __system_service_enable $service_enable
    systemctl restart $service_enable >/dev/null 2>&1
  fi
done
##################################################################################################################
__printf_head "Disabling services"
##################################################################################################################
for service_disable in $SERVICES_DISABLE; do
  if [ -n "$service_disable" ] && __system_service_exists "$service_disable"; then
    __system_service_disable $service_disable
  fi
done
##################################################################################################################
__printf_head "Setting up docker"
##################################################################################################################
if [ -n "$(type -P dockermgr 2>/dev/null)" ]; then
  __system_service_enable docker
  __devnull systemctl restart docker
  __run_post dockermgr init && __devnull dockermgr init
fi
if [ -n "$(type -P composemgr 2>/dev/null)" ]; then
  __run_post composemgr --config && __devnull composemgr --env
fi
##################################################################################################################
__printf_head "Disabling dnsmasq"
##################################################################################################################
__system_service_disable dnsmasq
__devnull sed -i 's/^dns=dnsmasq/#&/' /etc/NetworkManager/NetworkManager.conf
__devnull killall dnsmasq
##################################################################################################################
__printf_head "Fixing ip address"
##################################################################################################################
/root/bin/changeip.sh >/dev/null 2>&1
##################################################################################################################
__printf_head "Cleaning up"
##################################################################################################################
[ -f "/etc/yum/pluginconf.d/subscription-manager.conf" ] && echo "" >"/etc/yum/pluginconf.d/subscription-manager.conf"
find "/etc" "/usr" "/var" -iname '*.rpmnew' -exec rm -Rf {} \; >/dev/null 2>&1
find "/etc" "/usr" "/var" -iname '*.rpmsave' -exec rm -Rf {} \; >/dev/null 2>&1
__devnull rm -Rf /tmp/*.tar "/tmp/dotfiles" "$CONFIG_TEMP_DIR"
__devnull __retrieve_repo_file
history -c && history -w
##################################################################################################################
__printf_head "Installer version: $(__retrieve_version_file)"
##################################################################################################################
mkdir -p "/etc/casjaysdev/updates/versions"
echo "$VERSION" >"/etc/casjaysdev/updates/versions/configs.txt"
echo "$(date +'Installed on %y-%m-%d at %H:%M')" >"/etc/casjaysdev/updates/versions/installed.txt"
echo "Installed on $(date +'%Y-%m-%d at %H:%M %Z')" >"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/configs.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/installed.txt"
##################################################################################################################
__printf_head "Finished configuring $HOSTNAME"
echo ""
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
# end

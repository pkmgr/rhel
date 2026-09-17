#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# pkmgr-sync.sh — generate per-distro scripts/min.sh from rhel source
# rhel/scripts/min.sh is the source of truth; re-run whenever it changes.
# Usage: ./pkmgr-sync.sh [distro...]   (omit to sync all distros)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# Support running from the parent collection dir or from inside rhel/
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$_SCRIPT_DIR/rhel" ]; then
    BASEDIR="$_SCRIPT_DIR"
else
    # Script is inside a distro repo (e.g. rhel/) — go up one level
    BASEDIR="$(cd "$_SCRIPT_DIR/.." && pwd)"
fi
unset _SCRIPT_DIR
SRC="$BASEDIR/rhel/scripts/min.sh"
ALL_DISTROS=(debian ubuntu fedora raspbian arch alpine)

[ -f "$SRC" ] || { echo "ERROR: source not found: $SRC" >&2; exit 1; }

# Resolve target distro list from args or default to all
if [ "$#" -gt 0 ]; then
    DISTROS=("$@")
else
    DISTROS=("${ALL_DISTROS[@]}")
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# pkg_name DISTRO PKG  — emit distro-specific package name; "SKIP" means omit
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
pkg_name() {
    local distro="$1" pkg="$2"
    case "$distro" in
        debian|ubuntu|raspbian)
            case "$pkg" in
                httpd)                      echo apache2 ;;
                mod_fcgid)                  echo libapache2-mod-fcgid ;;
                mod_geoip)                  echo SKIP ;;
                mod_http2)                  echo SKIP ;;
                mod_maxminddb)              echo SKIP ;;
                mod_perl)                   echo libapache2-mod-perl2 ;;
                mod_ssl)                    echo SKIP ;;
                mod_wsgi)                   echo libapache2-mod-wsgi-py3 ;;
                mod_proxy_html)             echo SKIP ;;
                mod_proxy_uwsgi)            echo libapache2-mod-proxy-uwsgi ;;
                bind)                       echo bind9 ;;
                bind-utils)                 echo dnsutils ;;
                cronie)                     echo cron ;;
                cronie-noanacron)           echo SKIP ;;
                crontabs)                   echo cron ;;
                initscripts)                echo SKIP ;;
                redhat-lsb)                 echo lsb-release ;;
                grub2-tools)                echo grub-pc ;;
                grub2-tools-extra)          echo SKIP ;;
                grubby)                     echo SKIP ;;
                deltarpm)                   echo SKIP ;;
                rootfiles)                  echo SKIP ;;
                yum-utils)                  echo apt-utils ;;
                biosdevname)                echo SKIP ;;
                harfbuzz)                   echo libharfbuzz0b ;;
                gnupg2)                     echo gnupg2 ;;
                gnutls)                     echo libgnutls30 ;;
                readline)                   echo libreadline-dev ;;
                sqlite)                     echo sqlite3 ;;
                oddjob-mkhomedir)           echo libpam-mkhomedir ;;
                perl-CPAN|perl-CPAN-Meta)   echo perl ;;
                perl-DBD-Pg)                echo libdbd-pg-perl ;;
                perl-DBD-MySQL)             echo libdbd-mysql-perl ;;
                perl-DBD-SQLite)            echo libdbd-sqlite3-perl ;;
                perl-DBD-MariaDB)           echo libdbd-mariadb-perl ;;
                perl-DBD-Firebird)          echo SKIP ;;
                python3-certbot-dns-rfc2136) echo python3-certbot-dns-rfc2136 ;;
                python3-neovim)             echo python3-pynvim ;;
                python3-josepy)             echo SKIP ;;
                python3-parsedatetime|python3-pbr|python3-pyasn1|python3-pyrfc3339|python3-pysocks|python3-six) echo SKIP ;;
                incus-selinux|incus-tools)  echo SKIP ;;
                basesystem)                 echo base-files ;;
                gc)                         echo libgc-dev ;;
                cockpit-bridge|cockpit-system|cockpit-ws) echo SKIP ;;
                postfix-pcre)               echo SKIP ;;
                glibc-langpack-en)          echo SKIP ;;
                kernel-ml-modules|kernel-ml-modules-extra|kernel-lt-modules|kernel-lt-modules-extra) echo SKIP ;;
                cracklib)                   echo libcrack2 ;;
                cracklib-dicts)             echo cracklib-runtime ;;
                ctags)                      echo universal-ctags ;;
                man-pages)                  echo manpages ;;
                ncurses)                    echo ncurses-base ;;
                ncurses-libs)               echo libncurses6 ;;
                pinentry)                   echo pinentry-curses ;;
                xz)                         echo xz-utils ;;
                xz-libs)                    echo liblzma5 ;;
                zlib|zlib-ng-compat)        echo zlib1g ;;
                vim-enhanced)               echo vim ;;
                shadow-utils)               echo passwd ;;
                firewalld)                  echo SKIP ;;
                util-linux-core)            echo util-linux ;;
                mlocate)                    echo plocate ;;
                *)                          echo "$pkg" ;;
            esac
            ;;
        fedora)
            case "$pkg" in
                cronie-noanacron)           echo SKIP ;;
                redhat-lsb)                 echo SKIP ;;
                deltarpm)                   echo SKIP ;;
                yum-utils)                  echo dnf-utils ;;
                perl-DBD-Firebird)          echo SKIP ;;
                python3-josepy)             echo SKIP ;;
                python3-neovim)             echo python3-neovim ;;
                basesystem)                 echo SKIP ;;
                wget)                       echo wget2-wget ;;
                mlocate)                    echo plocate ;;
                zlib)                       echo zlib-ng-compat ;;
                incus-selinux)              echo SKIP ;;
                cockpit-bridge|cockpit-system|cockpit-ws) echo SKIP ;;
                glibc-langpack-en)          echo SKIP ;;
                kernel-ml-modules|kernel-ml-modules-extra|kernel-lt-modules|kernel-lt-modules-extra) echo SKIP ;;
                *)                          echo "$pkg" ;;
            esac
            ;;
        arch)
            case "$pkg" in
                httpd)                      echo apache ;;
                mod_fcgid)                  echo SKIP ;;
                cracklib-dicts)             echo SKIP ;;
                hostname)                   echo inetutils ;;
                ncurses-base|ncurses-libs)  echo ncurses ;;
                openssh-server)             echo openssh ;;
                xz-libs)                    echo xz ;;
                mrtg)                       echo SKIP ;;
                rsyslog)                    echo SKIP ;;
                mod_geoip)                  echo SKIP ;;
                mod_http2)                  echo SKIP ;;
                mod_maxminddb)              echo SKIP ;;
                mod_perl|mod_ssl|mod_wsgi)  echo SKIP ;;
                mod_proxy_html)             echo SKIP ;;
                mod_proxy_uwsgi)            echo SKIP ;;
                bind|bind-utils)            echo bind ;;
                cronie-noanacron)           echo SKIP ;;
                crontabs)                   echo SKIP ;;
                initscripts)                echo SKIP ;;
                redhat-lsb)                 echo lsb-release ;;
                grub2-tools)                echo grub ;;
                grub2-tools-extra)          echo SKIP ;;
                grubby)                     echo SKIP ;;
                deltarpm)                   echo SKIP ;;
                rootfiles)                  echo SKIP ;;
                yum-utils)                  echo pacman-contrib ;;
                biosdevname)                echo SKIP ;;
                gnupg2)                     echo gnupg ;;
                shadow-utils)               echo shadow ;;
                vim-enhanced)               echo vim ;;
                util-linux-core)            echo util-linux ;;
                mlocate)                    echo plocate ;;
                oddjob-mkhomedir)           echo SKIP ;;
                perl-CPAN|perl-CPAN-Meta)   echo perl ;;
                perl-DBD-Pg)                echo perl-dbd-pg ;;
                perl-DBD-MySQL)             echo perl-dbd-mysql ;;
                perl-DBD-SQLite)            echo perl-dbd-sqlite ;;
                perl-DBD-MariaDB)           echo perl-dbd-mariadb ;;
                perl-DBD-Firebird)          echo SKIP ;;
                python3-certbot-dns-rfc2136) echo certbot-dns-rfc2136 ;;
                python3-configargparse)     echo python-configargparse ;;
                python3-cryptography)       echo python-cryptography ;;
                python3-josepy)             echo SKIP ;;
                python3-future)             echo SKIP ;;
                python3-idna)               echo python-idna ;;
                python3-neovim)             echo python-pynvim ;;
                python3-parsedatetime|python3-pbr|python3-pyasn1|python3-pyrfc3339|python3-pysocks|python3-six) echo SKIP ;;
                python3-pip)                echo python-pip ;;
                python3-psutil)             echo python-psutil ;;
                python3-requests)           echo python-requests ;;
                python3-virtualenv)         echo python-virtualenv ;;
                php-common|php-pdo)         echo php ;;
                incus-selinux|incus-tools)  echo SKIP ;;
                docker-ce)                  echo docker ;;
                basesystem)                 echo base ;;
                cockpit-bridge|cockpit-system|cockpit-ws|cockpit-packagekit|cockpit-storaged) echo SKIP ;;
                munin|munin-common|munin-node) echo SKIP ;;
                postfix-pcre)               echo SKIP ;;
                webalizer)                  echo SKIP ;;
                glibc-langpack-en)          echo SKIP ;;
                kernel-ml-modules|kernel-ml-modules-extra|kernel-lt-modules|kernel-lt-modules-extra) echo SKIP ;;
                *)                          echo "$pkg" ;;
            esac
            ;;
        alpine)
            case "$pkg" in
                httpd)                      echo apache2 ;;
                cracklib-dicts)             echo cracklib-words ;;
                hostname)                   echo SKIP ;;
                ncurses-base)               echo ncurses ;;
                cowsay)                     echo SKIP ;;
                rkhunter)                   echo SKIP ;;
                symlinks)                   echo SKIP ;;
                mod_fcgid)                  echo SKIP ;;
                mod_geoip|mod_http2|mod_maxminddb|mod_perl|mod_ssl|mod_wsgi|mod_proxy_html|mod_proxy_uwsgi) echo SKIP ;;
                bind)                       echo bind ;;
                bind-utils)                 echo bind-tools ;;
                cronie-noanacron)           echo SKIP ;;
                crontabs)                   echo SKIP ;;
                initscripts)                echo SKIP ;;
                redhat-lsb)                 echo SKIP ;;
                grub2-tools)                echo grub ;;
                grub2-tools-extra)          echo SKIP ;;
                grubby)                     echo SKIP ;;
                deltarpm)                   echo SKIP ;;
                rootfiles)                  echo SKIP ;;
                yum-utils)                  echo SKIP ;;
                biosdevname)                echo SKIP ;;
                gnupg2)                     echo gnupg ;;
                shadow-utils)               echo shadow ;;
                vim-enhanced)               echo vim ;;
                util-linux-core)            echo util-linux ;;
                firewalld)                  echo SKIP ;;
                oddjob-mkhomedir)           echo SKIP ;;
                perl-CPAN|perl-CPAN-Meta)   echo perl ;;
                perl-DBD-Pg)                echo perl-dbd-pg ;;
                perl-DBD-MySQL)             echo perl-dbd-mysql ;;
                perl-DBD-SQLite|perl-DBD-MariaDB|perl-DBD-Firebird) echo SKIP ;;
                python3-certbot-dns-rfc2136) echo SKIP ;;
                python3-configargparse)     echo py3-configargparse ;;
                python3-cryptography)       echo py3-cryptography ;;
                python3-josepy)             echo SKIP ;;
                python3-future)             echo SKIP ;;
                python3-idna)               echo py3-idna ;;
                python3-neovim)             echo py3-pynvim ;;
                python3-parsedatetime|python3-pbr|python3-pyasn1|python3-pyrfc3339|python3-pysocks|python3-six) echo SKIP ;;
                python3-pip)                echo py3-pip ;;
                python3-psutil)             echo py3-psutil ;;
                python3-requests)           echo py3-requests ;;
                python3-virtualenv)         echo py3-virtualenv ;;
                php)                        echo SKIP ;;
                php-cli)                    echo SKIP ;;
                php-common)                 echo SKIP ;;
                php-fpm)                    echo SKIP ;;
                php-gd)                     echo SKIP ;;
                php-gmp)                    echo SKIP ;;
                php-intl)                   echo SKIP ;;
                php-mbstring)               echo SKIP ;;
                php-mysqlnd)                echo SKIP ;;
                php-pdo)                    echo SKIP ;;
                php-pgsql)                  echo SKIP ;;
                php-xml)                    echo SKIP ;;
                incus|incus-selinux|incus-tools) echo SKIP ;;
                docker-ce)                  echo docker ;;
                basesystem)                 echo alpine-base ;;
                cockpit|cockpit-packagekit|cockpit-storaged|cockpit-bridge|cockpit-system|cockpit-ws) echo SKIP ;;
                munin-common|munin-node)    echo SKIP ;;
                postfix-pcre)               echo SKIP ;;
                fortune-mod|webalizer)      echo SKIP ;;
                glibc-langpack-en)          echo SKIP ;;
                kernel-ml-modules|kernel-ml-modules-extra|kernel-lt-modules|kernel-lt-modules-extra) echo SKIP ;;
                *)                          echo "$pkg" ;;
            esac
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# distro_script_os DISTRO — return SCRIPT_OS value
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
distro_script_os() {
    case "$1" in
        debian)   echo "Debian" ;;
        ubuntu)   echo "Ubuntu" ;;
        fedora)   echo "Fedora" ;;
        raspbian) echo "Raspbian" ;;
        arch)     echo "Arch" ;;
        alpine)   echo "Alpine" ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# distro_id_check DISTRO — return grep pattern for /etc/os-release check
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
distro_id_check() {
    case "$1" in
        debian)   echo "debian" ;;
        ubuntu)   echo "ubuntu" ;;
        fedora)   echo "fedora" ;;
        raspbian) echo "raspbian" ;;
        arch)     echo "arch" ;;
        alpine)   echo "alpine" ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Early bootstrap block (before functions are loaded) per distro
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
early_bootstrap() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'EARLY'
if [ ! -d "/etc/casjaysdev" ]; then
	if apt-get update -q && apt-get upgrade -y -q; then
		echo "Rebooting your system: Please rerun this script after reboot"
		mkdir -p "/etc/casjaysdev"
		sleep 20 && reboot
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! type -P ifconfig >/dev/null 2>&1 && ! type -P hostname >/dev/null 2>&1; then
	echo "Installing net-tools package"
	apt-get install -y -q net-tools
fi
for pkg in sudo git curl wget; do
	command -v $pkg &>/dev/null || { echo "Installing $pkg" && apt-get install -y -q $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
EARLY
            ;;
        fedora)
            cat <<'EARLY'
if [ ! -d "/etc/casjaysdev" ]; then
	if dnf makecache && dnf update -y; then
		echo "Rebooting your system: Please rerun this script after reboot"
		mkdir -p "/etc/casjaysdev"
		sleep 20 && reboot
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! type -P ifconfig >/dev/null 2>&1 && ! type -P hostname >/dev/null 2>&1; then
	echo "Installing net-tools package"
	dnf install -y net-tools -q
fi
for pkg in sudo git curl wget; do
	command -v $pkg &>/dev/null || { echo "Installing $pkg" && dnf install -y -q $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
EARLY
            ;;
        arch)
            cat <<'EARLY'
if [ ! -d "/etc/casjaysdev" ]; then
	if pacman -Syu --noconfirm; then
		echo "Rebooting your system: Please rerun this script after reboot"
		mkdir -p "/etc/casjaysdev"
		sleep 20 && reboot
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! type -P ifconfig >/dev/null 2>&1 && ! type -P hostname >/dev/null 2>&1; then
	echo "Installing net-tools package"
	pacman -S --noconfirm --needed net-tools
fi
for pkg in sudo git curl wget; do
	command -v $pkg &>/dev/null || { echo "Installing $pkg" && pacman -S --noconfirm --needed $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
EARLY
            ;;
        alpine)
            cat <<'EARLY'
if [ ! -d "/etc/casjaysdev" ]; then
	if apk update && apk upgrade; then
		echo "Rebooting your system: Please rerun this script after reboot"
		mkdir -p "/etc/casjaysdev"
		sleep 20 && reboot
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! type -P ifconfig >/dev/null 2>&1 && ! type -P hostname >/dev/null 2>&1; then
	echo "Installing net-tools package"
	apk add --no-cache net-tools
fi
for pkg in sudo git curl wget; do
	command -v $pkg &>/dev/null || { echo "Installing $pkg" && apk add --no-cache $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
EARLY
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Function body replacements per distro
# Each function: name + body (not including the closing })
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# __dnf_yum replacement (only needed on RHEL-family; others use native pkg mgr)
func_dnf_yum_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            echo '	DEBIAN_FRONTEND=noninteractive apt-get -y -q "$@"'
            ;;
        fedora)
            echo '	local opts="--allowerasing --nobest --skip-broken"'
            echo '	dnf $opts "$@"'
            ;;
        arch)
            echo '	pacman --noconfirm --needed "$@"'
            ;;
        alpine)
            echo '	apk "$@"'
            ;;
    esac
}

# __yum replacement
func_yum_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian) echo '	DEBIAN_FRONTEND=noninteractive apt-get "$@" &>/dev/null || return 1' ;;
        fedora)                 echo '	dnf "$@" &>/dev/null || return 1' ;;
        arch)                   echo '	pacman --noconfirm "$@" &>/dev/null || return 1' ;;
        alpine)                 echo '	apk "$@" &>/dev/null || return 1' ;;
    esac
}

# backup_repo_files replacement
func_backup_repo_files_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian) echo '	cp -Rf "/etc/apt/sources.list.d/." "$BACKUP_DIR" 2>/dev/null || return 0' ;;
        fedora)                 echo '	cp -Rf "/etc/yum.repos.d/." "$BACKUP_DIR" 2>/dev/null || return 0' ;;
        arch)                   echo '	return 0' ;;
        alpine)                 echo '	cp -Rf "/etc/apk/." "$BACKUP_DIR" 2>/dev/null || return 0' ;;
    esac
}

# rm_repo_files replacement
func_rm_repo_files_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian) echo '	[ "${1:-$APT_DELETE}" = "yes" ] && rm -Rf "/etc/apt/sources.list.d"/* &>/dev/null || return 0' ;;
        fedora)                 echo '	[ "${1:-$YUM_DELETE}" = "yes" ] && rm -Rf "/etc/yum.repos.d"/* &>/dev/null || return 0' ;;
        arch)                   echo '	return 0' ;;
        alpine)                 echo '	return 0' ;;
    esac
}

# test_pkg replacement
func_test_pkg_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			__printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
BODY
            ;;
        fedora)
            cat <<'BODY'
	for pkg in "$@"; do
		if rpm -q "$pkg" >/dev/null 2>&1; then
			__printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
BODY
            ;;
        arch)
            cat <<'BODY'
	for pkg in "$@"; do
		if pacman -Q "$pkg" >/dev/null 2>&1; then
			__printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
BODY
            ;;
        alpine)
            cat <<'BODY'
	for pkg in "$@"; do
		if apk info -e "$pkg" >/dev/null 2>&1; then
			__printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
BODY
            ;;
    esac
}

# remove_pkg replacement
func_remove_pkg_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
	local pkg=""
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			__execute "DEBIAN_FRONTEND=noninteractive apt-get remove -y -q $pkg" "Removing: $pkg"
		fi
	done
	return 0
BODY
            ;;
        fedora)
            cat <<'BODY'
	local pkg=""
	for pkg in "$@"; do
		if rpm -q "$pkg" >/dev/null 2>&1; then
			__execute "rpm -ev --nodeps $pkg" "Removing: $pkg"
		fi
	done
	return 0
BODY
            ;;
        arch)
            cat <<'BODY'
	local pkg=""
	for pkg in "$@"; do
		if pacman -Q "$pkg" >/dev/null 2>&1; then
			__execute "pacman -R --noconfirm $pkg" "Removing: $pkg"
		fi
	done
	return 0
BODY
            ;;
        alpine)
            cat <<'BODY'
	local pkg=""
	for pkg in "$@"; do
		if apk info -e "$pkg" >/dev/null 2>&1; then
			__execute "apk del $pkg" "Removing: $pkg"
		fi
	done
	return 0
BODY
            ;;
    esac
}

# install_pkg replacement
func_install_pkg_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
	local statusCode=0
	if __test_pkg "$*"; then
		__execute "DEBIAN_FRONTEND=noninteractive apt-get install -y -q $*" "Installing: $*"
		__test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
BODY
            ;;
        fedora)
            cat <<'BODY'
	local statusCode=0
	local opts="--allowerasing --nobest --skip-broken"
	if __test_pkg "$*"; then
		__execute "dnf install -q -y $* $opts" "Installing: $*"
		__test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
BODY
            ;;
        arch)
            cat <<'BODY'
	local statusCode=0
	if __test_pkg "$*"; then
		__execute "pacman -S --noconfirm --needed $*" "Installing: $*"
		__test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
BODY
            ;;
        alpine)
            cat <<'BODY'
	local statusCode=0
	if __test_pkg "$*"; then
		__execute "apk add --no-cache $*" "Installing: $*"
		__test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
BODY
            ;;
    esac
}

# run_init_check replacement
func_run_init_check_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
	if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
		if ! git -C /usr/local/share/CasjaysDev/scripts pull -q; then
			rm -Rf "/usr/local/share/CasjaysDev/scripts"
			git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
		fi
	fi
	DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null || true
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q &>/dev/null || true
BODY
            ;;
        fedora)
            cat <<'BODY'
	if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
		if ! git -C /usr/local/share/CasjaysDev/scripts pull -q; then
			rm -Rf "/usr/local/share/CasjaysDev/scripts"
			git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
		fi
	fi
	dnf clean all &>/dev/null || true
BODY
            ;;
        arch)
            cat <<'BODY'
	if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
		if ! git -C /usr/local/share/CasjaysDev/scripts pull -q; then
			rm -Rf "/usr/local/share/CasjaysDev/scripts"
			git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
		fi
	fi
	pacman -Sy &>/dev/null || true
BODY
            ;;
        alpine)
            cat <<'BODY'
	if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
		if ! git -C /usr/local/share/CasjaysDev/scripts pull -q; then
			rm -Rf "/usr/local/share/CasjaysDev/scripts"
			git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
		fi
	fi
	apk update &>/dev/null || true
BODY
            ;;
    esac
}

# retrieve_repo_file replacement
func_retrieve_repo_file_body() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
	local statusCode="0"
	# Add Docker apt repository if not already present
	if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then
		printf '%b\n' "${YELLOW}Adding Docker apt repository${NC}"
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q ca-certificates curl gnupg lsb-release &>/dev/null
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" \
			| gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
		chmod a+r /etc/apt/keyrings/docker.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
			| tee /etc/apt/sources.list.d/docker.list >/dev/null
	fi
	DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null || statusCode=1
	[ "$statusCode" -ne 0 ] || printf '%b\n' "${YELLOW}Done updating repos${NC}"
	return $statusCode
BODY
            ;;
        fedora)
            cat <<'BODY'
	local statusCode="0"
	# Add Docker dnf repository if not already present
	if [ ! -f "/etc/yum.repos.d/docker-ce.repo" ]; then
		printf '%b\n' "${YELLOW}Adding Docker dnf repository${NC}"
		dnf -y install dnf-plugins-core &>/dev/null
		dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo &>/dev/null
	fi
	dnf makecache &>/dev/null || statusCode=1
	[ "$statusCode" -ne 0 ] || printf '%b\n' "${YELLOW}Done updating repos${NC}"
	return $statusCode
BODY
            ;;
        arch)
            cat <<'BODY'
	local statusCode="0"
	# Arch uses standard pacman repos; docker is in the extra/community repo
	pacman -Sy &>/dev/null || statusCode=1
	[ "$statusCode" -ne 0 ] || printf '%b\n' "${YELLOW}Done updating repos${NC}"
	return $statusCode
BODY
            ;;
        alpine)
            cat <<'BODY'
	local statusCode="0"
	# Add community and edge repos if not present
	if ! grep -q '^http.*community' /etc/apk/repositories 2>/dev/null; then
		ALPINE_VER="$(cut -d. -f1,2 /etc/alpine-release 2>/dev/null)"
		echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community" >>/etc/apk/repositories
	fi
	apk update &>/dev/null || statusCode=1
	[ "$statusCode" -ne 0 ] || printf '%b\n' "${YELLOW}Done updating repos${NC}"
	return $statusCode
BODY
            ;;
    esac
}

# disable_selinux / detect_selinux replacement (stub for non-RHEL)
func_disable_selinux_body() {
    local distro="$1"
    case "$distro" in
        fedora)
            # Fedora has selinux; keep same logic
            cat <<'BODY'
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
BODY
            ;;
        debian|ubuntu|raspbian|arch|alpine)
            echo '	__printf_blue "SELinux not applicable on this distro — skipping"'
            ;;
    esac
}

func_detect_selinux_body() {
    local distro="$1"
    case "$distro" in
        fedora)
            cat <<'BODY'
	if [ -f "/etc/selinux/config" ]; then
		grep -s 'SELINUX=' "/etc/selinux/config" | grep -q 'enabled' || return 1
	elif type -P selinuxenabled >/dev/null 2>&1; then
		selinuxenabled && return 1 || return 0
	else
		return 0
	fi
BODY
            ;;
        debian|ubuntu|raspbian|arch|alpine)
            echo '	return 0'
            ;;
    esac
}

# kernel-ml/lt stubs for non-RHEL
func_kernel_ml_body() {
    echo '	__printf_blue "Custom kernel not applicable on this distro — using distribution default"'
    echo '	return 0'
}
func_kernel_lt_body() {
    echo '	__printf_blue "Custom kernel not applicable on this distro — using distribution default"'
    echo '	return 0'
}

# __create_account: replace wheel with sudo for debian family
func_create_account_body_debian() {
    cat <<'BODY'
	local user_spec="$1" uid="$2" is_admin="${3:-no}"
	local user="" pass="" existing_uid=""
	user="${user_spec%%:*}"
	pass="${user_spec#*:}"
	[ "$user" = "$pass" ] && pass=""
	if [ -z "$pass" ] || [ "$pass" = "random" ]; then
		pass="$(__generate_password)"
	fi
	if __does_user_exist "$user"; then
		__printf_yellow "User $user already exists - updating password only"
		echo "$user:$pass" | __devnull chpasswd
	else
		existing_uid="$(getent passwd "$uid" | awk -F':' '{print $1}')"
		if [ -n "$existing_uid" ]; then
			__printf_yellow "UID $uid already in use by $existing_uid - skipping $user"
			return 1
		fi
		__devnull groupadd -g "$uid" "$user"
		__devnull useradd -u "$uid" -g "$uid" -m -s /bin/bash "$user"
		echo "$user:$pass" | __devnull chpasswd
	fi
	if [ "$is_admin" = "yes" ]; then
		__devnull usermod -aG sudo "$user"
		if [ -d "/etc/sudoers.d" ]; then
			echo "$user ALL=(ALL) ALL" >"/etc/sudoers.d/$user"
			chmod 440 "/etc/sudoers.d/$user"
		fi
	fi
	SETUP_ACCOUNT_CREDS+=("$user:$pass")
	__printf_green "Account ready: $user (uid $uid)"
BODY
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# firewall_section DISTRO — emit the firewall configuration section
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
firewall_section() {
    local distro="$1"
    cat <<'HDR'
##################################################################################################################
HDR
    echo "__printf_head \"Configuring the firewall\""
    echo "##################################################################################################################"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'FIREWALL'
__devnull apt-get install -y -q ufw
__devnull ufw --force reset
__devnull ufw default deny incoming
__devnull ufw default allow outgoing
__devnull ufw allow ssh
__devnull ufw allow http
__devnull ufw allow https
__devnull ufw allow 60000:61000/udp
__devnull ufw --force enable
FIREWALL
            ;;
        fedora)
            cat <<'FIREWALL'
__devnull systemctl start firewalld
__devnull firewall-cmd --permanent --zone=public --add-service=ssh
if __devnull firewall-cmd --info-service=mosh; then
	__devnull firewall-cmd --permanent --zone=public --add-service=mosh
else
	__devnull firewall-cmd --permanent --zone=public --add-port=60000-61000/udp
fi
__devnull firewall-cmd --permanent --zone=public --add-service=http
__devnull firewall-cmd --permanent --zone=public --add-service=https
__devnull firewall-cmd --permanent --zone=public --remove-service=cockpit
# docker-ce auto-manages its own "docker" firewalld zone for docker0 at
# runtime (D-Bus, target=ACCEPT) - a manual --change-interface=docker0
# binding here collides with it (ZONE_CONFLICT: interface already bound
# to a zone), so it has been dropped. incus does NOT self-manage a zone
# (ipv4.firewall/ipv6.firewall=false on its networks - it deliberately
# leaves firewalling to the host), so incusbr0 keeps its explicit bind.
if __devnull command -v incus; then
	__devnull firewall-cmd --permanent --zone=trusted --change-interface=incusbr0
fi
__devnull firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p icmp -s 0.0.0.0/0 -d 0.0.0.0/0 -j ACCEPT
__devnull firewall-cmd --reload
__devnull systemctl stop firewalld
FIREWALL
            ;;
        arch)
            cat <<'FIREWALL'
if type -P ufw >/dev/null 2>&1; then
	__devnull ufw --force reset
	__devnull ufw default deny incoming
	__devnull ufw default allow outgoing
	__devnull ufw allow ssh
	__devnull ufw allow http
	__devnull ufw allow https
	__devnull ufw allow 60000:61000/udp
	__devnull ufw --force enable
else
	__devnull nft flush ruleset
	__devnull nft add table inet filter
	__devnull nft add chain inet filter input '{ type filter hook input priority 0; policy drop; }'
	__devnull nft add rule inet filter input ct state established,related accept
	__devnull nft add rule inet filter input iif lo accept
	__devnull nft add rule inet filter input ip protocol icmp accept
	__devnull nft add rule inet filter input tcp dport '{22,80,443}' accept
	__devnull nft add rule inet filter input udp dport '60000-61000' accept
fi
FIREWALL
            ;;
        alpine)
            cat <<'FIREWALL'
__devnull apk add --no-cache iptables
__devnull rc-update add iptables default 2>/dev/null || true
# Allow SSH, HTTP, HTTPS, and mosh ports
iptables -F INPUT 2>/dev/null || true
iptables -P INPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
__devnull rc-service iptables save 2>/dev/null || true
FIREWALL
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# incus_section DISTRO — emit the incus installation section
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
incus_section() {
    local distro="$1"
    cat <<'HDR'
##################################################################################################################
HDR
    echo "__printf_head \"Installing incus\""
    echo "##################################################################################################################"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'INCUS'
incus_setup_failed="no"
# Install incus via upstream apt repository
if ! command -v incus >/dev/null 2>&1; then
	if ! grep -qsi 'zabbly' /etc/apt/sources.list.d/*.list 2>/dev/null; then
		__printf_green "Enabling the incus repository"
		curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg 2>/dev/null
		echo "deb [signed-by=/etc/apt/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
			| tee /etc/apt/sources.list.d/zabbly-incus-stable.list >/dev/null
		DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null
	fi
	__install_pkg incus
fi
echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
if __system_service_exists "incus"; then
	__devnull systemctl start "incus"
	__devnull systemctl restart "incus"
	__devnull systemctl enable --now incus || incus_setup_failed="yes"
else
	incus_setup_failed=yes
fi
[ -n "$(find /var/lib/incus -mindepth 1 2>/dev/null)" ] || incus_setup_failed="yes"
if [ "$incus_setup_failed" = "no" ]; then
	if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
		__devnull incus network set incusbr0 ipv4.firewall false
		__devnull incus network set incusbr0 ipv6.firewall false
		__devnull systemctl restart incus
		__printf_blue "incus has been initialized"
		unset incus_setup_failed
	else
		incus_setup_failed="yes"
	fi
fi
INCUS
            ;;
        fedora)
            cat <<'INCUS'
incus_setup_failed="no"
if ! grep -Rqsi 'copr.*incus' '/etc/yum.repos.d'; then
	__printf_green "Enabling the dnf incus repo"
	__devnull dnf -y copr enable neil/incus
	__yum makecache
fi
__install_pkg incus
[ -d "/usr/share/OVMF" ] || mkdir -p "/usr/share/OVMF"
if [ -f "/usr/share/edk2/ovmf/OVMF_CODE.fd" ] && [ ! -e "/usr/share/OVMF/OVMF_CODE.fd" ]; then
	ln -s /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd
fi
type -P setupmgr >/dev/null 2>&1 && setupmgr incus
echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
if __system_service_exists "incus"; then
	__devnull systemctl start "incus"
	__devnull systemctl restart "incus"
	__devnull systemctl enable --now incus || incus_setup_failed="yes"
else
	incus_setup_failed=yes
fi
[ -n "$(find /var/lib/incus -mindepth 1 2>/dev/null)" ] || incus_setup_failed="yes"
if [ "$incus_setup_failed" = "no" ]; then
	if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
		__devnull incus network set incusbr0 ipv4.firewall false
		__devnull incus network set incusbr0 ipv6.firewall false
		__devnull systemctl restart incus
		__printf_blue "incus has been initialized"
		unset incus_setup_failed
	else
		incus_setup_failed="yes"
	fi
fi
INCUS
            ;;
        arch)
            cat <<'INCUS'
incus_setup_failed="no"
__install_pkg incus
echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
if __system_service_exists "incus"; then
	__devnull systemctl start "incus"
	__devnull systemctl restart "incus"
	__devnull systemctl enable --now incus || incus_setup_failed="yes"
else
	incus_setup_failed=yes
fi
[ -n "$(find /var/lib/incus -mindepth 1 2>/dev/null)" ] || incus_setup_failed="yes"
if [ "$incus_setup_failed" = "no" ]; then
	if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
		__devnull incus network set incusbr0 ipv4.firewall false
		__devnull incus network set incusbr0 ipv6.firewall false
		__devnull systemctl restart incus
		__printf_blue "incus has been initialized"
		unset incus_setup_failed
	else
		incus_setup_failed="yes"
	fi
fi
INCUS
            ;;
        alpine)
            cat <<'INCUS'
__printf_yellow "incus requires systemd — skipping on Alpine (OpenRC)"
INCUS
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Apply function body replacement using awk brace-counting
# replace_func SRC_FILE FUNC_NAME BODY_STRING
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
replace_func() {
    local input="$1" funcname="$2"
    shift 2
    local newbody="$*"
    awk -v fn="$funcname" -v body="$newbody" '
        BEGIN { skip=0; depth=0; printed_replacement=0 }
        !skip && $0 ~ "^"fn"\\(\\) \\{" {
            # print the function header line
            print $0
            # print replacement body
            print body
            skip=1
            depth=1
            next
        }
        skip {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c == "{") depth++
                else if (c == "}") { depth--; if (depth==0) { print "}"; skip=0; next } }
            }
            next
        }
        { print }
    ' "$input"
}

# Helper: replace_func using a temp file pipeline
# Handles both single-line (func() { ...; }) and multi-line function definitions.
replace_func_file() {
    local file="$1" funcname="$2" bodyfile="$3"
    local body
    body="$(<"$bodyfile")"
    awk -v fn="$funcname" -v body="$body" '
        BEGIN { skip=0; depth=0 }
        !skip && $0 ~ "^"fn"\\(\\) \\{" {
            # Single-line function: line both opens AND closes with }
            # Detect by checking if the line ends with } (optional trailing whitespace)
            if ($0 ~ /\}[[:space:]]*$/) {
                print fn"() {"
                print body
                print "}"
                # Do NOT enter skip mode; line is fully consumed
            } else {
                print $0
                print body
                skip=1; depth=1
            }
            next
        }
        skip {
            n = split($0, chars, "")
            for (i=1; i<=n; i++) {
                if (chars[i] == "{") depth++
                else if (chars[i] == "}") {
                    depth--
                    if (depth == 0) { print "}"; skip=0; next }
                }
            }
            next
        }
        { print }
    ' "$file"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# replace_section INPUT MARKER REPL_FILE
# Section format: ######/__printf_head "Title"/######/content/######(next)
# Removes the entire section (including its leading ######) and emits
# the content of REPL_FILE in its place, then resumes at the next ######.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
replace_section() {
    local input="$1" marker="$2" repl_file="$3"
    awk -v marker="$marker" -v repl_file="$repl_file" '
        BEGIN {
            hold = ""; skip = 0; count = 0; repl = ""
            while ((getline line < repl_file) > 0)
                repl = repl line "\n"
        }
        /^#{40,}/ && !skip {
            if (hold != "") print hold
            hold = $0
            next
        }
        hold != "" && index($0, marker) > 0 && /__printf_head/ {
            hold = ""; skip = 1; count = 0; next
        }
        {
            if (hold != "") { print hold; hold = "" }
        }
        skip && /^#{40,}/ {
            count++
            if (count == 2) {
                printf "%s", repl
                skip = 0; count = 0; hold = $0
            }
            next
        }
        skip { next }
        { print }
        END { if (hold != "") print hold }
    ' "$input"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# skip_section INPUT MARKER — remove a section entirely (including its leading ######)
# Section format: ######/__printf_head "Title"/######/content/######(next)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
skip_section() {
    local input="$1" marker="$2"
    awk -v marker="$marker" '
        BEGIN { hold = ""; skip = 0; count = 0 }
        /^#{40,}/ && !skip {
            if (hold != "") print hold
            hold = $0
            next
        }
        hold != "" && index($0, marker) > 0 && /__printf_head/ {
            hold = ""; skip = 1; count = 0; next
        }
        {
            if (hold != "") { print hold; hold = "" }
        }
        skip && /^#{40,}/ {
            count++
            if (count == 2) {
                skip = 0; count = 0; hold = $0
            }
            next
        }
        skip { next }
        { print }
        END { if (hold != "") print hold }
    ' "$input"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# replace_block INPUT START_PATTERN END_PATTERN REPLACEMENT
# Replace verbatim block between two anchor patterns with new content
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
replace_block() {
    local input="$1" start="$2" end="$3"
    shift 3
    local replacement="$*"
    awk -v start="$start" -v end="$end" -v repl="$replacement" '
        BEGIN { skip=0; done=0 }
        !skip && !done && $0 ~ start { skip=1; print repl; next }
        skip && $0 ~ end { skip=0; done=1; next }
        skip { next }
        { print }
    ' "$input"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# apply_pkg_renames DISTRO — sed transforms all install_pkg / remove_pkg calls
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
apply_pkg_renames() {
    local distro="$1"

    while IFS= read -r line; do
        # Match __install_pkg/__remove_pkg (or the unprefixed legacy spelling)
        # at any indentation and map the package name for this distro
        if [[ "$line" =~ ^([[:space:]]*)(__)?(install_pkg|remove_pkg)[[:space:]]+([a-zA-Z0-9_.+-]+)$ ]]; then
            local indent="${BASH_REMATCH[1]}"
            local prefix="${BASH_REMATCH[2]}"
            local cmd="${BASH_REMATCH[3]}"
            local pkg="${BASH_REMATCH[4]}"
            local mapped
            mapped="$(pkg_name "$distro" "$pkg")"
            [ "$mapped" = "SKIP" ] && continue
            printf '%s\n' "${indent}${prefix}${cmd} ${mapped}"
        else
            printf '%s\n' "$line"
        fi
    done
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# apply_content_transforms DISTRO — sed-based path/string fixes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
apply_content_transforms() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            sed \
                -e 's|/etc/httpd|/etc/apache2|g' \
                -e 's|/var/log/httpd|/var/log/apache2|g' \
                -e 's|/run/httpd|/run/apache2|g' \
                -e 's|/etc/named|/etc/bind|g' \
                -e 's|/var/named|/var/cache/bind|g' \
                -e 's|/etc/yum.repos.d|/etc/apt/sources.list.d|g' \
                -e 's|/etc/php-fpm\.conf|/etc/php/${PHP_VER}/fpm/php-fpm.conf|g' \
                -e 's|/etc/php-fpm\.d/|/etc/php/${PHP_VER}/fpm/pool.d/|g' \
                -e 's|/etc/php\.ini|/etc/php/${PHP_VER}/cli/php.ini|g' \
                -e 's|/var/log/secure|/var/log/auth.log|g' \
                -e 's|/var/log/maillog|/var/log/mail.log|g' \
                -e "s|casjay-base/rhel|casjay-base/$distro|g" \
                -e "s|\"centos\"|\"$distro\"|g" \
                -e 's|httpd >/dev/null|apache2 >/dev/null|g' \
                -e 's|is-enabled httpd|is-enabled apache2|g' \
                -e 's|is-active httpd|is-active apache2|g' \
                -e "s|SCRIPT_OS=\"AlmaLinux\"|SCRIPT_OS=\"$(distro_script_os "$distro")\"|g" \
                -e 's|echo "rhel"|echo ""|g' \
                -e 's|__run_external "__yum clean all"|__run_external "__yum clean"|g' \
                -e 's|__run_external yum update -q -yy --skip-broken|__run_external "apt-get upgrade -y -q"|g'
            ;;
        fedora)
            sed \
                -e "s|casjay-base/rhel|casjay-base/$distro|g" \
                -e "s|\"centos\"|\"$distro\"|g" \
                -e "s|SCRIPT_OS=\"AlmaLinux\"|SCRIPT_OS=\"$(distro_script_os "$distro")\"|g" \
                -e 's|echo "rhel"|echo "fedora"|g' \
                -e "s|ID_LIKE.*centos\"|ID_LIKE.*fedora\"|g" \
                -e 's|__run_external "__yum clean all"|__run_external "dnf clean all -q"|g' \
                -e 's|__run_external yum update -q -yy --skip-broken|__run_external "dnf upgrade -y -q"|g'
            ;;
        arch)
            sed \
                -e 's|/etc/php-fpm\.conf|/etc/php/php-fpm.conf|g' \
                -e 's|/etc/php-fpm\.d/|/etc/php/fpm/pool.d/|g' \
                -e 's|/etc/php\.ini|/etc/php/php.ini|g' \
                -e 's|/var/log/secure|/var/log/auth.log|g' \
                -e 's|/var/log/maillog|/var/log/mail.log|g' \
                -e 's|/var/www/html|/srv/http|g' \
                -e "s|casjay-base/rhel|casjay-base/$distro|g" \
                -e "s|\"centos\"|\"$distro\"|g" \
                -e "s|SCRIPT_OS=\"AlmaLinux\"|SCRIPT_OS=\"$(distro_script_os "$distro")\"|g" \
                -e 's|echo "rhel"|echo ""|g' \
                -e 's|__run_external "__yum clean all"|__run_external "pacman -Sc --noconfirm"|g' \
                -e 's|__run_external yum update -q -yy --skip-broken|__run_external "pacman -Syu --noconfirm"|g'
            ;;
        alpine)
            sed \
                -e 's|/etc/httpd|/etc/apache2|g' \
                -e 's|/var/log/httpd|/var/log/apache2|g' \
                -e 's|/run/httpd|/run/apache2|g' \
                -e 's|/etc/named|/etc/bind|g' \
                -e 's|/var/named|/var/cache/bind|g' \
                -e 's|/etc/php-fpm\.conf|/etc/php8/php-fpm.conf|g' \
                -e 's|/etc/php-fpm\.d/|/etc/php8/php-fpm.d/|g' \
                -e 's|/etc/php\.ini|/etc/php8/php.ini|g' \
                -e 's|/var/log/secure|/var/log/auth.log|g' \
                -e 's|/var/log/maillog|/var/log/mail.log|g' \
                -e 's|/var/www/html|/var/www/localhost/htdocs|g' \
                -e "s|casjay-base/rhel|casjay-base/$distro|g" \
                -e "s|\"centos\"|\"$distro\"|g" \
                -e "s|SCRIPT_OS=\"AlmaLinux\"|SCRIPT_OS=\"$(distro_script_os "$distro")\"|g" \
                -e 's|echo "rhel"|echo ""|g' \
                -e 's|__run_external "__yum clean all"|__run_external "apk cache clean"|g' \
                -e 's|__run_external yum update -q -yy --skip-broken|__run_external "apk upgrade"|g'
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# service_list DISTRO TYPE — emit SERVICES_ENABLE or SERVICES_DISABLE
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
service_list() {
    local distro="$1" type="$2"
    case "$type" in
        enable)
            case "$distro" in
                debian|ubuntu|raspbian)
                    echo 'SERVICES_ENABLE="cockpit cockpit.socket docker apache2 munin-node nginx php-fpm postfix proftpd rsyslog snmpd sshd uptimed downtimed "'
                    ;;
                fedora)
                    echo 'SERVICES_ENABLE="cockpit cockpit.socket docker httpd munin-node nginx ntpd php-fpm postfix proftpd rsyslog snmpd sshd uptimed downtimed "'
                    ;;
                arch)
                    echo 'SERVICES_ENABLE="docker apache munin-node nginx php-fpm postfix rsyslog sshd "'
                    ;;
                alpine)
                    echo 'SERVICES_ENABLE="docker apache2 nginx php-fpm83 postfix rsyslog sshd "'
                    ;;
            esac
            ;;
        disable)
            case "$distro" in
                debian|ubuntu|raspbian)
                    echo 'SERVICES_DISABLE="avahi-daemon.service avahi-daemon.socket cups.path cups.service cups.socket dhcpd dhcpd6 dm-event.socket fail2ban irqbalance.service iscsi iscsid.socket iscsiuio.socket lvm2-lvmetad.socket lvm2-lvmpolld.socket lvm2-monitor mdmonitor named nfs-client.target radvd rpcbind.service rpcbind.socket smb sssd-kcm.socket udisks2.service"'
                    ;;
                fedora)
                    echo 'SERVICES_DISABLE="avahi-daemon.service avahi-daemon.socket cups.path cups.service cups.socket dhcpd dhcpd6 dm-event.socket fail2ban firewalld import-state.service irqbalance.service iscsi iscsid.socket iscsiuio.socket kdump loadmodules.service lvm2-lvmetad.socket lvm2-lvmpolld.socket lvm2-monitor mdmonitor multipathd.service multipathd.socket named nfs-client.target nis-domainname.service nmb radvd rpcbind.service rpcbind.socket shorewall shorewall6 smb sssd-kcm.socket timedatex.service tuned.service udisks2.service"'
                    ;;
                arch)
                    echo 'SERVICES_DISABLE="avahi-daemon avahi-daemon cups irqbalance named nmb radvd smb"'
                    ;;
                alpine)
                    echo 'SERVICES_DISABLE="avahi-daemon cups irqbalance"'
                    ;;
            esac
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# php_block DISTRO — emit the distro-specific PHP package install
# Replaces the rhel Remi/dnf-module PHP batch, which has no meaning elsewhere.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
php_block() {
    local distro="$1"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'PHPB'
# Debian family ships unversioned PHP meta packages that pull the default slot
__install_pkg php php-cli php-common php-fpm php-gd php-gmp php-intl php-mbstring php-mysql php-pdo php-pgsql php-xml
PHPB
            ;;
        fedora)
            cat <<'PHPB'
__install_pkg php php-cli php-common php-fpm php-gd php-gmp php-intl php-mbstring php-mysqlnd php-pdo php-pgsql php-xml
PHPB
            ;;
        arch)
            cat <<'PHPB'
# Arch builds cli, mbstring, xml and pdo into the base php package
__install_pkg php php-fpm php-gd php-pgsql php-sqlite
PHPB
            ;;
        alpine)
            cat <<'PHPB'
# Alpine PHP packages are slot-versioned and installed in the version-specific section
true
PHPB
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# version_pkg_block DISTRO — emit distro-specific runtime version-conditional package section
# Replaces the "Installing version-specific packages" section from rhel source.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
version_pkg_block() {
    local distro="$1"
    cat <<'HDR'
##################################################################################################################
HDR
    echo "__printf_head \"Installing version-specific packages\""
    echo "##################################################################################################################"
    case "$distro" in
        debian|ubuntu|raspbian)
            cat <<'BODY'
# Detect installed PHP version for dynamic config path construction
# (PHP paths in this script use ${PHP_VER} — set it before any config copy operations)
PHP_VER="$(php --version 2>/dev/null | awk 'NR==1{print $2}' | cut -d. -f1,2)"
[ -z "$PHP_VER" ] && PHP_VER="$(ls /etc/php/ 2>/dev/null | grep -E -- '^[0-9]' | sort -V | tail -1)"
[ -z "$PHP_VER" ] && PHP_VER="8.2"
# lsb-release: available on all supported Debian/Ubuntu versions
__install_pkg lsb-release
__install_pkg awstats
__install_pkg fortune-mod
# mlocate was replaced by plocate
__install_pkg plocate
__install_pkg zlib1g
BODY
            # python3-future is packaged by Ubuntu but not by Debian/Raspbian
            if [ "$distro" = "ubuntu" ]; then
                echo "__install_pkg python3-future"
            fi
            ;;
        fedora)
            cat <<'BODY'
__install_pkg awstats
__install_pkg fortune-mod
__install_pkg deltarpm
__install_pkg redhat-lsb
BODY
            ;;
        arch)
            cat <<'BODY'
__install_pkg lsb-release
__install_pkg awstats
__install_pkg fortune-mod
# mlocate was replaced by plocate
__install_pkg plocate
__install_pkg zlib
BODY
            ;;
        alpine)
            cat <<'BODY'
# Select PHP slot matching the running Alpine version
_ALPINE_VER="$(cat /etc/alpine-release 2>/dev/null | cut -d. -f1,2)"
case "$_ALPINE_VER" in
    3.1[0-3]*) _PHP="php7" ;;
    3.1[45]*)  _PHP="php8" ;;
    3.16*)     _PHP="php8" ;;
    3.17*)     _PHP="php81" ;;
    3.18*)     _PHP="php82" ;;
    *)         _PHP="php83" ;;
esac
__install_pkg ${_PHP}
__install_pkg ${_PHP}-cli
__install_pkg ${_PHP}-fpm
__install_pkg ${_PHP}-gd
__install_pkg ${_PHP}-gmp
__install_pkg ${_PHP}-intl
__install_pkg ${_PHP}-mbstring
__install_pkg ${_PHP}-pdo_mysql
__install_pkg ${_PHP}-pdo
__install_pkg ${_PHP}-pgsql
__install_pkg ${_PHP}-xml
unset _PHP _ALPINE_VER
__install_pkg awstats
__install_pkg plocate
__install_pkg zlib
BODY
            ;;
    esac
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# generate_min_sh DISTRO — produce transformed min.sh on stdout
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
generate_min_sh() {
    local distro="$1"
    local tmpdir
    tmpdir="$(mktemp -d)"
    local work="$tmpdir/min.sh"

    # Start with rhel source
    cp "$SRC" "$work"

    # --- Step 1: Replace header APPNAME and VERSION line ---
    sed -i "s|^APPNAME=\"min\"|APPNAME=\"min-$distro\"|g" "$work"
    sed -i "s|@@Description.*:.*Script to setup min for CentOS.*|@@Description      :  Script to setup min for $(distro_script_os "$distro")|g" "$work"

    # --- Step 1b: Drop the EPEL pre-seed block (EL-only, no equivalent elsewhere) ---
    awk '
        /^# epel-release must be enabled before the casjay-dotfiles\/scripts installer$/ { skip=1 }
        skip && /^\{ yum makecache / { skip=0; next }
        skip { next }
        { print }
    ' "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 2: Replace early bootstrap block (before functions are loaded) ---
    # The block spans from "if [ ! -d /etc/casjaysdev ]" through "unset pkg"
    # (bash uses if/fi not {/}, so we use the end-marker "^unset pkg$")
    local early_block
    early_block="$(early_bootstrap "$distro")"
    awk -v repl="$early_block" '
        BEGIN { skip=0; done=0 }
        !done && /^if \[ ! -d "\/etc\/casjaysdev" \]/ { skip=1; print repl; next }
        skip && /^unset pkg$/ { skip=0; done=1; next }
        skip { next }
        { print }
    ' "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 3: Replace function bodies ---
    # Use temp files to build replacement bodies
    local fbody
    for func in __dnf_yum __yum __backup_repo_files __rm_repo_files __test_pkg __remove_pkg __install_pkg __run_init_check __retrieve_repo_file __disable_selinux __detect_selinux __kernel_ml __kernel_lt; do
        fbody="$tmpdir/body_${func}.txt"
        case "$func" in
            __dnf_yum)         func_dnf_yum_body "$distro" >"$fbody" ;;
            __yum)             func_yum_body "$distro" >"$fbody" ;;
            __backup_repo_files) func_backup_repo_files_body "$distro" >"$fbody" ;;
            __rm_repo_files)     func_rm_repo_files_body "$distro" >"$fbody" ;;
            __test_pkg)          func_test_pkg_body "$distro" >"$fbody" ;;
            __remove_pkg)        func_remove_pkg_body "$distro" >"$fbody" ;;
            __install_pkg)       func_install_pkg_body "$distro" >"$fbody" ;;
            __run_init_check)    func_run_init_check_body "$distro" >"$fbody" ;;
            __retrieve_repo_file) func_retrieve_repo_file_body "$distro" >"$fbody" ;;
            __disable_selinux)   func_disable_selinux_body "$distro" >"$fbody" ;;
            __detect_selinux)    func_detect_selinux_body "$distro" >"$fbody" ;;
            __kernel_ml)       func_kernel_ml_body >"$fbody" ;;
            __kernel_lt)       func_kernel_lt_body >"$fbody" ;;
        esac
        replace_func_file "$work" "$func" "$fbody" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
    done

    # Replace __create_account for debian family (wheel → sudo)
    case "$distro" in
        debian|ubuntu|raspbian)
            func_create_account_body_debian >"$tmpdir/body___create_account.txt"
            replace_func_file "$work" "__create_account" "$tmpdir/body___create_account.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            ;;
    esac

    # Alpine: replace systemctl-based helper functions with OpenRC equivalents
    if [ "$distro" = "alpine" ]; then
        printf '%s\n' '	[ -f "/etc/init.d/$1" ] && return 0 || return 1' >"$tmpdir/body_system_service_exists.txt"
        replace_func_file "$work" "__system_service_exists" "$tmpdir/body_system_service_exists.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
        printf '%s\n' '	! rc-update show default 2>/dev/null | grep -q "^${1} " && __execute "rc-update add ${1} default" "Enabling service: ${1}" || return 1' >"$tmpdir/body_system_service_enable.txt"
        replace_func_file "$work" "__system_service_enable" "$tmpdir/body_system_service_enable.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
    fi

    # --- Step 4: Skip RHEL-only sections ---
    case "$distro" in
        debian|ubuntu|raspbian|arch|alpine)
            # Skip "Fixing initscripts" section
            skip_section "$work" "Fixing initscripts" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            # Skip "Disabling selinux" section
            skip_section "$work" "Disabling selinux" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            # Skip "Removing iptables-legacy" section (may not exist in all versions)
            grep -q 'Removing iptables-legacy' "$work" && \
                skip_section "$work" "Removing iptables-legacy" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work" || true
            ;;
    esac

    case "$distro" in
        debian|ubuntu|raspbian|arch|alpine)
            # Skip kernel configuration section (no kernel-ml/lt on these distros)
            skip_section "$work" "Configuring the kernel" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            ;;
    esac

    # --- Step 5: Replace "Installing incus" section ---
    incus_section "$distro" >"$tmpdir/incus_repl.txt"
    replace_section "$work" "Installing incus" "$tmpdir/incus_repl.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 6: Replace "Configuring the firewall" section ---
    firewall_section "$distro" >"$tmpdir/fw_repl.txt"
    replace_section "$work" "Configuring the firewall" "$tmpdir/fw_repl.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 7: Replace service lists ---
    local svc_enable svc_disable
    svc_enable="$(service_list "$distro" enable)"
    svc_disable="$(service_list "$distro" disable)"
    sed -i "s|^SERVICES_ENABLE=.*|${svc_enable}|g" "$work"
    # Replace the first SERVICES_DISABLE= line and delete all += continuation lines
    sed -i "s|^SERVICES_DISABLE=.*|${svc_disable}|g" "$work"
    sed -i '/^SERVICES_DISABLE+=/d' "$work"

    # --- Step 8: Fix OS-ID check ---
    local id_check
    id_check="$(distro_id_check "$distro")"
    sed -i "s|grep -qiwE \"\\\$SCRIPT_OS\"|grep -qiwE \"$id_check\"|g" "$work"

    # --- Step 9: Apply package name renames ---
    apply_pkg_renames "$distro" <"$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 9b: Replace the rhel Remi/dnf-module PHP batch ---
    php_block "$distro" >"$tmpdir/php_block.txt"
    awk -v f="$tmpdir/php_block.txt" '
        /^# __install_pkg cannot accept dnf flags so PHP packages are installed in one$/ {
            while ((getline line < f) > 0) print line
            close(f)
            skip=1
            next
        }
        skip && /^unset _php_pkgs _php_extra_opts _php_stream pkg$/ { skip=0; next }
        skip { next }
        { print }
    ' "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 10: Apply content transforms (paths, variables) ---
    apply_content_transforms "$distro" <"$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 10b: Translate RHEL-only cleanup and package-query lines ---
    case "$distro" in
        debian|ubuntu|raspbian)
            sed -e "s#^_oci_pkgs=.*#_oci_pkgs=\"\$(dpkg -l 2>/dev/null | awk '/^ii/{print \$2}' | grep -E -- '^(oci|cloud|oracle)')\"#" \
                -e "s|'\\*\\.rpmnew'|'*.dpkg-new'|g" \
                -e "s|'\\*\\.rpmsave'|'*.dpkg-old'|g" \
                "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            ;;
        arch)
            sed -e "s#^_oci_pkgs=.*#_oci_pkgs=\"\$(pacman -Qq 2>/dev/null | grep -E -- '^(oci|cloud|oracle)')\"#" \
                -e "s|'\\*\\.rpmnew'|'*.pacnew'|g" \
                -e "s|'\\*\\.rpmsave'|'*.pacsave'|g" \
                "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            ;;
        alpine)
            sed -e "s#^_oci_pkgs=.*#_oci_pkgs=\"\$(apk info 2>/dev/null | grep -E -- '^(oci|cloud|oracle)')\"#" \
                -e "s|'\\*\\.rpmnew'|'*.apk-new'|g" \
                -e "/'\\*\\.rpmsave'/d" \
                "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
            ;;
    esac
    # /etc/sysconfig/network* is an EL-only interface - drop it everywhere else
    case "$distro" in
        debian|ubuntu|raspbian|arch|alpine)
            sed -i -e '/if \[ -f "\/etc\/sysconfig\/network-scripts\/ifcfg-eth0.sample" \]/,+2d' \
                -e '/sed -i "s#myserverdomainname#\$HOSTNAME#g" \/etc\/sysconfig\/network$/d' \
                -e '/sed -i "s#mydomain#\$set_domainname#g" \/etc\/sysconfig\/network$/d' \
                "$work"
            ;;
    esac
    # Remaining httpd references (paths, service names, hook scripts) are apache2
    # on Debian family and Alpine - package names were already mapped in Step 9
    case "$distro" in
        debian|ubuntu|raspbian|alpine)
            sed -i 's|httpd|apache2|g' "$work"
            ;;
    esac
    # subscription-manager is a Red Hat subscription plugin - meaningless elsewhere
    case "$distro" in
        debian|ubuntu|raspbian|arch|alpine|fedora)
            sed -i '/^\[ -f "\/etc\/yum\/pluginconf.d\/subscription-manager.conf" \]/d' "$work"
            ;;
    esac

    # --- Step 11: Alpine-specific: replace systemctl service management ---
    if [ "$distro" = "alpine" ]; then
        sed -i \
            -e 's|systemctl enable --now|rc-update add|g' \
            -e 's|systemctl disable --now|rc-update del|g' \
            -e 's|systemctl restart \([a-zA-Z0-9._-]*\)|rc-service \1 restart|g' \
            -e 's|systemctl start \([a-zA-Z0-9._-]*\)|rc-service \1 start|g' \
            -e 's|systemctl stop \([a-zA-Z0-9._-]*\)|rc-service \1 stop|g' \
            -e 's|systemctl reload \([a-zA-Z0-9._-]*\)|rc-service \1 reload|g' \
            -e 's|systemctl is-enabled|rc-update show|g' \
            -e 's|systemctl is-active|rc-service -e|g' \
            -e 's|systemctl daemon-reload|true|g' \
            -e 's|systemctl mask|true|g' \
            "$work"
        # Alpine: skip tmpfiles.d and systemd sections
        sed -i '/\/etc\/systemd\//d' "$work"
        sed -i '/\/etc\/tmpfiles\.d\//d' "$work"
        # Alpine: busybox grep does not support --no-filename long option; use -h
        sed -i 's/grep --no-filename/grep -h/g' "$work"
        # Alpine: hostnamectl is systemd-only; guard with a command check
        sed -i 's/if hostnamectl set-hostname/if command -v hostnamectl >\/dev\/null 2>\&1 \&\& hostnamectl set-hostname/g' "$work"
        # Alpine: passwd --stdin not available; use chpasswd
        sed -i 's#echo "\$root_pass_1" | passwd --stdin root#echo "root:\$root_pass_1" | chpasswd#g' "$work"
    fi

    # --- Step 12: Alpine: update-ca-trust → update-ca-certificates ---
    if [ "$distro" = "alpine" ] || [ "$distro" = "debian" ] || [ "$distro" = "ubuntu" ] || [ "$distro" = "raspbian" ]; then
        sed -i \
            -e 's|update-ca-trust|update-ca-certificates|g' \
            "$work"
    fi

    # --- Step 13: Debian: hostnamectl and passwd --stdin ---
    if [ "$distro" = "debian" ] || [ "$distro" = "ubuntu" ] || [ "$distro" = "raspbian" ]; then
        # passwd --stdin not available on debian; use chpasswd
        # NOTE: use # delimiter to avoid | in pattern being treated as sed delimiter
        sed -i 's#echo "\$root_pass_1" | passwd --stdin root#echo "root:\$root_pass_1" | chpasswd#g' "$work"
        # yum_conf path fix
        sed -i 's|/etc/dnf/dnf.conf|/etc/apt/apt.conf.d/99casjays|g' "$work"
    fi

    # --- Step 14: Replace "Installing version-specific packages" section ---
    version_pkg_block "$distro" >"$tmpdir/ver_block.txt"
    replace_section "$work" "Installing version-specific packages" "$tmpdir/ver_block.txt" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

    # --- Step 15: Alpine: inject apt→apk shim before system-installer.bash source ---
    # system-installer.bash does not recognise apk; it exits 1 if no known pkg manager
    # is found.  A real /usr/local/bin/apt wrapper makes it fall through cleanly.
    if [ "$distro" = "alpine" ]; then
        cat >"$tmpdir/apt_shim.sh" <<'SHIM'
# Create apt shim so system-installer.bash recognises a package manager on Alpine
if ! command -v apt >/dev/null 2>&1 && command -v apk >/dev/null 2>&1; then
	printf '#!/bin/sh\nexec apk add --no-cache "$@"\n' >/usr/local/bin/apt && chmod +x /usr/local/bin/apt
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SHIM
        awk '/^# Set functions$/{while((getline line < "'"$tmpdir/apt_shim.sh"'") > 0) print line; close("'"$tmpdir/apt_shim.sh"'")} {print}' "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"

        # --- Step 16: Alpine: override execute() after functions source ---
        # system-installer.bash execute() uses mktemp /tmp/XXXXX (5 X's) which
        # busybox mktemp rejects — requires exactly 6 X's.  Redefine execute()
        # after the source block so every install_pkg call works on Alpine.
        cat >"$tmpdir/execute_override.sh" <<'EXECOVERRIDE'
# Override __execute() for Alpine busybox mktemp compatibility
__execute() {
	local cmd="$1"
	local msg="${2:-$1}"
	local tmpf
	tmpf="$(mktemp)" || tmpf="/tmp/execute_$$"
	printf '[ / ] %s\r' "$msg"
	if eval "$cmd" >/dev/null 2>"$tmpf"; then
		__printf_execute_success "$msg"
		rm -f "$tmpf"
		return 0
	else
		__printf_execute_error "$msg"
		__printf_execute_error_stream <"$tmpf"
		rm -f "$tmpf"
		return 1
	fi
}
EXECOVERRIDE
        awk '/^SCRIPT_OS=/{while((getline line < "'"$tmpdir/execute_override.sh"'") > 0) print line; close("'"$tmpdir/execute_override.sh"'")} {print}' "$work" >"$tmpdir/work2.sh" && mv "$tmpdir/work2.sh" "$work"
    fi

    # Output result
    cat "$work"
    rm -rf "$tmpdir"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main: generate min.sh for each distro
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
for distro in "${DISTROS[@]}"; do
    dst_dir="$BASEDIR/$distro/scripts"
    dst="$dst_dir/min.sh"

    # Create distro repo if it doesn't exist yet
    if [ ! -d "$BASEDIR/$distro" ]; then
        echo "Creating new distro dir: $distro"
        mkdir -p "$BASEDIR/$distro"
    fi
    mkdir -p "$dst_dir"

    # If distro has no git repo, initialize one
    if [ ! -d "$BASEDIR/$distro/.git" ]; then
        echo "Initializing git repo for $distro"
        git -C "$BASEDIR/$distro" init -q
    fi

    echo "Generating $distro/scripts/min.sh ..."
    generate_min_sh "$distro" >"$dst"
    chmod 755 "$dst"
    echo "  -> $dst"
done

echo ""
echo "pkmgr-sync complete."

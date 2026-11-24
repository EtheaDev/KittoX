#!/usr/bin/env bash
# Prepares an Ubuntu 24.04 (WSL or a real machine) to link and run KittoX
# Linux64 binaries built on Windows with dcclinux64.
#
#   sudo bash setup_ubuntu.sh [linux-user] [paserver-tgz]
#     linux-user   : the account to create/use as default (default: kittox)
#     paserver-tgz : optional path of LinuxPAServer<ver>.tar.gz, extracted to /opt
#
# Run as root. Safe to run again: every step checks before acting.
set -euo pipefail

LINUX_USER="${1:-kittox}"
PASERVER_TGZ="${2:-}"
export DEBIAN_FRONTEND=noninteractive

step() { printf '\n=== %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash $0)." >&2
  exit 1
fi

step "User $LINUX_USER"
if ! id "$LINUX_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo "$LINUX_USER"
fi
# A development box: sudo without a password, so scripts can run unattended.
echo "$LINUX_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-kittox
chmod 440 /etc/sudoers.d/90-kittox

if grep -qi microsoft /proc/version 2>/dev/null; then
  step "WSL settings (systemd, default user)"
  cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[user]
default=$LINUX_USER
EOF
fi

step "Base packages"
apt-get update
apt-get -y upgrade
# build-essential: crt*.o, libgcc and the glibc development files the Delphi
#   linker needs; the same set the IDE's SDK import expects.
# zlib, curl, icu: libraries the Delphi Linux RTL loads (ICU for strings and,
#   in KittoX, the NFKC normalization of passwords in Kitto.Bcrypt).
# python3: needed by PAServer's debugger.
apt-get install -y \
  build-essential zlib1g-dev libcurl4-openssl-dev libicu-dev \
  python3 libpython3-dev \
  curl ca-certificates gnupg file

step "Database client libraries (FireDAC)"
# PostgreSQL (libpq.so.5), Firebird (libfbclient.so.2), ODBC for SQL Server.
apt-get install -y libpq5 libfbclient2 unixodbc unixodbc-dev
# FireDAC loads Firebird as "libfbclient.so", with no version: the link comes
# only with the development package. Without it: "[FireDAC][Phys][FB]-314.
# Cannot load vendor library [libfbclient.so or libfbembed.so]".
apt-get install -y firebird-dev

step "LDAP (Kitto.Auth.LDAP)"
# libldap2 is what the program loads; libldap-dev only adds the libldap.so link
# the Delphi linker looks for (it turns 'libldap.so.2' into -lldap).
apt-get install -y libldap2 libldap-dev

if ! dpkg -s msodbcsql18 >/dev/null 2>&1; then
  step "Microsoft ODBC Driver 18 for SQL Server"
  . /etc/os-release
  curl -fsSL -o /tmp/packages-microsoft-prod.deb \
    "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
  dpkg -i /tmp/packages-microsoft-prod.deb
  rm -f /tmp/packages-microsoft-prod.deb
  apt-get update
  ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18
fi

if [ -n "$PASERVER_TGZ" ] && [ -f "$PASERVER_TGZ" ]; then
  step "PAServer (only needed to debug from the IDE)"
  tar -xzf "$PASERVER_TGZ" -C /opt
  chown -R "$LINUX_USER":"$LINUX_USER" /opt/PAServer-* || true
fi

step "Done"
echo "Distribution : $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "GCC          : $(gcc -dumpversion)"
echo "ICU          : $(ls /usr/lib/x86_64-linux-gnu/libicuuc.so.* 2>/dev/null | head -1)"
echo "ODBC drivers : $(odbcinst -q -d 2>/dev/null | tr '\n' ' ')"

#!/usr/bin/env bash
# Installs a Firebird server in Ubuntu with the EMPLOYEE sample database, the
# one the KEmployee example connects to (Config.yaml: Server localhost,
# Database EMPLOYEE, SYSDBA / masterkey).
#
#   sudo bash setup_firebird_employee.sh [sysdba-password]
#     sysdba-password : default masterkey, as in the KEmployee configuration
#
# Needed only when no Firebird with EMPLOYEE is reachable on 127.0.0.1:3050
# (with WSL in mirrored networking a Firebird on Windows would do as well).
# Safe to run again: every step checks before acting.
#
# Package: firebird3.0-server (Ubuntu 24.04). The database is created from
# employee.sql.gz of firebird3.0-examples into /var/lib/firebird/3.0/data and
# published as the alias EMPLOYEE in /etc/firebird/3.0/databases.conf.
set -euo pipefail

PASSWORD="${1:-masterkey}"
DB=/var/lib/firebird/3.0/data/employee.fdb
CONF=/etc/firebird/3.0/databases.conf
PWFILE=/etc/firebird/3.0/SYSDBA.password
export DEBIAN_FRONTEND=noninteractive

step() { printf '\n=== %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash $0)." >&2
  exit 1
fi

step "Firebird server"
apt-get install -y firebird3.0-server firebird3.0-examples
systemctl enable --now firebird3.0

# The package sets a random SYSDBA password and writes it to SYSDBA.password
# (preseeding it through debconf has no effect). Whatever it is now, read it
# from there; it becomes $PASSWORD below.
. "$PWFILE"
CURRENT="$ISC_PASSWORD"

step "EMPLOYEE database"
if [ ! -f "$DB" ]; then
  zcat /usr/share/doc/firebird3.0-common-doc/examples/employee.sql.gz \
    | sed "s|^create database 'employee.fdb';|create database 'localhost:$DB' user 'SYSDBA' password '$CURRENT';|" \
    > /tmp/kx_employee.sql
  isql-fb -q -i /tmp/kx_employee.sql > /tmp/kx_employee.out 2>&1 \
    || { tail -20 /tmp/kx_employee.out; exit 1; }
  rm -f /tmp/kx_employee.sql /tmp/kx_employee.out
else
  echo "Already there: $DB"
fi

if ! grep -q '^EMPLOYEE *=' "$CONF"; then
  echo "EMPLOYEE = $DB" >> "$CONF"
fi

step "SYSDBA password"
if [ "$CURRENT" != "$PASSWORD" ]; then
  # security3.fdb refuses remote connections and is locked by the server, so
  # the change goes through a connection to an ordinary database.
  echo "alter user SYSDBA password '$PASSWORD'; commit;" \
    | isql-fb -q -user SYSDBA -password "$CURRENT" "localhost:$DB"
  sed -i "s/^ISC_PASSWORD=.*/ISC_PASSWORD=\"$PASSWORD\"/" "$PWFILE"
  echo "Changed."
else
  echo "Already $PASSWORD."
fi

step "Check"
echo "select count(*) as employees from employee;" \
  | isql-fb -q -user SYSDBA -password "$PASSWORD" localhost:EMPLOYEE

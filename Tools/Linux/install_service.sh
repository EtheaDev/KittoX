#!/usr/bin/env bash
# Installs a KittoX application deployed by deploy_app.sh as a systemd service.
#
#   sudo bash install_service.sh <App> [user] [dest]
#     App  : the application name, e.g. HelloKitto (executable and folder name)
#     user : the account the service runs as (default: the one who ran sudo)
#     dest : the deployment root (default: ~user/kittox)
#
# Creates /etc/systemd/system/kittox-<app>.service, enables and starts it.
#   systemctl status kittox-<app>      state
#   journalctl -u kittox-<app> -f      log (the console log endpoint)
#   systemctl stop kittox-<app>        SIGTERM: the server stops cleanly
#
# Remove with: systemctl disable --now kittox-<app> && rm the unit file.
set -euo pipefail

APP="${1:?application name}"
USER_NAME="${2:-${SUDO_USER:-}}"
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = root ]; then
  # Run as root without sudo (wsl -u root): there is no caller to take the
  # user from, and a KittoX application has no reason to run as root.
  echo "Name the user the service runs as: sudo bash $0 $APP <user>" >&2
  exit 1
fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
DEST="${3:-$USER_HOME/kittox}"
HOME_DIR="$DEST/App/$APP/Home"
UNIT_NAME="kittox-$(echo "$APP" | tr '[:upper:]' '[:lower:]')"
UNIT="/etc/systemd/system/$UNIT_NAME.service"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash $0 ...)." >&2
  exit 1
fi
if [ ! -x "$HOME_DIR/$APP" ]; then
  echo "$HOME_DIR/$APP not found: deploy the application first (deploy_app.sh)." >&2
  exit 1
fi

cat > "$UNIT" <<EOF
[Unit]
Description=KittoX application $APP
# The database may be on this machine: start after the network is up.
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$HOME_DIR
ExecStart=$HOME_DIR/$APP
# KittoX stops cleanly on SIGTERM (the systemd default): it waits for the
# requests in progress and closes the sessions.
TimeoutStopSec=30
Restart=on-failure
RestartSec=5
# The console log endpoint writes to the standard output: the journal.
StandardOutput=journal
StandardError=journal
# Hardening that does not get in the way of a KittoX application: it writes
# only under its own Home (log file, uploads).
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$UNIT_NAME"
# restart, not "enable --now": a service already running would keep the
# executable it started with, and a new deployment would go unnoticed.
systemctl restart "$UNIT_NAME"
sleep 2
systemctl --no-pager status "$UNIT_NAME" | head -15

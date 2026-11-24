#!/usr/bin/env bash
# Copies a KittoX application built for Linux64 into a Linux file system, in
# the layout Kitto.Config finds on its own (the same as an IIS deployment):
#
#   <dest>/Home/                    the KittoX system Home (framework resources)
#   <dest>/App/<App>/Home/          the application Home, with the executable
#
#   bash deploy_app.sh <kittox-root> <app-home> <executable> [dest]
#     kittox-root : the KittoX folder (its Home is the system Home)
#     app-home    : the application Home folder
#     executable  : the Linux64 executable built by build_app_linux.cmd
#     dest        : default $HOME/kittox
#
# The copy goes to a native file system on purpose: /mnt/<drive> is
# case-insensitive like Windows, so it would hide the very problems a Linux
# deployment has to find (file names whose case differs from the metadata).
# Windows binaries (exe, dll, map...) are left out. The application Home is
# replaced at every run; files the application writes at run time (logs,
# uploads) are kept.
set -euo pipefail

KX="${1:?kittox root}"
APP_HOME="${2:?application Home}"
EXE="${3:?executable}"
DEST="${4:-$HOME/kittox}"
APP="$(basename "$EXE")"
TARGET="$DEST/App/$APP/Home"

copy_tree() {  # source target
  mkdir -p "$2"
  # tar keeps the tree and skips the Windows-only files in one pass.
  tar -C "$1" -cf - \
    --exclude='*.exe' --exclude='*.dll' --exclude='*.map' --exclude='*.pdb' \
    --exclude='*.rsm' --exclude='*.log' --exclude='__history' --exclude='__recovery' \
    . | tar -C "$2" -xf -
}

echo "System Home -> $DEST/Home"
rm -rf "$DEST/Home"
copy_tree "$KX/Home" "$DEST/Home"

echo "Application Home -> $TARGET"
# Keep what the application wrote: logs and uploaded files.
KEEP="$(mktemp -d)"
if [ -d "$TARGET" ]; then
  find "$TARGET" -maxdepth 1 -name '*.log' -exec mv {} "$KEEP"/ \;
  [ -d "$TARGET/UploadedFiles" ] && mv "$TARGET/UploadedFiles" "$KEEP"/
fi
rm -rf "$TARGET"
copy_tree "$APP_HOME" "$TARGET"
cp -a "$KEEP"/. "$TARGET"/ 2>/dev/null || true
rm -rf "$KEEP"

install -m 755 "$EXE" "$TARGET/$APP"
echo "Ready: $TARGET/$APP"

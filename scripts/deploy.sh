#!/usr/bin/env bash
#
# deploy.sh — push kindledaily.koplugin to a connected Kindle over MTP.
#
# The Kindle must be plugged in via USB in file-transfer (MTP) mode and
# mounted by gvfs (gio). After deploying, RESTART KOReader on the device —
# it caches Lua modules, so reopening the plugin alone won't load changes.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(dirname "$SCRIPT_DIR")/kindledaily.koplugin"

GVFS="/run/user/$(id -u)/gvfs"
KMOUNT="$(ls -d "$GVFS"/mtp:host=*[Kk]indle* 2>/dev/null | head -1 || true)"
if [ -z "${KMOUNT:-}" ]; then
    echo "No Kindle MTP mount found under $GVFS."
    echo "Plug the Kindle in (native USB, file transfer) and try again."
    exit 1
fi

DST="$KMOUNT/Internal Storage/koreader/plugins/kindledaily.koplugin"
echo "Deploying kindledaily.koplugin"
echo "  from: $SRC"
echo "  to:   $DST"

gio mkdir "$DST" 2>/dev/null || true
gio mkdir "$DST/icons" 2>/dev/null || true

n=0
for f in "$SRC"/*.lua; do
    gio copy "$f" "$DST/$(basename "$f")" && n=$((n+1))
done
i=0
for f in "$SRC"/icons/*; do
    gio copy "$f" "$DST/icons/$(basename "$f")" && i=$((i+1))
done

echo "Copied $n lua files and $i icons."
echo "Now RESTART KOReader on the Kindle to load the changes."

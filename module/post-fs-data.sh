#!/system/bin/sh
MODDIR=${0%/*}
[ -f "$MODDIR/disable" ] && exit 0
[ -f "$MODDIR/remove" ] && exit 0
# Intentionally light: do not touch Zygisk, Vector/LSPosed, ART, or app processes during early boot.
mkdir -p "$MODDIR/state"

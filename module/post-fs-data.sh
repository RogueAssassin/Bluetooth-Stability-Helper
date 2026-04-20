#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/bt-stability.log"
echo "$(date '+%F %T') post-fs-data start" >> "$LOG"
echo "$(date '+%F %T') post-fs-data complete" >> "$LOG"

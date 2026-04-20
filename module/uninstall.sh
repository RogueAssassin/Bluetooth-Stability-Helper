#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/bt-stability.log"
echo "$(date '+%F %T') uninstall start" >> "$LOG"
settings delete global ble_scan_always_enabled
settings delete global wifi_scan_throttle_enabled
settings delete global location_background_throttle_interval_ms
settings delete global device_idle_constants
cmd deviceidle whitelist -com.android.bluetooth >/dev/null 2>&1
cmd deviceidle whitelist -com.google.android.gms >/dev/null 2>&1
echo "$(date '+%F %T') uninstall complete" >> "$LOG"

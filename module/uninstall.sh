#!/system/bin/sh
# Leave /sdcard/Download/Bluetooth-Stability-Helper exports in place for diagnostics.
# Best effort restore of optional settings this module may have touched.
settings delete global location_background_throttle_interval_ms >/dev/null 2>&1
settings delete global wifi_scan_throttle_enabled >/dev/null 2>&1

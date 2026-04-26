#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
LOG="${LOG:-/sdcard/Bluetooth-Stability-Helper/logs/bt-stability.log}"
STATE_DIR="${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}"
mkdir -p "$STATE_DIR"
log() { echo "$(date '+%F %T')  $1" >> "$LOG"; }
package_running() { pkg="$1"; [ -n "$pkg" ] || return 1; pidof "$pkg" >/dev/null 2>&1 && return 0; ps -A 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; ps 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; return 1; }
package_installed() { pkg="$1"; [ -n "$pkg" ] || return 1; cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; }
first_installed_from_list() { for pkg in $1; do package_installed "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
first_running_from_list() { for pkg in $1; do package_running "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
whitelist_pkg() { pkg="$1"; [ -n "$pkg" ] || return 0; cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1 && log "Whitelisted from idle: $pkg"; }
appops_allow_safe() { pkg="$1"; op="$2"; package_installed "$pkg" || return 0; cmd appops set "$pkg" "$op" allow >/dev/null 2>&1 && log "AppOps allow: $pkg $op"; }


sdk_int() { getprop ro.build.version.sdk 2>/dev/null; }
brand_lc() { getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
manufacturer_lc() { getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
is_pixel_device() { [ "$(brand_lc)" = "google" ] || echo "$(getprop ro.product.model 2>/dev/null)" | grep -qi '^pixel'; }
is_samsung_device() { [ "$(manufacturer_lc)" = "samsung" ] || [ "$(brand_lc)" = "samsung" ]; }
is_miui_device() { getprop ro.miui.ui.version.name 2>/dev/null | grep -q . || [ "$(brand_lc)" = "xiaomi" ] || [ "$(brand_lc)" = "redmi" ] || [ "$(brand_lc)" = "poco" ]; }
check_android_support() { [ "$ENABLE_ANDROID_VERSION_WARNINGS" = 1 ] || return; sdk=$(sdk_int); [ -z "$sdk" ] && return; if [ "$sdk" -lt "$SUPPORTED_SDK_MIN" ] || [ "$sdk" -gt "$SUPPORTED_SDK_MAX" ]; then log "Android SDK warning: sdk=$sdk outside tested range $SUPPORTED_SDK_MIN-$SUPPORTED_SDK_MAX"; fi; }
apply_device_profile() {
  [ "$ENABLE_SDK_AWARE_TUNING" = 1 ] || return
  sdk=$(sdk_int)
  if is_pixel_device && [ "$ENABLE_PIXEL_TUNING" = 1 ]; then
    log "Device profile: Pixel/Google"
    ENABLE_A2DP_OFFLOAD_DISABLE=1
    APPLY_RESTRICTED_STANDBY_FIXES=1
    [ "$sdk" -ge "$ANDROID16_SDK" ] && [ "$ENABLE_PIXEL_ANDROID16_GUARDS" = 1 ] && { WATCHDOG_INTERVAL=45; FAILURE_THRESHOLD=2; log "Android 16 Pixel guards active"; }
  elif is_samsung_device && [ "$ENABLE_SAMSUNG_TUNING" = 1 ]; then
    log "Device profile: Samsung"
    APPLY_RESTRICTED_STANDBY_FIXES=1
  elif is_miui_device && [ "$ENABLE_MIUI_TUNING" = 1 ]; then
    log "Device profile: MIUI/Xiaomi/Redmi/Poco"
    ENABLE_DEVICE_IDLE_TUNING=1
    APPLY_RESTRICTED_STANDBY_FIXES=1
  else
    log "Device profile: generic"
  fi
}

#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
LOG="${LOG:-/sdcard/Bluetooth-Stability-Helper/logs/bt-stability.log}"
STATE_DIR="${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}"
mkdir -p "$STATE_DIR"

_log_should_keep() {
  msg="$1"
  [ "${LOG_IMPORTANT_ONLY:-1}" != "1" ] && return 0
  echo "$msg" | grep -qiE 'start|boot|clean|guard active|warning|error|fail|failure|recover|recovery|restart|skipped|stale|stall|freeze|crash|binder died|dead object|gatt|hci|bond|encryption|permission|location warning|bluetooth enabled but no|did not report|health score: ([0-6][0-9]|70)|snapshot|exported|max|storage|rotat|prun|cleanup|Pokémon GO running|not detected' && return 0
  return 1
}

_log_dedup_ok() {
  msg="$1"
  dedup="${LOG_DEDUP_SECONDS:-300}"
  [ "$dedup" = "0" ] && return 0
  key=$(echo "$msg" | tr -cd '[:alnum:] _.-' | cut -c1-80 | tr ' /' '__')
  [ -z "$key" ] && key=message
  f="$STATE_DIR/logdedup_$key"
  now=$(date +%s)
  last=$(cat "$f" 2>/dev/null)
  if [ -n "$last" ] && [ $((now-last)) -lt "$dedup" ]; then return 1; fi
  echo "$now" > "$f" 2>/dev/null
  return 0
}

log_rotate_enforce() {
  [ -n "$LOG" ] || return 0
  mkdir -p "$(dirname "$LOG")" "$STATE_DIR" 2>/dev/null
  [ -f "$LOG" ] || return 0
  size_kb=$(du -k "$LOG" 2>/dev/null | awk '{print $1}')
  [ -z "$size_kb" ] && return 0
  if [ "$size_kb" -gt "${LOG_ROTATE_SIZE_KB:-256}" ]; then
    keep="${LOG_KEEP_ROTATED_COUNT:-2}"
    i="$keep"
    while [ "$i" -ge 1 ]; do
      prev=$((i-1))
      [ "$prev" -eq 0 ] && src="$LOG" || src="$LOG.$prev"
      dst="$LOG.$i"
      [ -f "$src" ] && mv "$src" "$dst" 2>/dev/null
      i=$((i-1))
    done
    : > "$LOG"
  fi
}

log_storage_guard() {
  dir=$(dirname "$LOG")
  [ -d "$dir" ] || return 0
  max_kb=$(( ${LOG_MAX_TOTAL_MB:-10} * 1024 ))
  total=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
  [ -z "$total" ] && return 0
  [ "$total" -le "$max_kb" ] && return 0
  # Keep the newest small active log and remove old rotated/exported log files first.
  find "$dir" -type f ! -name 'bt-stability.log' -delete 2>/dev/null
  : > "$LOG" 2>/dev/null
  echo "$(date '+%F %T')  Log storage guard trimmed logs after exceeding ${LOG_MAX_TOTAL_MB:-10}MB" >> "$LOG"
}

log() {
  msg="$1"
  _log_should_keep "$msg" || return 0
  _log_dedup_ok "$msg" || return 0
  mkdir -p "$(dirname "$LOG")" "$STATE_DIR" 2>/dev/null
  log_rotate_enforce
  echo "$(date '+%F %T')  $msg" >> "$LOG"
  log_storage_guard
}

package_running() { pkg="$1"; [ -n "$pkg" ] || return 1; pidof "$pkg" >/dev/null 2>&1 && return 0; ps -A 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; ps 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; return 1; }
package_installed() { pkg="$1"; [ -n "$pkg" ] || return 1; cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; }
first_installed_from_list() { for pkg in $1; do package_installed "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
first_running_from_list() { for pkg in $1; do package_running "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
whitelist_pkg() { pkg="$1"; [ -n "$pkg" ] || return 0; cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1 && log "Whitelisted from idle: $pkg"; }
appops_allow_safe() { pkg="$1"; op="$2"; package_installed "$pkg" || return 0; cmd appops set "$pkg" "$op" allow >/dev/null 2>&1 && log "AppOps allow: $pkg $op"; }


sdk_int() { getprop ro.build.version.sdk 2>/dev/null; }
build_id() { getprop ro.build.id 2>/dev/null; }
build_fingerprint() { getprop ro.build.fingerprint 2>/dev/null; }
security_patch() { getprop ro.build.version.security_patch 2>/dev/null; }
build_family() { build_id | sed 's/[0-9].*//' 2>/dev/null; }
write_metric_json() { file="$1"; shift; mkdir -p "$STATE_DIR" "${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"; printf '%s\n' "$*" > "$file"; }
is_pixel_android16_may2026() { is_pixel_device || return 1; [ "$(sdk_int)" -ge "$ANDROID16_SDK" ] || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; echo "$bid $fp" | grep -q "$PIXEL_ANDROID16_MAY2026_BUILD_PREFIX"; }
is_android17_or_newer() { [ "$(sdk_int)" -ge "$ANDROID17_SDK" ]; }
is_pixel_android17() { is_pixel_device || return 1; is_android17_or_newer || return 1; }
is_known_pixel_android17_build_family() { is_pixel_android17 || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; for prefix in $PIXEL_ANDROID17_KNOWN_BUILD_PREFIXES; do echo "$bid $fp" | grep -q "$prefix" && return 0; done; return 1; }
brand_lc() { getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
manufacturer_lc() { getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
is_pixel_device() { [ "$(brand_lc)" = "google" ] || echo "$(getprop ro.product.model 2>/dev/null)" | grep -qi '^pixel'; }
is_samsung_device() { [ "$(manufacturer_lc)" = "samsung" ] || [ "$(brand_lc)" = "samsung" ]; }
is_miui_device() { getprop ro.miui.ui.version.name 2>/dev/null | grep -q . || [ "$(brand_lc)" = "xiaomi" ] || [ "$(brand_lc)" = "redmi" ] || [ "$(brand_lc)" = "poco" ]; }
recent_bt_stall_score_penalty() {
  active_bluetooth_game >/dev/null 2>&1 || { echo 0; return; }
  logcat -d -t 180 2>/dev/null | grep -iE 'gatt.*(133|257|timeout|busy|congested)|bt_stack.*(timeout|hci|acl|l2cap)|bluetooth.*(binder died|dead object|gattservice)|scan.*(failed|stopped|throttle)|location.*(stale|timeout|throttle)|pokemod|vpgp|go plus' >/dev/null 2>&1 && echo 20 || echo 0
}
bluetooth_health_score() {
  score=100
  [ "$(bt_enabled_setting)" = 1 ] || score=$((score-35))
  [ "$(bt_process_count)" -gt 0 ] || score=$((score-25))
  health_bad_state && score=$((score-20))
  penalty=$(recent_bt_stall_score_penalty); score=$((score-penalty))
  active_bluetooth_game >/dev/null 2>&1 && [ "$penalty" -gt 0 ] && score=$((score-10))
  [ "$score" -lt 0 ] && score=0
  echo "$score"
}
export_bluetooth_health_score() {
  [ "${ENABLE_BLUETOOTH_HEALTH_SCORE:-1}" = 1 ] || return 0
  metrics_dir="${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"; mkdir -p "$metrics_dir"
  score=$(bluetooth_health_score)
  cat > "$metrics_dir/bluetooth-health.json" <<EOF
{
  "timestamp": "$(date '+%F %T')",
  "score": $score,
  "device": "$(getprop ro.product.brand 2>/dev/null) $(getprop ro.product.model 2>/dev/null)",
  "sdk": "$(sdk_int)",
  "android": "$(getprop ro.build.version.release 2>/dev/null)",
  "build_id": "$(build_id)",
  "security_patch": "$(security_patch)",
  "active_pokemon_go": "$(active_pokemon_go 2>/dev/null)",
  "active_pokemod_vpgp3": "$(active_pokemod 2>/dev/null)",
  "bt_enabled_setting": "$(bt_enabled_setting)",
  "bt_process_count": "$(bt_process_count)"
}
EOF
  echo "$score"
}
check_android_support() { [ "$ENABLE_ANDROID_VERSION_WARNINGS" = 1 ] || return; sdk=$(sdk_int); [ -z "$sdk" ] && return; if [ "$sdk" -lt "$SUPPORTED_SDK_MIN" ] || [ "$sdk" -gt "$SUPPORTED_SDK_MAX" ]; then log "Android SDK warning: sdk=$sdk outside tested range $SUPPORTED_SDK_MIN-$SUPPORTED_SDK_MAX"; fi; }
apply_device_profile() {
  [ "$ENABLE_SDK_AWARE_TUNING" = 1 ] || return
  sdk=$(sdk_int)
  if is_pixel_device && [ "$ENABLE_PIXEL_TUNING" = 1 ]; then
    log "Device profile: Pixel/Google"
    ENABLE_A2DP_OFFLOAD_DISABLE=1
    APPLY_RESTRICTED_STANDBY_FIXES=1
    [ "$sdk" -ge "$ANDROID16_SDK" ] && [ "$ENABLE_PIXEL_ANDROID16_GUARDS" = 1 ] && { WATCHDOG_INTERVAL=25; FAILURE_THRESHOLD=2; log "Android 16+ Pixel guards active"; }
    if [ "$ENABLE_PIXEL_ANDROID17_GUARD" = 1 ] && is_pixel_android17; then
      WATCHDOG_INTERVAL="$PIXEL_ANDROID17_WATCHDOG_INTERVAL"
      RECOVERY_COOLDOWN="$PIXEL_ANDROID17_RECOVERY_COOLDOWN"
      STALE_SESSION_MINUTES="$PIXEL_ANDROID17_STALE_SESSION_MINUTES"
      FAILURE_THRESHOLD="$PIXEL_ANDROID17_FAILURE_THRESHOLD"
      COMPANION_DEVICE_KEEPALIVE_INTERVAL="$ANDROID17_COMPANION_KEEPALIVE_INTERVAL"
      GMS_LOCATION_KEEPALIVE_INTERVAL="$ANDROID17_GMS_LOCATION_KEEPALIVE_INTERVAL"
      ENABLE_BLE_KEEPALIVE=1
      ENABLE_GMS_LOCATION_KEEPALIVE=1
      ENABLE_COMPANION_DEVICE_KEEPALIVE=1
      ENABLE_ANDROID17_COMPANION_PERMISSION_OBSERVE=1
      ENABLE_ANDROID17_BLE_PRIVACY_GUARD=1
      log "Pixel Android 17 guard active: build=$(build_id) sdk=$(sdk_int) known_family=$(is_known_pixel_android17_build_family && echo yes || echo no) interval=${WATCHDOG_INTERVAL}s stale=${STALE_SESSION_MINUTES}m"
    elif [ "$ENABLE_PIXEL_MAY2026_CP1A_GUARD" = 1 ] && is_pixel_android16_may2026; then
      WATCHDOG_INTERVAL="$PIXEL_CP1A_WATCHDOG_INTERVAL"
      RECOVERY_COOLDOWN="$PIXEL_CP1A_RECOVERY_COOLDOWN"
      STALE_SESSION_MINUTES="$PIXEL_CP1A_STALE_SESSION_MINUTES"
      FAILURE_THRESHOLD="$PIXEL_CP1A_FAILURE_THRESHOLD"
      ENABLE_BLE_KEEPALIVE=1
      ENABLE_GMS_LOCATION_KEEPALIVE=1
      ENABLE_ANDROID16_BOND_LOSS_OBSERVE=1
      ENABLE_ANDROID16_COMPANION_DEVICE_OBSERVE=1
      log "Pixel Android 16 May 2026 CP1A guard active: build=$(build_id) interval=${WATCHDOG_INTERVAL}s stale=${STALE_SESSION_MINUTES}m"
    fi
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

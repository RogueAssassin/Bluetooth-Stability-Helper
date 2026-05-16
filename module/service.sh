#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
LOG="$CONFIG_DIR/logs/bt-stability.log"
STATE_DIR="$CONFIG_DIR/state"
EXPORT_DIR="$CONFIG_DIR/export"
USERCFG="$CONFIG_DIR/user-config.sh"
RESTARTS_FILE="$STATE_DIR/restarts.txt"
LAST_RECOVERY_FILE="$STATE_DIR/last_recovery.txt"
FAIL_COUNT_FILE="$STATE_DIR/fail_count.txt"
SESSION_KEY_FILE="$STATE_DIR/vpgp3_session_key"
SESSION_START_FILE="$STATE_DIR/vpgp3_session_start"
LAST_STALE_FILE="$STATE_DIR/vpgp3_last_stale"
LAST_KEEPALIVE_FILE="$STATE_DIR/last_ble_keepalive"
LAST_GMS_LOCATION_KEEPALIVE_FILE="$STATE_DIR/last_gms_location_keepalive"
LAST_COMPANION_KEEPALIVE_FILE="$STATE_DIR/last_companion_keepalive"
INTERACTION_FREEZE_FILE="$STATE_DIR/interaction_freeze_count"
LAST_INTERACTION_RECOVERY_FILE="$STATE_DIR/last_interaction_recovery"
mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$CONFIG_DIR/logs" "$EXPORT_DIR" "$CONFIG_DIR/import"
. "$MODDIR/common/config.sh"
[ -f "$USERCFG" ] && . "$USERCFG"
. "$MODDIR/scripts/lib.sh"

rotate_log_if_needed() { [ -f "$LOG" ] || return; size_kb=$(du -k "$LOG" | awk '{print $1}'); [ "$size_kb" -gt "$LOG_ROTATE_SIZE_KB" ] && mv "$LOG" "$LOG.1" 2>/dev/null && touch "$LOG"; }
wait_until_boot_complete() { until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done; sleep 25; }
ensure_files() { mkdir -p "$STATE_DIR" "$EXPORT_DIR" "$CONFIG_DIR/logs" "$CONFIG_DIR/import"; [ -f "$USERCFG" ] || cat > "$USERCFG" <<'EOF'
# Bluetooth Stability Helper local overrides.
# Keep this file under /sdcard/Bluetooth-Stability-Helper/ so Downloads stays clean.
# Example safe overrides:
# WATCHDOG_INTERVAL=45
# STALE_SESSION_MINUTES=42
# ENABLE_A2DP_OFFLOAD_DISABLE=1
EOF
}

apply_adaptive_defaults() {
  apply_device_profile
  log "Engine profile: adaptive Bluetooth stability; primary target Pixel + Android 12-16; VPGP³+ aware"
}

apply_appops_for_pkg() {
  pkg="$1"; package_installed "$pkg" || return 0
  appops_allow_safe "$pkg" WAKE_LOCK
  appops_allow_safe "$pkg" RUN_ANY_IN_BACKGROUND
  appops_allow_safe "$pkg" RUN_IN_BACKGROUND
  appops_allow_safe "$pkg" START_FOREGROUND
  appops_allow_safe "$pkg" BLUETOOTH_CONNECT
  appops_allow_safe "$pkg" BLUETOOTH_SCAN
  appops_allow_safe "$pkg" FINE_LOCATION
  appops_allow_safe "$pkg" ACCESS_FINE_LOCATION
  appops_allow_safe "$pkg" COARSE_LOCATION
  appops_allow_safe "$pkg" POST_NOTIFICATION
  appops_allow_safe "$pkg" SCHEDULE_EXACT_ALARM
  appops_allow_safe "$pkg" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  if [ "$ENABLE_ANDROID16_JOB_STANDBY_GUARD" = 1 ]; then
    am set-standby-bucket "$pkg" active >/dev/null 2>&1 && log "Standby bucket active: $pkg"
    cmd jobscheduler monitor-battery off >/dev/null 2>&1
  fi
  # Keep appops conservative; do not touch VPN or LSPosed/Vector style hooks.
}

apply_static_tuning() {
  check_android_support
  [ "$WHITELIST_BLUETOOTH" = 1 ] && whitelist_pkg com.android.bluetooth
  [ "$WHITELIST_GMS" = 1 ] && whitelist_pkg com.google.android.gms
  if [ "$WHITELIST_POKEMON_GO" = 1 ]; then for pkg in $POKEMON_GO_PACKAGE_CANDIDATES; do package_installed "$pkg" && whitelist_pkg "$pkg"; done; fi
  if [ "$WHITELIST_POKEMOD" = 1 ]; then for pkg in $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do package_installed "$pkg" && whitelist_pkg "$pkg"; done; fi
  for pkg in $WHITELIST_EXTRA_PACKAGES; do whitelist_pkg "$pkg"; done
  if [ "$APPLY_RESTRICTED_STANDBY_FIXES" = 1 ]; then
    for pkg in com.android.bluetooth com.google.android.gms $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do
      package_installed "$pkg" || continue
      cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
      cmd appops set "$pkg" RUN_IN_BACKGROUND allow >/dev/null 2>&1
      cmd appops set "$pkg" START_FOREGROUND allow >/dev/null 2>&1
      cmd appops set "$pkg" WAKE_LOCK allow >/dev/null 2>&1
      am set-inactive "$pkg" false >/dev/null 2>&1
    done
  fi
  if [ "$APPLY_APP_OPS_FIXES" = 1 ]; then
    for pkg in com.android.bluetooth com.google.android.gms $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES $BLUETOOTH_GAME_PACKAGE_CANDIDATES; do apply_appops_for_pkg "$pkg"; done
  fi
  [ "$ENABLE_BLE_SCAN_ALWAYS" = 1 ] && settings put global ble_scan_always_enabled 1 >/dev/null 2>&1
  [ "$ENABLE_WIFI_SCAN_THROTTLE_OFF" = 1 ] && settings put global wifi_scan_throttle_enabled 0 >/dev/null 2>&1
  [ "$ENABLE_LOCATION_BG_THROTTLE_OFF" = 1 ] && settings put global location_background_throttle_interval_ms 0 >/dev/null 2>&1
  [ "$ENABLE_DEVICE_IDLE_TUNING" = 1 ] && settings put global device_idle_constants "$DEVICE_IDLE_CONSTANTS" >/dev/null 2>&1
  [ "$ENABLE_A2DP_OFFLOAD_DISABLE" = 1 ] && { resetprop -n persist.bluetooth.a2dp_offload.disabled true 2>/dev/null; resetprop -n persist.vendor.bluetooth.a2dp_offload.disabled true 2>/dev/null; }
}

bt_enabled_setting() { settings get global bluetooth_on 2>/dev/null; }
bt_process_count() { count=0; for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service android.hardware.bluetooth.audio-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do pidof "$name" >/dev/null 2>&1 && count=$((count+1)); done; echo "$count"; }
health_bad_state() { summary="$(dumpsys bluetooth_manager 2>/dev/null | tr '[:upper:]' '[:lower:]')"; echo "$summary" | grep -q "state:.*on" && return 1; echo "$summary" | grep -q "enabled: true" && return 1; return 0; }

active_bluetooth_game() { for pkg in $BLUETOOTH_GAME_PACKAGE_CANDIDATES; do package_running "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
active_pokemod() { first_running_from_list "$POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES"; }
active_pokemon_go() { first_running_from_list "$POKEMON_GO_PACKAGE_CANDIDATES"; }

location_health_check() {
  [ "$CHECK_LOCATION_MODE" = 1 ] || return 1
  mode=$(settings get secure location_mode 2>/dev/null)
  [ "$mode" = 3 ] || [ "$mode" = 1 ] || { log "Location warning: location_mode=$mode; Pokémon GO/Pokemod BLE sessions may stall"; return 0; }
  [ "$CHECK_BLE_SCAN_SETTINGS" = 1 ] && [ "$(settings get global ble_scan_always_enabled 2>/dev/null)" != 1 ] && log "BLE scan warning: ble_scan_always_enabled is not 1"
  return 1
}

ble_keepalive() {
  [ "$ENABLE_BLE_KEEPALIVE" = 1 ] || return
  now=$(date +%s); last=$(cat "$LAST_KEEPALIVE_FILE" 2>/dev/null); [ -n "$last" ] && [ $((now-last)) -lt "$BLE_KEEPALIVE_INTERVAL" ] && return
  dumpsys bluetooth_manager >/dev/null 2>&1
  dumpsys bluetooth_manager --proto >/dev/null 2>&1
  echo "$now" > "$LAST_KEEPALIVE_FILE"
  log "BLE keepalive poll executed"
}


gms_location_keepalive() {
  [ "$ENABLE_GMS_LOCATION_KEEPALIVE" = 1 ] || return
  active_bluetooth_game >/dev/null 2>&1 || return
  now=$(date +%s); last=$(cat "$LAST_GMS_LOCATION_KEEPALIVE_FILE" 2>/dev/null)
  [ -n "$last" ] && [ $((now-last)) -lt "$GMS_LOCATION_KEEPALIVE_INTERVAL" ] && return
  dumpsys location >/dev/null 2>&1
  dumpsys activity service com.google.android.gms/.chimera.GmsBoundBrokerService >/dev/null 2>&1
  dumpsys activity provider com.google.android.gms >/dev/null 2>&1
  echo "$now" > "$LAST_GMS_LOCATION_KEEPALIVE_FILE"
  log "GMS/location keepalive poll executed for active Bluetooth game"
}

companion_device_keepalive() {
  [ "$ENABLE_COMPANION_DEVICE_KEEPALIVE" = 1 ] || return
  active_bluetooth_game >/dev/null 2>&1 || return
  now=$(date +%s); last=$(cat "$LAST_COMPANION_KEEPALIVE_FILE" 2>/dev/null)
  [ -n "$last" ] && [ $((now-last)) -lt "$COMPANION_DEVICE_KEEPALIVE_INTERVAL" ] && return
  dumpsys companiondevice >/dev/null 2>&1
  dumpsys bluetooth_manager >/dev/null 2>&1
  echo "$now" > "$LAST_COMPANION_KEEPALIVE_FILE"
  log "CompanionDevice/Bluetooth keepalive poll executed for Android 16 presence/bond tracking"
}

pixel_connectivity_snapshot() {
  [ "$ENABLE_PIXEL_CONNECTIVITY_SNAPSHOT_ON_STALL" = 1 ] || return
  is_pixel_device || return
  ts=$(date '+%Y%m%d-%H%M%S')
  out="$EXPORT_DIR/pixel-connectivity-$ts.txt"
  {
    echo "Bluetooth Stability Helper Pixel connectivity snapshot"
    echo "Time: $(date '+%F %T')"
    echo "Build: $(getprop ro.build.id) / $(getprop ro.build.fingerprint)"
    echo "SDK: $(getprop ro.build.version.sdk)"
    echo
    echo "--- bluetooth_manager ---"; dumpsys bluetooth_manager 2>/dev/null
    echo
    echo "--- bluetooth_manager proto size check ---"; dumpsys bluetooth_manager --proto 2>/dev/null | wc -c
    echo
    echo "--- companiondevice ---"; dumpsys companiondevice 2>/dev/null
    echo
    echo "--- location ---"; dumpsys location 2>/dev/null
    echo
    echo "--- thermalservice ---"; dumpsys thermalservice 2>/dev/null
    echo
    echo "--- recent bt/log patterns ---"; logcat -d -t 360 2>/dev/null | grep -iE 'bluetooth|bt_stack|gatt|hci|l2cap|companion|bond|encryption|niantic|pokemod|vpgp|location|fused' | tail -260
  } > "$out" 2>/dev/null
  log "Pixel connectivity snapshot exported: $out"
}

android16_connectivity_change_patterns() {
  [ "$ENABLE_ANDROID16_BOND_LOSS_OBSERVE" = 1 ] || return 1
  [ "$(sdk_int)" -ge "$ANDROID16_SDK" ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  logcat -d -t 360 2>/dev/null | grep -iE 'bond.*(loss|lost|none|removed)|encryption.*(change|failed|lost)|companion.*(presence|unbound|disconnected|timeout)|cdm.*(presence|unbound)|bluetooth.*(bond|encryption)' >/dev/null 2>&1 || return 1
  log "Android 16 connectivity observer matched bond/encryption/companion-device change pattern"
  pixel_connectivity_snapshot
  return 0
}

interaction_freeze_patterns() {
  [ "$ENABLE_INTERACTION_FREEZE_GUARD" = 1 ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  # The freeze normally appears as GATT busy/timeout, binder death, scan pause,
  # or Pokémon GO/Google Play services location stalls while the accessory remains connected.
  logcat -d -t "$INTERACTION_FREEZE_WINDOW_SECONDS" 2>/dev/null | grep -iE 'gatt.*(busy|133|257|timeout|disconnect|stuck|dead)|bluetoothgatt.*(busy|timeout|status=133)|bt_stack.*(timeout|hci|acl|l2cap|gatt)|bluetooth.*(binder died|dead object|adapter service|profile service|gattservice)|scan.*(failed|stopped|too frequent|throttle)|niantic|pokemod|vpgp|go plus|plus\+|fused.*(stale|timeout)|location.*(stale|throttle|no last location)' >/dev/null 2>&1 || return 1
  c=$(cat "$INTERACTION_FREEZE_FILE" 2>/dev/null); [ -z "$c" ] && c=0; c=$((c+1)); echo "$c" > "$INTERACTION_FREEZE_FILE"
  log "Interaction freeze guard matched recent BLE/location/app stall pattern count=$c"
  [ "$POKEMONPLUS_AUTO_EXPORT_ON_STALL" = 1 ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
  pixel_connectivity_snapshot
  [ "$c" -ge "$INTERACTION_FREEZE_RECOVERY_AFTER_MATCHES" ] || return 1
  now=$(date +%s); last=$(cat "$LAST_INTERACTION_RECOVERY_FILE" 2>/dev/null); [ -n "$last" ] && [ $((now-last)) -lt "$RECOVERY_COOLDOWN" ] && return 1
  echo "$now" > "$LAST_INTERACTION_RECOVERY_FILE"
  return 0
}

reset_interaction_freeze_count() { echo 0 > "$INTERACTION_FREEZE_FILE"; }

scan_stall_patterns() {
  [ "$ENABLE_GO_PLUS_STALL_PATTERNS" = 1 ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  logcat -d -t 260 2>/dev/null | grep -iE 'gatt.*(133|257|timeout|disconnect|dead|busy)|go plus.*(disconnect|timeout|stale)|vpgp|vpgp3|ble.*(scan.*failed|stopped|timeout)|location.*(stale|throttle)|fused.*stale|bt_stack.*(hci|timeout)|bluetooth.*(crash|dead object|binder died)' >/dev/null 2>&1 || return 1
  log "Recent logs contain BLE/GATT/location stall pattern while a Bluetooth-aware game is active"
  [ "$POKEMONPLUS_AUTO_EXPORT_ON_STALL" = 1 ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
  return 0
}

track_vpgp3_session() {
  [ "$ENABLE_STALE_SESSION_WATCHDOG" = 1 ] || return 1
  go=$(active_pokemon_go); pm=$(active_pokemod); game=$(active_bluetooth_game)
  [ -n "$go$pm$game" ] || { rm -f "$SESSION_START_FILE" "$SESSION_KEY_FILE" 2>/dev/null; return 1; }
  key="go=${go:-none} pokemod=${pm:-none} btgame=${game:-none}"
  now=$(date +%s); oldkey=$(cat "$SESSION_KEY_FILE" 2>/dev/null)
  if [ "$oldkey" != "$key" ] || [ ! -f "$SESSION_START_FILE" ]; then
    echo "$key" > "$SESSION_KEY_FILE"; echo "$now" > "$SESSION_START_FILE"
    log "Bluetooth game/VPGP³+ session observed: $key"
    return 1
  fi
  start=$(cat "$SESSION_START_FILE" 2>/dev/null); [ -z "$start" ] && echo "$now" > "$SESSION_START_FILE" && return 1
  age_min=$(( (now-start) / 60 ))
  if [ "$age_min" -ge "$STALE_SESSION_MINUTES" ]; then
    last=$(cat "$LAST_STALE_FILE" 2>/dev/null); [ -n "$last" ] && [ $((now-last)) -lt 900 ] && return 1
    echo "$now" > "$LAST_STALE_FILE"
    log "Possible stale $VPGP3_DISPLAY_NAME / Bluetooth game session: age=${age_min}m key=$key"
    [ "$POKEMONPLUS_AUTO_EXPORT_ON_STALL" = 1 ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
    [ "$STALE_SESSION_ACTION" = "bt_refresh" ] && [ "$STALE_SESSION_BT_REFRESH" = 1 ] && return 0
  fi
  return 1
}

pokemon_stack_health_bad() {
  [ "$POKEMOD_CHECK_ENABLED" = 1 ] || return 1
  go=$(active_pokemon_go); pinst=$(first_installed_from_list "$POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES"); prun=$(active_pokemod)
  [ -n "$prun" ] && log "Pokemod/$VPGP3_DISPLAY_NAME running: $prun"
  if [ -n "$go" ] && [ "$POKEMOD_REQUIRED_FOR_GO" = 1 ] && [ -n "$pinst" ] && [ -z "$prun" ]; then
    log "Pokémon GO running but installed Pokemod/$VPGP3_DISPLAY_NAME package is not detected running"
    return 0
  fi
  return 1
}

count_recent_restarts() { now=$(date +%s); cutoff=$((now - 3600)); [ -f "$RESTARTS_FILE" ] || { echo 0; return; }; awk -v cutoff="$cutoff" '$1 >= cutoff {count++} END {print count+0}' "$RESTARTS_FILE"; }
record_restart() { date +%s >> "$RESTARTS_FILE"; date +%s > "$LAST_RECOVERY_FILE"; }
recovery_cooldown_ok() { [ -f "$LAST_RECOVERY_FILE" ] || return 0; last=$(cat "$LAST_RECOVERY_FILE" 2>/dev/null); [ -z "$last" ] && return 0; delta=$(($(date +%s)-last)); [ "$delta" -ge "$RECOVERY_COOLDOWN" ]; }
get_fail_count() { [ -f "$FAIL_COUNT_FILE" ] && cat "$FAIL_COUNT_FILE" || echo 0; }
set_fail_count() { echo "$1" > "$FAIL_COUNT_FILE"; }
increment_fail_count() { c=$(get_fail_count); c=$((c+1)); set_fail_count "$c"; echo "$c"; }
reset_fail_count() { set_fail_count 0; }
cleanup_restart_history() { now=$(date +%s); cutoff=$((now-7200)); [ -f "$RESTARTS_FILE" ] && awk -v cutoff="$cutoff" '$1 >= cutoff' "$RESTARTS_FILE" > "$RESTARTS_FILE.tmp" && mv "$RESTARTS_FILE.tmp" "$RESTARTS_FILE"; }
repair_audio_route() { [ "$ENABLE_AUDIO_ROUTE_REPAIR" = 1 ] || return; cmd media_session volume --show >/dev/null 2>&1; dumpsys audio >/dev/null 2>&1; log "Audio route repair hint executed"; }

restart_bt_stack() {
  recent=$(count_recent_restarts); [ "$recent" -ge "$MAX_RESTARTS_PER_HOUR" ] && { log "Recovery skipped: max restarts reached $recent/$MAX_RESTARTS_PER_HOUR"; return; }
  recovery_cooldown_ok || { log "Recovery skipped: cooldown active"; return; }
  fails=$(get_fail_count); repair_audio_route
  if [ "$ENABLE_BLUETOOTH_APP_FORCE_STOP" = 1 ] && [ "$fails" -ge 3 ]; then am force-stop com.android.bluetooth >/dev/null 2>&1; sleep 2; log "Bluetooth app force-stop attempted"; fi
  if [ "$ENABLE_ADAPTER_TOGGLE_RECOVERY" = 1 ]; then
    log "Bluetooth adapter safe refresh recovery"
    svc bluetooth disable >/dev/null 2>&1; sleep 4; svc bluetooth enable >/dev/null 2>&1; sleep 7; record_restart
  fi
}

write_status() {
  sdk=$(sdk_int); model=$(getprop ro.product.model 2>/dev/null); brand=$(getprop ro.product.brand 2>/dev/null)
  go=$(active_pokemon_go); pm=$(active_pokemod); game=$(active_bluetooth_game)
  cat > "$LOCAL_STATUS_FILE" <<EOF
Bluetooth Stability Helper v0.9.2
Profile: adaptive
Build ID: $(build_id)
Device: $brand $model SDK=$sdk
Bluetooth enabled setting: $(bt_enabled_setting)
BT process count: $(bt_process_count)
Pixel May 2026 CP1A guard: $(is_pixel_android16_may2026 && echo active || echo inactive)
Active Pokémon GO: ${go:-none}
Active Pokemod/$VPGP3_DISPLAY_NAME: ${pm:-none}
Active Bluetooth-aware game/app: ${game:-none}
Last updated: $(date '+%F %T')
Logs: $LOG
EOF
}

main_loop() {
  while true; do
    rotate_log_if_needed; cleanup_restart_history; ensure_files
    . "$MODDIR/common/config.sh"; [ -f "$USERCFG" ] && . "$USERCFG"; . "$MODDIR/scripts/lib.sh"; apply_adaptive_defaults
    bad=0
    if [ "$WATCHDOG_ENABLED" = 1 ]; then
      proc_count=$(bt_process_count)
      [ "$ENABLE_BT_PROCESS_CHECK" = 1 ] && [ "$(bt_enabled_setting)" = 1 ] && [ "$proc_count" -eq 0 ] && { log "Bluetooth enabled but no known Bluetooth process found"; bad=1; }
      [ "$ENABLE_BT_MANAGER_CHECK" = 1 ] && health_bad_state && { log "bluetooth_manager did not report ON/true"; bad=1; }
      location_health_check
      ble_keepalive
      gms_location_keepalive
      companion_device_keepalive
      android16_connectivity_change_patterns && bad=1
      interaction_freeze_patterns && bad=1
      scan_stall_patterns && bad=1
      track_vpgp3_session && bad=1
      if pokemon_stack_health_bad; then [ "$POKEMOD_WARN_ONLY" = 1 ] && log "Pokemod/$VPGP3_DISPLAY_NAME signal warn-only; not triggering BT recovery" || bad=1; fi
      if [ "$bad" = 1 ]; then fails=$(increment_fail_count); log "Failure count: $fails/$FAILURE_THRESHOLD"; [ "$fails" -ge "$FAILURE_THRESHOLD" ] && restart_bt_stack && reset_fail_count && reset_interaction_freeze_count; else reset_fail_count; reset_interaction_freeze_count; fi
    fi
    write_status
    sleep "$WATCHDOG_INTERVAL"
  done
}

wait_until_boot_complete
ensure_files
log "Bluetooth Stability Helper 0.9.2 adaptive engine start"
apply_adaptive_defaults
apply_static_tuning
MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
main_loop

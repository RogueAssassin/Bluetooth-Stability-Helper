#!/system/bin/sh
MODDIR=${0%/*}
# Compatibility safety: never run when the module is disabled or being removed.
[ -f "$MODDIR/disable" ] && exit 0
[ -f "$MODDIR/remove" ] && exit 0

# Avoid duplicate long-running service instances after manager/service restarts.
LOCK_DIR="/data/adb/bsh-service.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then exit 0; fi
  rm -rf "$LOCK_DIR" 2>/dev/null
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT INT TERM
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
LOG="$CONFIG_DIR/logs/bt-stability.log"
STATE_DIR="$CONFIG_DIR/state"
EXPORT_DIR="$CONFIG_DIR/export"
USERCFG="$CONFIG_DIR/user-config.sh"
RESTARTS_FILE="$STATE_DIR/restarts.txt"
LAST_RECOVERY_FILE="$STATE_DIR/last_recovery.txt"
FAIL_COUNT_FILE="$STATE_DIR/fail_count.txt"
LAST_FAILURE_SIGNAL_FILE="$STATE_DIR/last_failure_signal.txt"
SESSION_KEY_FILE="$STATE_DIR/vpgp3_session_key"
SESSION_START_FILE="$STATE_DIR/vpgp3_session_start"
LAST_STALE_FILE="$STATE_DIR/vpgp3_last_stale"
LAST_HEALTH_EXPORT_FILE="$STATE_DIR/last_health_export"
RECOVERY_HISTORY_FILE="$CONFIG_DIR/metrics/recovery-history.jsonl"
INTERACTION_FREEZE_FILE="$STATE_DIR/interaction_freeze_count"
LAST_INTERACTION_RECOVERY_FILE="$STATE_DIR/last_interaction_recovery"
mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$CONFIG_DIR/logs" "$EXPORT_DIR" "$CONFIG_DIR/import" "$CONFIG_DIR/metrics"
. "$MODDIR/common/config.sh"
. "$MODDIR/scripts/lib.sh"

rotate_log_if_needed() { log_rotate_enforce 2>/dev/null; log_storage_guard 2>/dev/null; }

cleanup_boot_logs() {
  [ "${LOG_BOOT_CLEAN:-1}" = "1" ] || return 0
  mkdir -p "$CONFIG_DIR/logs" "$EXPORT_DIR" "$CONFIG_DIR/metrics" "$STATE_DIR"
  find "$CONFIG_DIR/logs" -type f -delete 2>/dev/null
  find "$EXPORT_DIR" -type f -delete 2>/dev/null
  find "$STATE_DIR" -type f -name 'logdedup_*' -delete 2>/dev/null
  find "$STATE_DIR" -type f -name 'fault-signature-*' -delete 2>/dev/null
  rm -f "$STATE_DIR/last-fresh-fault-epoch" "$STATE_DIR/last-fresh-fault.txt" 2>/dev/null
  : > "$RECOVERY_HISTORY_FILE" 2>/dev/null
  : > "$CONFIG_DIR/metrics/bluetooth-health.json" 2>/dev/null
  echo "$(date '+%F %T')  Boot cleanup completed: old logs/exports removed" > "$LOG"
}

cap_runtime_files() {
  # Keep exported diagnostics and snapshots bounded; these are the files that can grow fast.
  if [ -d "$EXPORT_DIR" ]; then
    keep=${EXPORT_MAX_FILES:-8}; count=0
    for f in $(ls -1t "$EXPORT_DIR" 2>/dev/null); do
      count=$((count+1)); [ "$count" -le "$keep" ] && continue
      rm -f "$EXPORT_DIR/$f" 2>/dev/null
    done
    keep_snap=${SNAPSHOT_MAX_FILES:-4}; count=0
    for f in $(ls -1t "$EXPORT_DIR"/pixel-connectivity-*.txt 2>/dev/null); do
      count=$((count+1)); [ "$count" -le "$keep_snap" ] && continue
      rm -f "$f" 2>/dev/null
    done
  fi
  [ -d "$CONFIG_DIR/metrics" ] && find "$CONFIG_DIR/metrics" -type f -size +${METRICS_MAX_KB:-512}k -exec sh -c ': > "$1"' _ {} \; 2>/dev/null
}
wait_until_boot_complete() { until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done; sleep 25; }
ensure_files() {
  mkdir -p "$STATE_DIR" "$EXPORT_DIR" "$CONFIG_DIR/logs" "$CONFIG_DIR/import" "$CONFIG_DIR/metrics"
  [ -f "$MODDIR/state/install-report.txt" ] && cp "$MODDIR/state/install-report.txt" "$CONFIG_DIR/install-report.txt" 2>/dev/null
  [ -f "$MODDIR/state/install-profile.txt" ] && cp "$MODDIR/state/install-profile.txt" "$STATE_DIR/install-profile.txt" 2>/dev/null
  [ -f "$USERCFG" ] || cat > "$USERCFG" <<'EOF'
# Bluetooth Stability Helper local overrides.
# Keep this file under /sdcard/Bluetooth-Stability-Helper/ so Downloads stays clean.
# Example safe overrides:
# WATCHDOG_INTERVAL=45
# STALE_SESSION_MINUTES=20
# ENABLE_A2DP_OFFLOAD_DISABLE=0
EOF
}

apply_adaptive_defaults() {
  apply_device_profile
  load_user_config "$USERCFG"
  log "Engine profile: adaptive Bluetooth stability; primary target Pixel + Android 12-17; monthly patch aware; Pokémon GO/Pokemod/VPGP³+ name-aware"
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
  appops_allow_safe "$pkg" AUTO_REVOKE_PERMISSIONS_IF_UNUSED
  if [ "$ENABLE_ANDROID16_JOB_STANDBY_GUARD" = 1 ]; then
    am set-standby-bucket "$pkg" active >/dev/null 2>&1 && log "Standby bucket active: $pkg"
  fi
  # Keep appops conservative; do not touch VPN or LSPosed/Vector style hooks.
}

backup_global_setting() {
  key="$1"; backup="$MODDIR/state/original-global-settings.txt"
  grep -q "^$key|" "$backup" 2>/dev/null && return 0
  value=$(settings get global "$key" 2>/dev/null)
  printf '%s|%s\n' "$key" "${value:-null}" >> "$backup"
}

put_global_setting() {
  key="$1"; value="$2"
  backup_global_setting "$key"
  settings put global "$key" "$value" >/dev/null 2>&1
}

backup_property() {
  key="$1"; backup="$MODDIR/state/original-properties.txt"
  grep -q "^$key|" "$backup" 2>/dev/null && return 0
  value=$(getprop "$key" 2>/dev/null)
  [ -n "$value" ] || value="__EMPTY__"
  printf '%s|%s\n' "$key" "$value" >> "$backup"
}

put_property() {
  key="$1"; value="$2"
  backup_property "$key"
  resetprop -n "$key" "$value" >/dev/null 2>&1
}

apply_static_tuning() {
  check_android_support
  [ "$WHITELIST_BLUETOOTH" = 1 ] && whitelist_pkg com.android.bluetooth
  [ "$WHITELIST_GMS" = 1 ] && whitelist_pkg com.google.android.gms
  if [ "$WHITELIST_POKEMON_GO" = 1 ]; then for pkg in $POKEMON_GO_PACKAGE_CANDIDATES; do package_installed "$pkg" && whitelist_pkg "$pkg"; done; fi
  if [ "$WHITELIST_POKEMOD" = 1 ]; then for pkg in $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do package_installed "$pkg" && whitelist_pkg "$pkg"; done; fi
  for pkg in $WHITELIST_EXTRA_PACKAGES; do whitelist_pkg "$pkg"; done
  if [ "$APPLY_RESTRICTED_STANDBY_FIXES" = 1 ]; then
    for pkg in $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do
      package_installed "$pkg" || continue
      am set-inactive "$pkg" false >/dev/null 2>&1
      am set-standby-bucket "$pkg" active >/dev/null 2>&1
    done
  fi
  if [ "$APPLY_APP_OPS_FIXES" = 1 ]; then
    for pkg in $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do apply_appops_for_pkg "$pkg"; done
  fi
  [ "$ENABLE_BLE_SCAN_ALWAYS" = 1 ] && put_global_setting ble_scan_always_enabled 1
  [ "$ENABLE_WIFI_SCAN_THROTTLE_OFF" = 1 ] && put_global_setting wifi_scan_throttle_enabled 0
  [ "$ENABLE_LOCATION_BG_THROTTLE_OFF" = 1 ] && put_global_setting location_background_throttle_interval_ms 0
  [ "$ENABLE_DEVICE_IDLE_TUNING" = 1 ] && put_global_setting device_idle_constants "$DEVICE_IDLE_CONSTANTS"
  [ "$ENABLE_A2DP_OFFLOAD_DISABLE" = 1 ] && {
    put_property persist.bluetooth.a2dp_offload.disabled true
    put_property persist.vendor.bluetooth.a2dp_offload.disabled true
  }
}

bt_enabled_setting() { settings get global bluetooth_on 2>/dev/null; }
bt_process_count() {
  count=0
  for name in com.android.bluetooth android.hardware.bluetooth-service android.hardware.bluetooth-service.default android.hardware.bluetooth.audio-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do
    pidof "$name" >/dev/null 2>&1 && count=$((count+1))
  done
  if [ "$count" -eq 0 ] && ps -A 2>/dev/null | grep -iE 'com\.android\.bluetooth|android\.hardware\.bluetooth|vendor\..*bluetooth' | grep -v grep >/dev/null 2>&1; then count=1; fi
  echo "$count"
}
health_bad_state() {
  [ "$(bt_enabled_setting)" = 1 ] || return 1
  summary="$(dumpsys bluetooth_manager 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  [ -n "$summary" ] || return 1
  echo "$summary" | grep -Eq 'state:.*on|state *= *on|enabled: *true|isenabled\(\): *true' && return 1
  echo "$summary" | grep -Eq 'state:.*off|state *= *off|enabled: *false|isenabled\(\): *false' && return 0
  return 1
}

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
    echo "--- bluetooth_manager summary ---"; dumpsys bluetooth_manager 2>/dev/null | head -220
    echo
    echo "--- bluetooth_manager proto size check ---"; dumpsys bluetooth_manager --proto 2>/dev/null | wc -c
    echo
    echo "--- companiondevice summary ---"; dumpsys companiondevice 2>/dev/null | head -180
    echo
    echo "--- location summary ---"; dumpsys location 2>/dev/null | head -220
    echo
    echo "--- thermalservice summary ---"; dumpsys thermalservice 2>/dev/null | head -120
    echo
    echo "--- recent bt/log patterns ---"; logcat -d -t ${LOGCAT_CAPTURE_WINDOW_SECONDS:-180} 2>/dev/null | grep -iE 'bluetooth|bt_stack|gatt|hci|l2cap|companion|cdm|bond|encryption|nearby|permission|rpa|privacy|niantic|pokemod|vpgp|location|fused|lmkd|audio focus' | tail -n ${LOGCAT_CAPTURE_LINES:-80}
  } > "$out" 2>/dev/null
  log "Pixel connectivity snapshot exported: $out"
}

android16_connectivity_change_patterns() {
  [ "$ENABLE_ANDROID16_BOND_LOSS_OBSERVE" = 1 ] || return 1
  [ "$(sdk_int)" -ge "$ANDROID16_SDK" ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  fresh_log_fault android16-observer 'bond.*(loss|lost|removed)|encryption.*(failed|lost)|companion.*(unbound|disconnected|timeout)|cdm.*(unbound|timeout)' || return 1
  log "Android 16 connectivity observer matched bond/encryption/companion-device change pattern"
  pixel_connectivity_snapshot
  return 0
}

android17_connectivity_change_patterns() {
  [ "$ENABLE_PIXEL_ANDROID17_GUARD" = 1 ] || return 1
  [ "$(sdk_int)" -ge "$ANDROID17_SDK" ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  # Android 17 can autonomously re-pair after bond loss. Observe that process
  # without toggling the adapter and interrupting the platform recovery.
  fresh_log_fault android17-observer 'companion.*(permission denied|association.*failed|presence.*timeout|disconnected|unbound)|cdm.*(permission denied|association.*failed|presence.*timeout|unbound)|bluetooth.*(scan.*denied|permission denied)|bond.*(loss|lost|key missing)' || return 1
  log "Android 17 connectivity observer matched CDM/permission/BLE/privacy/memory-pressure pattern"
  pixel_connectivity_snapshot
  return 0
}

interaction_freeze_patterns() {
  [ "$ENABLE_INTERACTION_FREEZE_GUARD" = 1 ] || return 1
  active_bluetooth_game >/dev/null 2>&1 || return 1
  # Require a concrete failure. App names by themselves are not fault signals.
  fresh_log_fault interaction-freeze 'gatt.*(status[ =:-]*(133|257)|busy|timeout|congested|disconnect|stuck|dead)|bluetoothgatt.*(busy|timeout|status[ =:-]*133)|bt_stack.*(timeout|hci.*(error|failed|timeout)|acl.*(failed|timeout)|l2cap.*(failed|timeout))|bluetooth.*(binder died|dead object|adapterservice.*(crash|died)|gattservice.*(crash|died))|scan.*(failed|stopped unexpectedly)|fused.*(stale|timeout)|location.*(stale|timeout)' "$INTERACTION_FREEZE_WINDOW_SECONDS" || return 1
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
  fresh_log_fault scan-stall 'gatt.*(status[ =:-]*(133|257)|timeout|disconnect|dead|busy|congested)|go plus.*(disconnect|timeout|stale)|ble.*scan.*(failed|stopped unexpectedly|timeout)|bt_stack.*(hci.*(error|failed|timeout)|timeout)|bluetooth.*(crash|dead object|binder died)' || return 1
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
    # Elapsed time is not proof of a stall. Never toggle Bluetooth from session
    # age alone; concrete fresh log faults drive the recovery ladder instead.
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
record_restart() { now=$(date +%s); echo "$now" >> "$RESTARTS_FILE"; echo "$now" > "$LAST_RECOVERY_FILE"; mkdir -p "$CONFIG_DIR/metrics"; echo "{\"timestamp\":\"$(date '+%F %T')\",\"action\":\"bt_refresh\",\"score\":\"$(bluetooth_health_score 2>/dev/null)\",\"build_id\":\"$(build_id)\"}" >> "$RECOVERY_HISTORY_FILE"; }
recovery_cooldown_ok() { [ -f "$LAST_RECOVERY_FILE" ] || return 0; last=$(cat "$LAST_RECOVERY_FILE" 2>/dev/null); [ -z "$last" ] && return 0; delta=$(($(date +%s)-last)); [ "$delta" -ge "$RECOVERY_COOLDOWN" ]; }
get_fail_count() { [ -f "$FAIL_COUNT_FILE" ] && cat "$FAIL_COUNT_FILE" || echo 0; }
set_fail_count() { echo "$1" > "$FAIL_COUNT_FILE"; }
increment_fail_count() { c=$(get_fail_count); c=$((c+1)); set_fail_count "$c"; echo "$c"; }
reset_fail_count() { set_fail_count 0; }
cleanup_restart_history() { now=$(date +%s); cutoff=$((now-7200)); [ -f "$RESTARTS_FILE" ] && awk -v cutoff="$cutoff" '$1 >= cutoff' "$RESTARTS_FILE" > "$RESTARTS_FILE.tmp" && mv "$RESTARTS_FILE.tmp" "$RESTARTS_FILE"; }
repair_audio_route() { [ "$ENABLE_AUDIO_ROUTE_REPAIR" = 1 ] || return; cmd media_session volume --show >/dev/null 2>&1; dumpsys audio >/dev/null 2>&1; log "Audio route repair hint executed"; }

restart_bt_stack() {
  [ "$(bt_enabled_setting)" = 1 ] || { log "Recovery skipped: Bluetooth is off"; return; }
  recent=$(count_recent_restarts); [ "$recent" -ge "$MAX_RESTARTS_PER_HOUR" ] && { log "Recovery skipped: max restarts reached $recent/$MAX_RESTARTS_PER_HOUR"; return; }
  recovery_cooldown_ok || { log "Recovery skipped: cooldown active"; return; }
  fails=$(get_fail_count); repair_audio_route
  if [ "$ENABLE_BLUETOOTH_APP_FORCE_STOP" = 1 ] && [ "$fails" -ge 3 ]; then am force-stop com.android.bluetooth >/dev/null 2>&1; sleep 2; log "Bluetooth app force-stop attempted"; fi
  if [ "$ENABLE_ADAPTER_TOGGLE_RECOVERY" = 1 ]; then
    log "Bluetooth adapter confirmed-fault refresh recovery"
    pixel_connectivity_snapshot
    if svc bluetooth disable >/dev/null 2>&1; then
      sleep 4
      if svc bluetooth enable >/dev/null 2>&1; then
        sleep 7
        record_restart
        now=$(date +%s); echo "$now" > "$SESSION_START_FILE"
      else
        log "Recovery error: Bluetooth enable command failed"
      fi
    else
      log "Recovery error: Bluetooth disable command failed"
    fi
  fi
}

periodic_health_export() {
  [ "${ENABLE_BLUETOOTH_HEALTH_SCORE:-1}" = 1 ] || return 0
  now=$(date +%s); last=$(cat "$LAST_HEALTH_EXPORT_FILE" 2>/dev/null)
  [ -n "$last" ] && [ $((now-last)) -lt "${HEALTH_SCORE_EXPORT_INTERVAL:-60}" ] && return 0
  echo "$now" > "$LAST_HEALTH_EXPORT_FILE"
  score=$(export_bluetooth_health_score 2>/dev/null)
  [ -n "$score" ] && log "Bluetooth health score: $score"
  return 0
}

write_status() {
  sdk=$(sdk_int); model=$(getprop ro.product.model 2>/dev/null); brand=$(getprop ro.product.brand 2>/dev/null)
  go=$(active_pokemon_go); pm=$(active_pokemod); game=$(active_bluetooth_game)
  cat > "$LOCAL_STATUS_FILE" <<EOF
Bluetooth Stability Helper v$(module_version)
Profile: ${PROFILE_LABEL:-$(device_profile_id)}
Build ID: $(build_id)
Device: $brand $model SDK=$sdk
Bluetooth enabled setting: $(bt_enabled_setting)
BT process count: $(bt_process_count)
Strict process check: ${ENABLE_STRICT_BT_PROCESS_CHECK:-0}
Recovery evidence: ${FAILURE_THRESHOLD} faults within ${FAILURE_WINDOW_SECONDS}s
Adapter recovery: ${ENABLE_ADAPTER_TOGGLE_RECOVERY} (max ${MAX_RESTARTS_PER_HOUR}/hour, cooldown ${RECOVERY_COOLDOWN}s)
Pixel May 2026 CP1A guard: $(is_pixel_android16_may2026 && echo active || echo inactive)
Pixel Android 17 guard: $(is_pixel_android17 && echo active || echo inactive)
Active Pokémon GO: ${go:-none}
Active Pokemod/$VPGP3_DISPLAY_NAME: ${pm:-none}
Bluetooth health score: $(bluetooth_health_score 2>/dev/null)
Active Bluetooth-aware game/app: ${game:-none}
Last updated: $(date '+%F %T')
Logs: $LOG
EOF
}

main_loop() {
  while true; do
    rotate_log_if_needed; cleanup_restart_history; cap_runtime_files; ensure_files
    . "$MODDIR/common/config.sh"; . "$MODDIR/scripts/lib.sh"; apply_adaptive_defaults
    bad=0
    if [ "$WATCHDOG_ENABLED" = 1 ]; then
      proc_count=$(bt_process_count)
      [ "$ENABLE_BT_PROCESS_CHECK" = 1 ] && [ "${ENABLE_STRICT_BT_PROCESS_CHECK:-0}" = 1 ] && [ "$(bt_enabled_setting)" = 1 ] && [ "$proc_count" -eq 0 ] && { log "Bluetooth enabled but no known Bluetooth process found"; bad=1; }
      [ "$ENABLE_BT_MANAGER_CHECK" = 1 ] && health_bad_state && { log "bluetooth_manager did not report ON/true"; bad=1; }
      location_health_check
      periodic_health_export
      # Bond/CDM observers are diagnostic only. Android 17 performs autonomous
      # re-pairing, so these signals must not fight the platform recovery.
      android16_connectivity_change_patterns
      android17_connectivity_change_patterns
      interaction_freeze_patterns && bad=1
      scan_stall_patterns && bad=1
      track_vpgp3_session
      if pokemon_stack_health_bad; then [ "$POKEMOD_WARN_ONLY" = 1 ] && log "Pokemod/$VPGP3_DISPLAY_NAME signal warn-only; not triggering BT recovery" || bad=1; fi
      now=$(date +%s); last_signal=$(cat "$LAST_FAILURE_SIGNAL_FILE" 2>/dev/null)
      if [ "$bad" = 1 ]; then
        if [ -z "$last_signal" ] || [ $((now-last_signal)) -gt "${FAILURE_WINDOW_SECONDS:-180}" ]; then reset_fail_count; fi
        echo "$now" > "$LAST_FAILURE_SIGNAL_FILE"
        fails=$(increment_fail_count)
        log "Failure evidence: $fails/$FAILURE_THRESHOLD within ${FAILURE_WINDOW_SECONDS:-180}s"
        if [ "$fails" -ge "$FAILURE_THRESHOLD" ]; then
          restart_bt_stack
          reset_fail_count
          reset_interaction_freeze_count
          rm -f "$LAST_FAILURE_SIGNAL_FILE" 2>/dev/null
        fi
      elif [ -n "$last_signal" ] && [ $((now-last_signal)) -gt "${FAILURE_WINDOW_SECONDS:-180}" ]; then
        reset_fail_count
        reset_interaction_freeze_count
        rm -f "$LAST_FAILURE_SIGNAL_FILE" 2>/dev/null
      fi
    fi
    write_status
    sleep "$WATCHDOG_INTERVAL"
  done
}

wait_until_boot_complete
ensure_files
cleanup_boot_logs
log "Bluetooth Stability Helper $(module_version) adaptive engine start"
apply_adaptive_defaults
apply_static_tuning
[ "${RUN_DIAGNOSTICS_ON_BOOT:-0}" = "1" ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
main_loop

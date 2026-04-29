#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
LOG="$CONFIG_DIR/logs/bt-stability.log"
STATE_DIR="$CONFIG_DIR/state"
RESTARTS_FILE="$STATE_DIR/restarts.txt"
LAST_RECOVERY_FILE="$STATE_DIR/last_recovery.txt"
FAIL_COUNT_FILE="$STATE_DIR/fail_count.txt"
MODEFILE="$CONFIG_DIR/mode.txt"
USERCFG="$CONFIG_DIR/user-config.sh"
mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$CONFIG_DIR/logs" "$CONFIG_DIR/export" "$CONFIG_DIR/import"
. "$MODDIR/common/config.sh"
[ -f "$USERCFG" ] && . "$USERCFG"
. "$MODDIR/scripts/lib.sh"

rotate_log_if_needed() { [ -f "$LOG" ] || return; size_kb=$(du -k "$LOG" | awk '{print $1}'); [ "$size_kb" -gt "$LOG_ROTATE_SIZE_KB" ] && mv "$LOG" "$LOG.1" 2>/dev/null && touch "$LOG"; }
wait_until_boot_complete() { until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done; sleep 25; }
ensure_mode_file() { [ -f "$MODEFILE" ] || echo "$MODE_DEFAULT" > "$MODEFILE"; [ -f "$LOCAL_MODE_FILE" ] && cp "$LOCAL_MODE_FILE" "$MODEFILE" 2>/dev/null; [ -f "$LOCAL_USER_CONFIG" ] && cp "$LOCAL_USER_CONFIG" "$USERCFG" 2>/dev/null; }
current_mode() { cat "$MODEFILE" 2>/dev/null; }
apply_mode_defaults() { MODE=$(current_mode); case "$MODE" in
 safe) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=120; ENABLE_ADAPTER_TOGGLE_RECOVERY=0; ENABLE_BLUETOOTH_APP_FORCE_STOP=0; APPLY_APP_OPS_FIXES=0; ENABLE_DEVICE_IDLE_TUNING=0 ;;
 monitor) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=90; ENABLE_ADAPTER_TOGGLE_RECOVERY=0; ENABLE_BLUETOOTH_APP_FORCE_STOP=0; APPLY_APP_OPS_FIXES=0 ;;
 standard) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=60; FAILURE_THRESHOLD=2; ENABLE_ADAPTER_TOGGLE_RECOVERY=1; ENABLE_BLUETOOTH_APP_FORCE_STOP=0 ;;
 pixel) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=50; FAILURE_THRESHOLD=2; ENABLE_PIXEL_TUNING=1; ENABLE_A2DP_OFFLOAD_DISABLE=1; APPLY_APP_OPS_FIXES=1 ;;
 pokemon) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=45; FAILURE_THRESHOLD=2; WHITELIST_POKEMON_GO=1; WHITELIST_POKEMOD=1; APPLY_APP_OPS_FIXES=1; APPLY_RESTRICTED_STANDBY_FIXES=1; ENABLE_BLE_SCAN_ALWAYS=1; ENABLE_CONN_REPAIR_HINTS=1; ENABLE_STALE_SESSION_WATCHDOG=1 ;;
 pokemonplus) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=35; FAILURE_THRESHOLD=2; WHITELIST_POKEMON_GO=1; WHITELIST_POKEMOD=1; APPLY_APP_OPS_FIXES=1; APPLY_RESTRICTED_STANDBY_FIXES=1; ENABLE_BLE_SCAN_ALWAYS=1; ENABLE_LOCATION_BG_THROTTLE_OFF=1; ENABLE_STALE_SESSION_WATCHDOG=1; STALE_SESSION_MINUTES=48; ENABLE_GO_PLUS_STALL_PATTERNS=1; ENABLE_ACTIVITY_KEEPALIVE_HINTS=1 ;;
 aggressive) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=35; FAILURE_THRESHOLD=1; MAX_RESTARTS_PER_HOUR=4; ENABLE_BLUETOOTH_APP_FORCE_STOP=1; ENABLE_DEVICE_IDLE_TUNING=1 ;;
 diagnostics) WATCHDOG_ENABLED=1; WATCHDOG_INTERVAL=180; ENABLE_ADAPTER_TOGGLE_RECOVERY=0; ENABLE_BLUETOOTH_APP_FORCE_STOP=0 ;;
 *) echo pokemonplus > "$MODEFILE"; MODE=pokemonplus ;;
 esac; apply_device_profile; log "Mode applied: $MODE"; }
apply_static_tuning() {
 [ "$WHITELIST_BLUETOOTH" = 1 ] && whitelist_pkg com.android.bluetooth
 [ "$WHITELIST_GMS" = 1 ] && whitelist_pkg com.google.android.gms
 [ "$WHITELIST_POKEMON_GO" = 1 ] && whitelist_pkg "$POKEMON_GO_PACKAGE"
 if [ "$WHITELIST_POKEMOD" = 1 ]; then for pkg in $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do package_installed "$pkg" && whitelist_pkg "$pkg"; done; fi
 for pkg in $WHITELIST_EXTRA_PACKAGES; do whitelist_pkg "$pkg"; done
 if [ "$APPLY_APP_OPS_FIXES" = 1 ]; then
   for pkg in com.android.bluetooth com.google.android.gms "$POKEMON_GO_PACKAGE" $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do
     appops_allow_safe "$pkg" WAKE_LOCK; appops_allow_safe "$pkg" RUN_ANY_IN_BACKGROUND; appops_allow_safe "$pkg" START_FOREGROUND; appops_allow_safe "$pkg" BLUETOOTH_CONNECT; appops_allow_safe "$pkg" BLUETOOTH_SCAN; appops_allow_safe "$pkg" FINE_LOCATION; appops_allow_safe "$pkg" ACCESS_FINE_LOCATION; appops_allow_safe "$pkg" COARSE_LOCATION; appops_allow_safe "$pkg" POST_NOTIFICATION; appops_allow_safe "$pkg" SCHEDULE_EXACT_ALARM
   done
 fi
 [ "$ENABLE_BLE_SCAN_ALWAYS" = 1 ] && settings put global ble_scan_always_enabled 1 >/dev/null 2>&1
 [ "$ENABLE_WIFI_SCAN_THROTTLE_OFF" = 1 ] && settings put global wifi_scan_throttle_enabled 0 >/dev/null 2>&1
 [ "$ENABLE_LOCATION_BG_THROTTLE_OFF" = 1 ] && settings put global location_background_throttle_interval_ms 0 >/dev/null 2>&1
 [ "$ENABLE_DEVICE_IDLE_TUNING" = 1 ] && settings put global device_idle_constants "$DEVICE_IDLE_CONSTANTS" >/dev/null 2>&1
 [ "$ENABLE_A2DP_OFFLOAD_DISABLE" = 1 ] && { resetprop -n persist.bluetooth.a2dp_offload.disabled true 2>/dev/null; resetprop -n persist.vendor.bluetooth.a2dp_offload.disabled true 2>/dev/null; }
 [ "$APPLY_RESTRICTED_STANDBY_FIXES" = 1 ] && for pkg in com.android.bluetooth com.google.android.gms "$POKEMON_GO_PACKAGE" $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do package_installed "$pkg" && { cmd appops set "$pkg" RUN_IN_BACKGROUND allow >/dev/null 2>&1; cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1; }; done
 check_android_support
}
bt_enabled_setting() { settings get global bluetooth_on 2>/dev/null; }
bt_process_count() { count=0; for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service android.hardware.bluetooth.audio-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do pidof "$name" >/dev/null 2>&1 && count=$((count+1)); done; echo "$count"; }
health_bad_state() { summary="$(dumpsys bluetooth_manager 2>/dev/null | tr '[:upper:]' '[:lower:]')"; echo "$summary" | grep -q "state:.*on" && return 1; echo "$summary" | grep -q "enabled: true" && return 1; return 0; }
location_health_check() { [ "$CHECK_LOCATION_MODE" = 1 ] || return 1; mode=$(settings get secure location_mode 2>/dev/null); [ "$mode" = 3 ] || [ "$mode" = 1 ] || { log "Location warning: location_mode=$mode; Pokemon GO/Pokemod may have unstable BLE/location sessions"; return 0; }; [ "$CHECK_BLE_SCAN_SETTINGS" = 1 ] && [ "$(settings get global ble_scan_always_enabled 2>/dev/null)" != 1 ] && log "BLE scan warning: ble_scan_always_enabled is not 1"; return 1; }
pokemon_stack_health_bad() { [ "$POKEMOD_CHECK_ENABLED" = 1 ] || return 1; go=0; package_running "$POKEMON_GO_PACKAGE" && go=1; prun=$(first_running_from_list "$POKEMOD_PACKAGE_CANDIDATES"); vrun=$(first_running_from_list "$VPGP3_PACKAGE_CANDIDATES"); pinst=$(first_installed_from_list "$POKEMOD_PACKAGE_CANDIDATES"); vinst=$(first_installed_from_list "$VPGP3_PACKAGE_CANDIDATES"); [ -n "$prun" ] && log "Pokemod running: $prun"; [ -n "$vrun" ] && log "vPGP3 candidate running: $vrun"; if [ "$go" = 1 ] && [ "$POKEMOD_REQUIRED_FOR_GO" = 1 ] && [ -n "$pinst$vinst" ] && [ -z "$prun$vrun" ]; then log "Pokemon GO running but installed Pokemod/vPGP3 package is not detected running"; return 0; fi; return 1; }
ensure_session_files() { mkdir -p "$STATE_DIR" "$EXPORT_DIR" "$LOG_DIR"; }
current_session_key() { go=0; package_running "$POKEMON_GO_PACKAGE" && go=1; prun=$(first_running_from_list "$POKEMOD_PACKAGE_CANDIDATES"); vrun=$(first_running_from_list "$VPGP3_PACKAGE_CANDIDATES"); echo "go=$go pokemod=${prun:-none} vpgp=${vrun:-none}"; }
track_pokemonplus_session() {
 [ "$ENABLE_STALE_SESSION_WATCHDOG" = 1 ] || return 1
 ensure_session_files
 key=$(current_session_key)
 echo "$key" | grep -q 'go=1' || { rm -f "$STATE_DIR/pokemonplus_session_start" "$STATE_DIR/pokemonplus_session_key" 2>/dev/null; return 1; }
 echo "$key" | grep -q 'pokemod=none vpgp=none' && return 1
 now=$(date +%s)
 oldkey=$(cat "$STATE_DIR/pokemonplus_session_key" 2>/dev/null)
 if [ "$oldkey" != "$key" ] || [ ! -f "$STATE_DIR/pokemonplus_session_start" ]; then echo "$key" > "$STATE_DIR/pokemonplus_session_key"; echo "$now" > "$STATE_DIR/pokemonplus_session_start"; log "Pokemon Plus session observed: $key"; return 1; fi
 start=$(cat "$STATE_DIR/pokemonplus_session_start" 2>/dev/null)
 [ -z "$start" ] && echo "$now" > "$STATE_DIR/pokemonplus_session_start" && return 1
 age_min=$(( (now-start) / 60 ))
 if [ "$age_min" -ge "$STALE_SESSION_MINUTES" ]; then
   last=$(cat "$STATE_DIR/pokemonplus_last_stale" 2>/dev/null)
   [ -n "$last" ] && [ $((now-last)) -lt 900 ] && return 1
   echo "$now" > "$STATE_DIR/pokemonplus_last_stale"
   log "Possible stale Virtual GO Plus session: age=${age_min}m key=$key"
   [ "$POKEMONPLUS_AUTO_EXPORT_ON_STALL" = 1 ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
   case "$STALE_SESSION_ACTION" in log|diagnose) return 1 ;; bt_refresh) [ "$STALE_SESSION_BT_REFRESH" = 1 ] && return 0 || return 1 ;; app_refresh) [ "$STALE_SESSION_APP_REFRESH" = 1 ] && return 0 || return 1 ;; *) return 1 ;; esac
 fi
 return 1
}
scan_go_plus_stall_patterns() {
 [ "$ENABLE_GO_PLUS_STALL_PATTERNS" = 1 ] || return 1
 logcat -d -t 220 2>/dev/null | grep -iE 'gatt.*(133|257|timeout|disconnect|dead|busy)|go plus.*(disconnect|timeout|stale)|ble.*(scan.*failed|stopped)|location.*(stale|throttle)|fused.*stale|bt_stack.*(hci|timeout)' >/dev/null 2>&1 || return 1
 log "Recent logcat contains BLE/GATT/location stall pattern; exported diagnostics"
 [ "$POKEMONPLUS_AUTO_EXPORT_ON_STALL" = 1 ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
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
restart_bt_stack() { recent=$(count_recent_restarts); [ "$recent" -ge "$MAX_RESTARTS_PER_HOUR" ] && { log "Recovery skipped: max restarts reached $recent/$MAX_RESTARTS_PER_HOUR"; return; }; recovery_cooldown_ok || { log "Recovery skipped: cooldown active"; return; }; fails=$(get_fail_count); repair_audio_route; if [ "$ENABLE_BLUETOOTH_APP_FORCE_STOP" = 1 ] && [ "$fails" -ge 2 ]; then am force-stop com.android.bluetooth >/dev/null 2>&1; sleep 2; log "Bluetooth app force-stop attempted"; fi; if [ "$ENABLE_ADAPTER_TOGGLE_RECOVERY" = 1 ]; then log "Bluetooth adapter toggle recovery"; svc bluetooth disable >/dev/null 2>&1; sleep 4; svc bluetooth enable >/dev/null 2>&1; sleep 7; record_restart; fi; }
main_loop() { while true; do rotate_log_if_needed; cleanup_restart_history; ensure_mode_file; . "$MODDIR/common/config.sh"; [ -f "$USERCFG" ] && . "$USERCFG"; . "$MODDIR/scripts/lib.sh"; apply_mode_defaults; bad=0; if [ "$WATCHDOG_ENABLED" = 1 ]; then proc_count=$(bt_process_count); [ "$ENABLE_BT_PROCESS_CHECK" = 1 ] && [ "$(bt_enabled_setting)" = 1 ] && [ "$proc_count" -eq 0 ] && { log "Bluetooth enabled but no known Bluetooth process found"; bad=1; }; [ "$ENABLE_BT_MANAGER_CHECK" = 1 ] && health_bad_state && { log "bluetooth_manager did not report ON/true"; bad=1; }; location_health_check; scan_go_plus_stall_patterns; if track_pokemonplus_session; then [ "$POKEMONPLUS_WARN_ONLY" = 1 ] && log "Virtual GO Plus stale-session signal warn-only; not triggering BT recovery" || bad=1; fi; if pokemon_stack_health_bad; then [ "$POKEMOD_WARN_ONLY" = 1 ] && log "Pokemod/vPGP3 signal warn-only; not triggering BT recovery" || bad=1; fi; if [ "$bad" = 1 ]; then fails=$(increment_fail_count); log "Failure count: $fails/$FAILURE_THRESHOLD"; [ "$fails" -ge "$FAILURE_THRESHOLD" ] && restart_bt_stack && reset_fail_count; else reset_fail_count; fi; fi; [ "$(current_mode)" = diagnostics ] && MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1; sleep "$WATCHDOG_INTERVAL"; done; }
wait_until_boot_complete
log "Bluetooth Stability Helper PRO 0.8.1 start"
ensure_mode_file
apply_mode_defaults
apply_static_tuning
MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
main_loop

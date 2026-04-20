#!/system/bin/sh
MODDIR=${0%/*}
LOG="$MODDIR/bt-stability.log"
STATE_DIR="$MODDIR/state"
RESTARTS_FILE="$STATE_DIR/restarts.txt"
LAST_RECOVERY_FILE="$STATE_DIR/last_recovery.txt"
FAIL_COUNT_FILE="$STATE_DIR/fail_count.txt"
MODEFILE="$MODDIR/user-mode.txt"
USERCFG="$MODDIR/user-config.sh"

mkdir -p "$STATE_DIR"

. "$MODDIR/common/config.sh"
[ -f "$USERCFG" ] && . "$USERCFG"
. "$MODDIR/common/profiles/generic.sh"
. "$MODDIR/common/profiles/pixel.sh"
. "$MODDIR/common/profiles/samsung.sh"
. "$MODDIR/common/profiles/xiaomi.sh"

log() {
  echo "$(date '+%F %T')  $1" >> "$LOG"
}

rotate_log_if_needed() {
  if [ -f "$LOG" ]; then
    size_kb=$(du -k "$LOG" | awk '{print $1}')
    if [ "$size_kb" -gt "$LOG_ROTATE_SIZE_KB" ]; then
      mv "$LOG" "$LOG.1" 2>/dev/null
      touch "$LOG"
      log "Rotated log"
    fi
  fi
}

wait_until_boot_complete() {
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
  done
  sleep 15
}

ensure_mode_file() {
  [ -f "$MODEFILE" ] || echo "$MODE_DEFAULT" > "$MODEFILE"
}

current_mode() {
  cat "$MODEFILE" 2>/dev/null
}

apply_mode_defaults() {
  MODE=$(current_mode)
  case "$MODE" in
    safe)
      WATCHDOG_ENABLED=0
      RESTART_BT_ON_MISSING=0
      RESTART_BT_ON_BAD_STATE=0
      WATCHDOG_INTERVAL=120
      ENABLE_DEVICE_IDLE_TUNING=0
      ;;
    monitor)
      WATCHDOG_ENABLED=1
      RESTART_BT_ON_MISSING=0
      RESTART_BT_ON_BAD_STATE=0
      WATCHDOG_INTERVAL=120
      ENABLE_DEVICE_IDLE_TUNING=0
      ;;
    recover)
      WATCHDOG_ENABLED=1
      RESTART_BT_ON_MISSING=1
      RESTART_BT_ON_BAD_STATE=1
      WATCHDOG_INTERVAL=90
      ENABLE_DEVICE_IDLE_TUNING=0
      ;;
    pixel_aggressive)
      WATCHDOG_ENABLED=1
      RESTART_BT_ON_MISSING=1
      RESTART_BT_ON_BAD_STATE=1
      WATCHDOG_INTERVAL=60
      ENABLE_DEVICE_IDLE_TUNING=1
      MAX_RESTARTS_PER_HOUR=3
      FAILURE_THRESHOLD=2
      ;;
    *)
      log "Unknown mode '$MODE', forcing safe"
      echo safe > "$MODEFILE"
      WATCHDOG_ENABLED=0
      RESTART_BT_ON_MISSING=0
      RESTART_BT_ON_BAD_STATE=0
      WATCHDOG_INTERVAL=120
      ENABLE_DEVICE_IDLE_TUNING=0
      ;;
  esac
  log "Mode defaults applied: $(current_mode)"
}

detect_profile() {
  BRAND=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')
  MANUFACTURER=$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
  DEVICE=$(getprop ro.product.device)
  case "$BRAND:$MANUFACTURER" in
    google:*|*:google) PROFILE="pixel" ;;
    samsung:*|*:samsung) PROFILE="samsung" ;;
    xiaomi:*|*:xiaomi|redmi:*|*:redmi|poco:*|*:poco) PROFILE="xiaomi" ;;
    *) PROFILE="generic" ;;
  esac
  log "Detected brand=$BRAND manufacturer=$MANUFACTURER device=$DEVICE profile=$PROFILE"
}

apply_profile() {
  case "$PROFILE" in
    pixel) apply_profile_pixel ;;
    samsung) apply_profile_samsung ;;
    xiaomi) apply_profile_xiaomi ;;
    *) apply_profile_generic ;;
  esac
}

whitelist_pkg() {
  pkg="$1"
  [ -n "$pkg" ] || return 0
  cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1
  log "Whitelisted from device idle: $pkg"
}

apply_whitelists() {
  [ "$WHITELIST_BLUETOOTH" = "1" ] && whitelist_pkg "com.android.bluetooth"
  [ "$WHITELIST_GMS" = "1" ] && whitelist_pkg "com.google.android.gms"
  for pkg in $WHITELIST_EXTRA_PACKAGES; do
    whitelist_pkg "$pkg"
  done
}

bt_enabled_setting() {
  settings get global bluetooth_on 2>/dev/null
}

bt_process_count() {
  count=0
  for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do
    pidof "$name" >/dev/null 2>&1 && count=$((count+1))
  done
  echo "$count"
}

bt_manager_summary() {
  dumpsys bluetooth_manager 2>/dev/null | grep -E "enabled:|state:|name:|address:" | head -n 8
}

health_bad_state() {
  # Heuristic only. Return 0 when state looks bad.
  summary="$(dumpsys bluetooth_manager 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  echo "$summary" | grep -q "state:.*on" && return 1
  echo "$summary" | grep -q "enabled: true" && return 1
  return 0
}

count_recent_restarts() {
  now=$(date +%s)
  cutoff=$((now - 3600))
  [ -f "$RESTARTS_FILE" ] || { echo 0; return; }
  awk -v cutoff="$cutoff" '$1 >= cutoff {count++} END {print count+0}' "$RESTARTS_FILE"
}

record_restart() {
  date +%s >> "$RESTARTS_FILE"
  date +%s > "$LAST_RECOVERY_FILE"
}

recovery_cooldown_ok() {
  [ -f "$LAST_RECOVERY_FILE" ] || return 0
  last=$(cat "$LAST_RECOVERY_FILE" 2>/dev/null)
  [ -n "$last" ] || return 0
  now=$(date +%s)
  delta=$((now - last))
  [ "$delta" -ge "$RECOVERY_COOLDOWN" ]
}

cleanup_restart_history() {
  now=$(date +%s)
  cutoff=$((now - 7200))
  if [ -f "$RESTARTS_FILE" ]; then
    awk -v cutoff="$cutoff" '$1 >= cutoff' "$RESTARTS_FILE" > "$RESTARTS_FILE.tmp" && mv "$RESTARTS_FILE.tmp" "$RESTARTS_FILE"
  fi
}

get_fail_count() {
  [ -f "$FAIL_COUNT_FILE" ] && cat "$FAIL_COUNT_FILE" || echo 0
}

set_fail_count() {
  echo "$1" > "$FAIL_COUNT_FILE"
}

increment_fail_count() {
  count=$(get_fail_count)
  count=$((count + 1))
  set_fail_count "$count"
  echo "$count"
}

reset_fail_count() {
  set_fail_count 0
}

restart_bt_stack() {
  recent=$(count_recent_restarts)
  if [ "$recent" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
    log "Restart skipped: max restarts per hour reached ($recent/$MAX_RESTARTS_PER_HOUR)"
    return
  fi
  if ! recovery_cooldown_ok; then
    log "Restart skipped: cooldown active"
    return
  fi
  log "Attempting Bluetooth stack restart"
  svc bluetooth disable >/dev/null 2>&1
  sleep 3
  svc bluetooth enable >/dev/null 2>&1
  sleep 5
  record_restart
  log "Bluetooth stack restart complete"
}

main_loop() {
  while true; do
    rotate_log_if_needed
    cleanup_restart_history

    if [ "$WATCHDOG_ENABLED" = "1" ]; then
      bad=0
      proc_count=$(bt_process_count)

      if [ "$RESTART_BT_ON_MISSING" = "1" ] && [ "$(bt_enabled_setting)" = "1" ] && [ "$proc_count" -eq 0 ]; then
        log "Health warning: bluetooth enabled but no known Bluetooth process detected"
        bad=1
      fi

      if [ "$RESTART_BT_ON_BAD_STATE" = "1" ]; then
        if health_bad_state; then
          log "Health warning: bluetooth_manager summary did not clearly report ON"
          bad=1
        fi
      fi

      if [ "$bad" -eq 1 ]; then
        fails=$(increment_fail_count)
        log "Consecutive failure count: $fails/$FAILURE_THRESHOLD"
        if [ "$fails" -ge "$FAILURE_THRESHOLD" ]; then
          restart_bt_stack
          reset_fail_count
        fi
      else
        reset_fail_count
      fi
    fi

    sleep "$WATCHDOG_INTERVAL"
  done
}

wait_until_boot_complete
log "Service start"
ensure_mode_file
apply_mode_defaults
detect_profile
apply_profile
apply_whitelists
main_loop

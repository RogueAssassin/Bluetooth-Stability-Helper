#!/system/bin/sh
MODDIR=${0%/*}
if ! command -v ui_print >/dev/null 2>&1; then ui_print() { echo "$1"; }; fi

. "$MODDIR/common/config.sh"
USERCFG="$LOCAL_USER_CONFIG"
mkdir -p "$EXPORT_DIR" "$IMPORT_DIR" "$LOG_DIR" "$STATE_DIR"
. "$MODDIR/scripts/lib.sh"

[ -f "$USERCFG" ] || cat > "$USERCFG" <<'EOF'
# Bluetooth Stability Helper local overrides.
# Defaults are automatic and recommended.
# WATCHDOG_INTERVAL=45
# STALE_SESSION_MINUTES=20
# ENABLE_A2DP_OFFLOAD_DISABLE=0
EOF

import_bundle_if_present() {
  [ -f "$IMPORT_DIR/user-config.sh" ] || return 1
  cp "$IMPORT_DIR/user-config.sh" "$USERCFG" || return 1
  chmod 0644 "$USERCFG"
}

if import_bundle_if_present; then ui_print "Imported user configuration from $IMPORT_DIR"; fi
apply_device_profile
load_user_config "$USERCFG"

ui_print "Bluetooth Stability Helper v$(module_version)"
ui_print "Profile: ${PROFILE_LABEL:-$(device_profile_id)}"
ui_print "Device: $(getprop ro.product.brand 2>/dev/null) $(getprop ro.product.model 2>/dev/null)"
ui_print "Android: $(getprop ro.build.version.release 2>/dev/null) / SDK $(sdk_int)"
ui_print "Recovery: ${FAILURE_THRESHOLD} faults/${FAILURE_WINDOW_SECONDS}s, cooldown ${RECOVERY_COOLDOWN}s"
ui_print "Bluetooth: enabled=$(bt_enabled_setting), processes=$(bt_process_count)"

pid=$(cat /data/adb/bsh-service.lock/pid 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then ui_print "Watchdog: running (PID $pid)"
else ui_print "Watchdog: not detected; run verify.sh or reboot"
fi

ui_print ""
ui_print "Collecting current diagnostics..."
MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
ui_print "Diagnostics: $EXPORT_DIR"
ui_print "Status: $LOCAL_STATUS_FILE"
ui_print "Install report: $CONFIG_DIR/install-report.txt"
ui_print "Log: $LOG_DIR/bt-stability.log"

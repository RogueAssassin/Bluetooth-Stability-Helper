#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
LOG="$CONFIG_DIR/logs/bt-stability.log"
STATE_DIR="$CONFIG_DIR/state"
USERCFG="$CONFIG_DIR/user-config.sh"
fail=0
warn=0

. "$MODDIR/common/config.sh"
. "$MODDIR/scripts/lib.sh"
apply_device_profile
load_user_config "$USERCFG"

pass() { echo "PASS: $1"; }
warning() { echo "WARN: $1"; warn=$((warn+1)); }
failure() { echo "FAIL: $1"; fail=$((fail+1)); }

echo "Bluetooth Stability Helper v$(module_version) verification"
echo "Profile: ${PROFILE_LABEL:-$(device_profile_id)}"
echo "Android: $(getprop ro.build.version.release 2>/dev/null) / SDK $(sdk_int)"
echo "Build: $(build_id)"
echo

for file in module.prop service.sh post-fs-data.sh action.sh uninstall.sh common/config.sh scripts/lib.sh scripts/diagnostics.sh scripts/install_utils.sh; do
  [ -f "$MODDIR/$file" ] && pass "$file present" || failure "$file missing"
done

for file in "$MODDIR"/*.sh "$MODDIR"/scripts/*.sh "$MODDIR"/common/*.sh "$MODDIR"/common/profiles/*.sh; do
  sh -n "$file" >/dev/null 2>&1 || failure "shell syntax: ${file#$MODDIR/}"
done
[ "$fail" -gt 0 ] || pass "all shell scripts parse"

mkdir -p "$STATE_DIR" "$CONFIG_DIR/logs" "$CONFIG_DIR/metrics" 2>/dev/null
[ -d "$STATE_DIR" ] && [ -w "$STATE_DIR" ] && pass "runtime storage writable" || failure "runtime storage unavailable"

case "$(sdk_int)" in 31|32|33|34|35|36|37) pass "Android SDK in validated range" ;; *) warning "Android SDK outside validated range 31-37" ;; esac

pid=$(cat /data/adb/bsh-service.lock/pid 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then pass "watchdog service running (PID $pid)"
elif [ "$(getprop sys.boot_completed 2>/dev/null)" = 1 ]; then warning "watchdog service is not currently running"
else warning "Android has not completed boot; service status unavailable"
fi

if [ "$(bt_enabled_setting)" = 1 ]; then
  pass "Bluetooth setting enabled"
  [ "$(bt_process_count)" -gt 0 ] && pass "Bluetooth process detected" || warning "no known Bluetooth process detected"
else
  warning "Bluetooth is currently off"
fi

echo
echo "Recovery policy: ${FAILURE_THRESHOLD} faults/${FAILURE_WINDOW_SECONDS}s, max ${MAX_RESTARTS_PER_HOUR}/hour, cooldown ${RECOVERY_COOLDOWN}s"
echo "Adapter recovery: $ENABLE_ADAPTER_TOGGLE_RECOVERY"
echo "Status: $CONFIG_DIR/status.txt"
echo "Install report: $CONFIG_DIR/install-report.txt"

if [ "$fail" -gt 0 ]; then
  echo "RESULT: FAIL ($fail failures, $warn warnings)"
  exit 1
fi
echo "RESULT: PASS ($warn warnings)"
exit 0

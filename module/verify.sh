#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
fail=0
check_file() { [ -f "$1" ] || { echo "MISSING: $1"; fail=1; }; }
check_file "$MODDIR/module.prop"
check_file "$MODDIR/service.sh"
check_file "$MODDIR/common/config.sh"
check_file "$MODDIR/scripts/lib.sh"
check_file "$MODDIR/scripts/install_utils.sh"
mkdir -p "$CONFIG_DIR/state" "$CONFIG_DIR/logs" "$CONFIG_DIR/metrics" 2>/dev/null || fail=1
case "$(getprop ro.build.version.sdk 2>/dev/null)" in
  31|32|33|34|35|36|37) : ;;
  *) echo "WARN: Android SDK outside tested range 31-37" ;;
esac
if [ "$fail" = 0 ]; then
  echo "Bluetooth Stability Helper verification: PASS"
  exit 0
fi
echo "Bluetooth Stability Helper verification: FAIL"
exit 1

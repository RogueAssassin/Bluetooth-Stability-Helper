#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MODDIR="$ROOT/module"

for file in "$MODDIR"/*.sh "$MODDIR"/scripts/*.sh "$MODDIR"/common/*.sh "$MODDIR"/common/profiles/*.sh; do
  sh -n "$file"
done

version=$(sed -n 's/^version=//p' "$MODDIR/module.prop" | head -n1)
version_code=$(sed -n 's/^versionCode=//p' "$MODDIR/module.prop" | head -n1)
python3 - "$ROOT/update.json" "$version" "$version_code" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["version"] == sys.argv[2]
assert int(manifest["versionCode"]) == int(sys.argv[3])
assert f"/v{sys.argv[2]}/bt-stability-helper-v{sys.argv[2]}.zip" in manifest["zipUrl"]
PY

grep -q '^PIXEL_ANDROID17_FAILURE_THRESHOLD=2$' "$MODDIR/common/config.sh"
grep -q '^FAILURE_WINDOW_SECONDS=180$' "$MODDIR/common/config.sh"
grep -q '^STALE_SESSION_ACTION="diagnose"' "$MODDIR/common/config.sh"
grep -q '^STALE_SESSION_BT_REFRESH=0$' "$MODDIR/common/config.sh"
grep -q '^ENABLE_A2DP_OFFLOAD_DISABLE=0$' "$MODDIR/common/config.sh"
grep -q '^APPLY_APP_OPS_FIXES=0$' "$MODDIR/common/config.sh"
! grep -q '\[ -f "$USERCFG" \] && \. "$USERCFG"' "$MODDIR/service.sh"
! grep -q '\[ -f "$LOCAL_USER_CONFIG" \] && \. "$LOCAL_USER_CONFIG"' "$MODDIR/scripts/diagnostics.sh"
grep -q '^SKIPUNZIP=0$' "$MODDIR/customize.sh"
grep -q '^bsh_print_environment$' "$MODDIR/customize.sh"
grep -q '^bsh_verify_payload$' "$MODDIR/customize.sh"
! grep -q '^on_install()' "$MODDIR/customize.sh"
! grep -q '^print_modname()' "$MODDIR/customize.sh"
for profile in generic pixel samsung xiaomi oplus nothing motorola asus sony vivo huawei; do
  [ -f "$MODDIR/common/profiles/$profile.sh" ]
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"
mkdir -p "$STATE_DIR" "$CONFIG_DIR"
. "$MODDIR/common/config.sh"
STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"
. "$MODDIR/scripts/lib.sh"
reset_test_paths() { STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"; }

MOCK_BRAND=google; MOCK_MAKER=Google; MOCK_MODEL='Pixel 8'; MOCK_SDK=37; MOCK_BUILD=CP2A.260705.006
getprop() {
  case "$1" in
    ro.product.brand) echo "$MOCK_BRAND" ;;
    ro.product.manufacturer) echo "$MOCK_MAKER" ;;
    ro.product.model) echo "$MOCK_MODEL" ;;
    ro.build.version.sdk) echo "$MOCK_SDK" ;;
    ro.build.id) echo "$MOCK_BUILD" ;;
    ro.build.fingerprint) echo "$MOCK_BRAND/$MOCK_MODEL/$MOCK_BUILD" ;;
    *) echo "" ;;
  esac
}

[ "$(device_profile_id)" = pixel ]
apply_device_profile
[ "$PROFILE_ID" = pixel ]
[ "$FAILURE_THRESHOLD" = 2 ]
[ "$ENABLE_STRICT_BT_PROCESS_CHECK" = 1 ]

. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_BRAND=samsung; MOCK_MAKER=samsung; MOCK_MODEL='SM-S928B'; MOCK_SDK=37
apply_device_profile
[ "$PROFILE_ID" = samsung ]
[ "$FAILURE_THRESHOLD" = 3 ]
[ "$ENABLE_STRICT_BT_PROCESS_CHECK" = 0 ]

. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_BRAND=HUAWEI; MOCK_MAKER=HUAWEI; MOCK_MODEL='HUAWEI'; MOCK_SDK=37
apply_device_profile
[ "$PROFILE_ID" = huawei ]
[ "$ENABLE_ADAPTER_TOGGLE_RECOVERY" = 0 ]

. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_BRAND=unknown; MOCK_MAKER=unknown; MOCK_MODEL=unknown; MOCK_SDK=38
apply_device_profile
[ "$PROFILE_ID" = unsupported ]
[ "$ENABLE_ADAPTER_TOGGLE_RECOVERY" = 0 ]

. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_BRAND=google; MOCK_MAKER=Google; MOCK_MODEL='Pixel 8'; MOCK_SDK=37
apply_device_profile

active_bluetooth_game() { echo com.nianticlabs.pokemongo; return 0; }
TEST_LOG_LINE=""
logcat() { printf '%s\n' "$TEST_LOG_LINE"; }
now=$(date +%s)
TEST_LOG_LINE="$now.000 100 100 E BluetoothGatt: status=133 timeout"
fresh_log_fault test-observer 'gatt.*(133|timeout)'
if fresh_log_fault test-observer 'gatt.*(133|timeout)'; then
  echo "duplicate log event was incorrectly accepted" >&2
  exit 1
fi
TEST_LOG_LINE="$now.100 100 100 E BluetoothGatt: status=257 timeout"
fresh_log_fault test-observer 'gatt.*(257|timeout)'

cfg="$tmp/user-config.sh"
printf '%s\n' 'WATCHDOG_INTERVAL=40' 'STALE_SESSION_ACTION=diagnose' 'WATCHDOG_INTERVAL=$(touch /data/local/tmp/bsh-injection)' 'UNKNOWN_SETTING=1' > "$cfg"
load_user_config "$cfg"
[ "$WATCHDOG_INTERVAL" = 40 ]
[ "$STALE_SESSION_ACTION" = diagnose ]
! grep -q '\$(' "$STATE_DIR/user-config.safe"

# Exercise the modern top-level installer with a temporary Pixel payload.
install_root="$tmp/install-module"
cp -R "$MODDIR" "$install_root"
(
  MODPATH="$install_root"; ZIPFILE="$ROOT/test-module.zip"; BOOTMODE=true
  MOCK_BRAND=google; MOCK_MAKER=Google; MOCK_MODEL='Pixel 8'; MOCK_SDK=37; MOCK_BUILD=CP2A.260705.006
  getprop() {
    case "$1" in
      ro.product.brand) echo "$MOCK_BRAND" ;;
      ro.product.manufacturer) echo "$MOCK_MAKER" ;;
      ro.product.model) echo "$MOCK_MODEL" ;;
      ro.build.version.sdk) echo "$MOCK_SDK" ;;
      ro.build.version.release) echo 17 ;;
      ro.build.id) echo "$MOCK_BUILD" ;;
      ro.build.version.security_patch) echo 2026-07-05 ;;
      ro.product.cpu.abi) echo arm64-v8a ;;
      ro.soc.manufacturer) echo Google ;;
      ro.soc.model) echo Tensor ;;
      *) echo "" ;;
    esac
  }
  ui_print() { :; }
  abort() { echo "$1" >&2; exit 1; }
  set_perm() { :; }
  set_perm_recursive() { :; }
  . "$MODPATH/customize.sh"
)
grep -q '^Profile: Google Pixel (primary)$' "$install_root/state/install-report.txt"
grep -q '^PROFILE_ID=pixel$' "$install_root/state/install-profile.txt"

echo "Bluetooth Stability Helper tests: PASS"

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

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"
mkdir -p "$STATE_DIR" "$CONFIG_DIR"
. "$MODDIR/common/config.sh"
STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"
. "$MODDIR/scripts/lib.sh"

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

echo "Bluetooth Stability Helper tests: PASS"

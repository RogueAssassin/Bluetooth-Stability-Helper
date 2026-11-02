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
grep -q '^METRICS_HISTORY_MAX_LINES=500$' "$MODDIR/common/config.sh"
grep -q '^EVENT_HISTORY_MAX_LINES=500$' "$MODDIR/common/config.sh"
grep -Fq 'echo "$$" > "$STATE_DIR/service.pid"' "$MODDIR/service.sh"
grep -Fq 'verify_recovery_outcome()' "$MODDIR/service.sh"
[ -f "$MODDIR/scripts/telemetry.sh" ]
[ -f "$MODDIR/scripts/manager_api.sh" ]
grep -q '^MANAGER_API_ENABLED=1$' "$MODDIR/common/config.sh"
grep -q '^MANAGER_API_REFRESH_SECONDS=30$' "$MODDIR/common/config.sh"
grep -q '^SERVICE_SELF_HEAL_ENABLED=1$' "$MODDIR/common/config.sh"
grep -q '^SERVICE_SELF_HEAL_INTERVAL_SECONDS=120$' "$MODDIR/common/config.sh"
grep -Fq 'service_self_check()' "$MODDIR/service.sh"
grep -Fq 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' "$MODDIR/scripts/install_utils.sh"
grep -Fq 'bsh_check_manager_features' "$MODDIR/scripts/install_utils.sh"
grep -q 'CP3A' "$MODDIR/common/config.sh"
grep -q 'CD1A' "$MODDIR/common/config.sh"
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
. "$MODDIR/scripts/telemetry.sh"
telemetry_init
. "$MODDIR/scripts/manager_api.sh"
reset_test_paths() { STATE_DIR="$tmp/state"; CONFIG_DIR="$tmp/config"; LOG="$tmp/test.log"; }

MOCK_BRAND=google; MOCK_MAKER=Google; MOCK_MODEL='Pixel 8'; MOCK_SDK=37; MOCK_BUILD=CP2A.260705.006; MOCK_CODENAME=REL
getprop() {
  case "$1" in
    ro.product.brand) echo "$MOCK_BRAND" ;;
    ro.product.manufacturer) echo "$MOCK_MAKER" ;;
    ro.product.model) echo "$MOCK_MODEL" ;;
    ro.product.device) echo pixel8 ;;
    ro.build.version.sdk) echo "$MOCK_SDK" ;;
    ro.build.id) echo "$MOCK_BUILD" ;;
    ro.build.fingerprint) echo "$MOCK_BRAND/$MOCK_MODEL/$MOCK_BUILD" ;;
    ro.build.version.release) echo 17 ;;
    ro.build.version.codename) echo "$MOCK_CODENAME" ;;
    ro.build.version.security_patch) echo 2026-07-05 ;;
    sys.boot_completed) echo 1 ;;
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

# Current Pixel Android 17 firmware families are recognised.
. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_BRAND=google; MOCK_MAKER=Google; MOCK_MODEL='Pixel 9'; MOCK_SDK=37; MOCK_BUILD=CP3A.261005.005; MOCK_CODENAME=REL
apply_device_profile
[ "$PROFILE_ID" = pixel ]
is_known_pixel_android17_build_family
is_pixel_android17_october2026
if is_android_preview_build; then echo "stable Pixel build reported as preview" >&2; exit 1; fi

MOCK_MODEL='Pixel 11 Pro'; MOCK_BUILD=CD1A.261005.003
[ "$(device_profile_id)" = pixel ]
is_known_pixel_android17_build_family
is_pixel_android17_october2026

# Beta firmware is reported but keeps the Pixel recovery policy.
. "$MODDIR/common/config.sh"
reset_test_paths
MOCK_MODEL='Pixel 10'; MOCK_BUILD=DP11.260918.006
apply_device_profile
[ "$PROFILE_ID" = pixel ]
[ "$FAILURE_THRESHOLD" = 2 ]
is_android_preview_build
MOCK_BUILD=CP3A.261005.005; MOCK_CODENAME=CinnamonBun
is_android_preview_build
MOCK_MODEL='Pixel 8'; MOCK_BUILD=CP2A.260705.006; MOCK_CODENAME=REL

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

# Out-of-range values are ignored.
printf '%s\n' 'WATCHDOG_INTERVAL=0' 'MAX_RESTARTS_PER_HOUR=99' > "$cfg"
WATCHDOG_INTERVAL=25
MAX_RESTARTS_PER_HOUR=2
load_user_config "$cfg"
[ "$WATCHDOG_INTERVAL" = 25 ]
[ "$MAX_RESTARTS_PER_HOUR" = 2 ]

# Structured telemetry is writable and state transitions are explicit.
record_event "test" "info" "tests" "hello" "" ""
grep -q '"type":"test"' "$EVENT_HISTORY_FILE"
set_recovery_state "SUSPECT"
[ "$(recovery_state)" = SUSPECT ]

# Manager contract is read-only, versioned and emits atomic JSON snapshots.
API_DIR="$tmp/api"
API_STATUS_FILE="$API_DIR/status.json"
API_CAPABILITIES_FILE="$API_DIR/capabilities.json"
API_CONFIG_SCHEMA_FILE="$API_DIR/config-schema.json"
API_LAST_REFRESH_FILE="$STATE_DIR/manager-api-last-refresh"
manager_api_init
if ! manager_api_write_status; then
  echo "manager_api_write_status failed" >&2
  exit 1
fi
python3 - "$API_STATUS_FILE" "$API_CAPABILITIES_FILE" <<'PY'
import json, sys
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        json.load(fh)
PY
grep -q '"schema": 3' "$API_STATUS_FILE"
grep -q '"schema": 3' "$API_CAPABILITIES_FILE"
# ACL instability fields are additive; the schema number stays 3 so existing
# managers (which accept schema 1..3) keep working.
grep -q '"acl_instability": true' "$API_CAPABILITIES_FILE"
grep -q '"acl_instability": {' "$API_STATUS_FILE"
grep -q '"abnormal_window_count":' "$API_STATUS_FILE"
grep -q '"service_state":' "$API_STATUS_FILE"
grep -q '"settings": {' "$API_STATUS_FILE"
grep -q '"service_state": "READY"' "$API_STATUS_FILE"
grep -q '"manufacturer": "Google"' "$API_STATUS_FILE"
grep -q '"root_provider":' "$API_STATUS_FILE"
grep -q '"service_uptime_seconds":' "$API_STATUS_FILE"
grep -q '"failure_threshold":' "$API_STATUS_FILE"
grep -q '"android_codename": "REL"' "$API_STATUS_FILE"
grep -q '"android_preview_build": "no"' "$API_STATUS_FILE"
grep -Fq 'BSH-Diagnostics-' "$MODDIR/scripts/diagnostics.sh"
grep -Fq 'REDACTED-MAC' "$MODDIR/scripts/diagnostics.sh"
grep -q '"read_only": true' "$API_CAPABILITIES_FILE"
grep -q '"remote_commands": false' "$API_CAPABILITIES_FILE"
grep -q '"WATCHDOG_INTERVAL"' "$API_CONFIG_SCHEMA_FILE"
grep -q '"ACL_INSTABILITY_THRESHOLD"' "$API_CONFIG_SCHEMA_FILE"

# --- ACL link-instability evidence ------------------------------------------
reset_test_paths
acl_dump="$tmp/acl-dump.txt"
cat > "$acl_dump" <<'ACL'
  11-02 08:32:23.708 [XX:XX:XX:XX:D0:C0] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:8, Adapter state:ON
  11-02 08:32:41.203 [XX:XX:XX:XX:D0:C0] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:11, Adapter state:ON
  11-02 08:33:35.895 [XX:XX:XX:XX:D0:C0] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:34, Adapter state:ON
  11-02 12:22:42.634 [XX:XX:XX:XX:7A:1C] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:19, Adapter state:ON
ACL
# Three abnormal disconnects (8, 11, 34); the normal reason:19 is excluded.
[ "$(acl_abnormal_lines < "$acl_dump" | wc -l | tr -d ' ')" = 3 ]
# First scan is a baseline only, so startup never injects a storm.
rm -f "$STATE_DIR/acl-last-line" "$STATE_DIR/acl-events" "$STATE_DIR/acl-window-count"
[ "$(acl_new_abnormal_count "$acl_dump")" = 0 ]
# A newly appended abnormal disconnect counts as exactly one new event.
printf '%s\n' '  11-02 15:13:25.687 [XX:XX:XX:XX:D0:C0] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:8, Adapter state:ON' >> "$acl_dump"
[ "$(acl_new_abnormal_count "$acl_dump")" = 1 ]
# Windowed count feeds a capped health penalty.
acl_record_new_events 4
[ "$(acl_abnormal_window_count)" -ge 4 ]
acl_abnormal_window_count > "$STATE_DIR/acl-window-count"
[ "$(acl_instability_penalty)" -gt 0 ]
# A dump of only normal disconnects registers nothing.
printf '%s\n' '  11-02 17:01:43.577 [XX:XX:XX:XX:7A:1C] aclStateChangeCallback: State:Disconnected, transport:BR/EDR, Address type:Public, reason:19, Adapter state:ON' > "$acl_dump"
[ "$(acl_abnormal_lines < "$acl_dump" | wc -l | tr -d ' ')" = 0 ]
# Health export carries the component breakdown.
export_bluetooth_health_score > /dev/null
python3 - "$CONFIG_DIR/metrics/bluetooth-health.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert "components" in d and "acl_instability" in d["components"], d
assert "acl_abnormal_window_count" in d, d
PY

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

# v1.8 API contract test refresh

#!/system/bin/sh
# Bluetooth Stability Helper manager data contract.
# Canonical snapshots live in the private Magisk module tree; a best-effort
# shared-storage mirror remains available for diagnostics and manual support.

PRIVATE_API_DIR="${PRIVATE_API_DIR:-${MODDIR:-/data/adb/modules/btstabilityhelper}/runtime/api}"
EXTERNAL_API_DIR="${EXTERNAL_API_DIR:-${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/api}"
API_DIR="${API_DIR:-$PRIVATE_API_DIR}"
API_SCHEMA_VERSION=3
API_STATUS_FILE="$API_DIR/status.json"
API_CAPABILITIES_FILE="$API_DIR/capabilities.json"
API_CONFIG_SCHEMA_FILE="$API_DIR/config-schema.json"
API_LAST_REFRESH_FILE="${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/manager-api-last-refresh"

manager_api_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

manager_api_mirror_file() {
  src="$1"; name="$2"
  [ -f "$src" ] || return 0
  mkdir -p "$EXTERNAL_API_DIR" 2>/dev/null || return 0
  api_mirror_tmp="$EXTERNAL_API_DIR/$name.tmp"
  cp "$src" "$api_mirror_tmp" 2>/dev/null && mv "$api_mirror_tmp" "$EXTERNAL_API_DIR/$name" 2>/dev/null
}

manager_api_init() {
  mkdir -p "$API_DIR" 2>/dev/null
  mkdir -p "$(dirname "$API_LAST_REFRESH_FILE")" 2>/dev/null
  manager_api_write_capabilities
  manager_api_write_config_schema
}

manager_api_write_capabilities() {
  api_cap_tmp="$API_CAPABILITIES_FILE.tmp"
  cat > "$api_cap_tmp" <<EOF
{
  "schema": $API_SCHEMA_VERSION,
  "module": "Bluetooth Stability Helper",
  "manager_api": "3",
  "read_only": true,
  "root_engine_required": true,
  "canonical_location": "$PRIVATE_API_DIR",
  "external_mirror": "$EXTERNAL_API_DIR",
  "supports": {
    "health": true,
    "recovery_state": true,
    "fault_events": true,
    "recovery_history": true,
    "watchdog_heartbeat": true,
    "profile": true,
    "diagnostic_export": true,
    "config_schema": true,
    "remote_commands": false,
    "arbitrary_shell": false
  }
}
EOF
  mv "$api_cap_tmp" "$API_CAPABILITIES_FILE" 2>/dev/null
  manager_api_mirror_file "$API_CAPABILITIES_FILE" capabilities.json
}

manager_api_write_config_schema() {
  api_cfg_tmp="$API_CONFIG_SCHEMA_FILE.tmp"
  cat > "$api_cfg_tmp" <<'EOF'
{
  "schema": 3,
  "config_file": "/sdcard/Bluetooth-Stability-Helper/user-config.sh",
  "write_policy": "future-manager-controlled-safe-overrides-only",
  "fields": {
    "WATCHDOG_INTERVAL": {"type":"integer","min":10,"max":300},
    "MAX_RESTARTS_PER_HOUR": {"type":"integer","min":0,"max":6},
    "FAILURE_THRESHOLD": {"type":"integer","min":1,"max":10},
    "FAILURE_WINDOW_SECONDS": {"type":"integer","min":30,"max":1800},
    "RECOVERY_COOLDOWN": {"type":"integer","min":60,"max":7200},
    "STALE_SESSION_MINUTES": {"type":"integer","min":5,"max":240},
    "ENABLE_ADAPTER_TOGGLE_RECOVERY": {"type":"boolean"},
    "ENABLE_INTERACTION_FREEZE_GUARD": {"type":"boolean"},
    "LOG_IMPORTANT_ONLY": {"type":"boolean"}
  }
}
EOF
  mv "$api_cfg_tmp" "$API_CONFIG_SCHEMA_FILE" 2>/dev/null
  manager_api_mirror_file "$API_CONFIG_SCHEMA_FILE" config-schema.json
}

manager_api_heartbeat_age() {
  heartbeat=$(cat "${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/service-heartbeat" 2>/dev/null)
  now=$(date +%s)
  case "$heartbeat" in ''|*[!0-9]*) echo -1 ;; *) echo $((now-heartbeat)) ;; esac
}

manager_api_refresh_due() {
  now=$(date +%s)
  last=$(cat "$API_LAST_REFRESH_FILE" 2>/dev/null)
  case "$last" in ''|*[!0-9]*) return 0 ;; esac
  [ $((now-last)) -ge "${MANAGER_API_REFRESH_SECONDS:-30}" ]
}

manager_api_write_status() {
  mkdir -p "$API_DIR" 2>/dev/null || return 1
  metrics_dir="${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"
  api_status_tmp="$API_STATUS_FILE.tmp"
  score=$(bluetooth_health_score 2>/dev/null); [ -n "$score" ] || score=0
  profile="${PROFILE_ID:-$(device_profile_id 2>/dev/null)}"; [ -n "$profile" ] || profile=unknown
  state=$(recovery_state 2>/dev/null); [ -n "$state" ] || state=UNKNOWN
  fault=$(cat "${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/last-fault-type" 2>/dev/null); [ -n "$fault" ] || fault=none
  outcome=$(last_recovery_outcome 2>/dev/null); [ -n "$outcome" ] || outcome=none
  go=$(active_pokemon_go 2>/dev/null || true); [ -n "$go" ] || go=none
  pm=$(active_pokemod 2>/dev/null || true); [ -n "$pm" ] || pm=none
  service_start=$(cat "${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/service-start-time" 2>/dev/null); case "$service_start" in ''|*[!0-9]*) service_start=0 ;; esac
  now_epoch=$(date +%s); service_uptime=0; [ "$service_start" -gt 0 ] && service_uptime=$((now_epoch-service_start))
  root_provider="Root"; command -v magisk >/dev/null 2>&1 && root_provider="Magisk"; command -v ksud >/dev/null 2>&1 && root_provider="KernelSU"; command -v apd >/dev/null 2>&1 && root_provider="APatch"
  zygisk="unknown"; command -v magisk >/dev/null 2>&1 && zygisk=$(magisk --zygisk 2>/dev/null || echo unknown)
  boot_completed=$(getprop sys.boot_completed 2>/dev/null); [ "$boot_completed" = 1 ] && service_state="READY" || service_state="BOOTING"
  cat > "$api_status_tmp" <<EOF
{
  "schema": $API_SCHEMA_VERSION,
  "timestamp": "$(date '+%F %T')",
  "epoch": $(date +%s),
  "module_detected": true,
  "module_id": "btstabilityhelper",
  "module_version": "$(manager_api_json_escape "$(module_version 2>/dev/null)")",
  "service_state": "$service_state",
  "service_start_epoch": $service_start,
  "service_uptime_seconds": $service_uptime,
  "root_provider": "$root_provider",
  "zygisk": "$(manager_api_json_escape "$zygisk")",
  "profile": "$(manager_api_json_escape "$profile")",
  "health_score": $score,
  "recovery_state": "$(manager_api_json_escape "$state")",
  "last_fault_type": "$(manager_api_json_escape "$fault")",
  "last_recovery_outcome": "$(manager_api_json_escape "$outcome")",
  "bluetooth_enabled": "$(bt_enabled_setting 2>/dev/null)",
  "bluetooth_process_count": "$(bt_process_count 2>/dev/null)",
  "watchdog_heartbeat_age_seconds": $(manager_api_heartbeat_age),
  "android_sdk": "$(sdk_int 2>/dev/null)",
  "android_release": "$(manager_api_json_escape "$(getprop ro.build.version.release 2>/dev/null)")",
  "brand": "$(manager_api_json_escape "$(getprop ro.product.brand 2>/dev/null)")",
  "manufacturer": "$(manager_api_json_escape "$(getprop ro.product.manufacturer 2>/dev/null)")",
  "model": "$(manager_api_json_escape "$(getprop ro.product.model 2>/dev/null)")",
  "device": "$(manager_api_json_escape "$(getprop ro.product.device 2>/dev/null)")",
  "build_fingerprint": "$(manager_api_json_escape "$(getprop ro.build.fingerprint 2>/dev/null)")",
  "build_id": "$(manager_api_json_escape "$(build_id 2>/dev/null)")",
  "security_patch": "$(manager_api_json_escape "$(security_patch 2>/dev/null)")",
  "active_pokemon_go": "$(manager_api_json_escape "$go")",
  "active_pokemod_vpgp3": "$(manager_api_json_escape "$pm")",
  "settings": {
    "watchdog_enabled": "${WATCHDOG_ENABLED:-1}",
    "watchdog_interval": "${WATCHDOG_INTERVAL:-25}",
    "failure_threshold": "${FAILURE_THRESHOLD:-2}",
    "failure_window_seconds": "${FAILURE_WINDOW_SECONDS:-180}",
    "recovery_cooldown": "${RECOVERY_COOLDOWN:-600}",
    "max_restarts_per_hour": "${MAX_RESTARTS_PER_HOUR:-2}",
    "adapter_toggle_recovery": "${ENABLE_ADAPTER_TOGGLE_RECOVERY:-1}",
    "interaction_freeze_guard": "${ENABLE_INTERACTION_FREEZE_GUARD:-1}",
    "stale_session_minutes": "${STALE_SESSION_MINUTES:-20}",
    "ble_scan_always_enabled": "$(settings get global ble_scan_always_enabled 2>/dev/null)",
    "location_mode": "$(settings get secure location_mode 2>/dev/null)"
  },
  "events_file": "$metrics_dir/events.jsonl",
  "recovery_history_file": "$metrics_dir/recovery-history.jsonl",
  "health_file": "$metrics_dir/bluetooth-health.json"
}
EOF
  mv "$api_status_tmp" "$API_STATUS_FILE" 2>/dev/null || return 1
  manager_api_mirror_file "$API_STATUS_FILE" status.json
  date +%s > "$API_LAST_REFRESH_FILE" 2>/dev/null
}

manager_api_refresh() {
  manager_api_refresh_due || return 0
  manager_api_init
  manager_api_write_status
}

#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
LOG="${LOG:-/sdcard/Bluetooth-Stability-Helper/logs/bt-stability.log}"
STATE_DIR="${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}"
mkdir -p "$STATE_DIR"

_log_should_keep() {
  msg="$1"
  [ "${LOG_IMPORTANT_ONLY:-1}" != "1" ] && return 0
  echo "$msg" | grep -qiE 'start|boot|clean|guard active|warning|error|fail|failure|recover|recovery|restart|skipped|stale|stall|freeze|crash|binder died|dead object|gatt|hci|bond|encryption|permission|location warning|bluetooth enabled but no|did not report|health score: ([0-6][0-9]|70)|snapshot|exported|max|storage|rotat|prun|cleanup|Pokémon GO running|not detected' && return 0
  return 1
}

_log_dedup_ok() {
  msg="$1"
  dedup="${LOG_DEDUP_SECONDS:-300}"
  [ "$dedup" = "0" ] && return 0
  key=$(echo "$msg" | tr -cd '[:alnum:] _.-' | cut -c1-80 | tr ' /' '__')
  [ -z "$key" ] && key=message
  f="$STATE_DIR/logdedup_$key"
  now=$(date +%s)
  last=$(cat "$f" 2>/dev/null)
  if [ -n "$last" ] && [ $((now-last)) -lt "$dedup" ]; then return 1; fi
  echo "$now" > "$f" 2>/dev/null
  return 0
}

log_rotate_enforce() {
  [ -n "$LOG" ] || return 0
  mkdir -p "$(dirname "$LOG")" "$STATE_DIR" 2>/dev/null
  [ -f "$LOG" ] || return 0
  size_kb=$(du -k "$LOG" 2>/dev/null | awk '{print $1}')
  [ -z "$size_kb" ] && return 0
  if [ "$size_kb" -gt "${LOG_ROTATE_SIZE_KB:-256}" ]; then
    keep="${LOG_KEEP_ROTATED_COUNT:-2}"
    i="$keep"
    while [ "$i" -ge 1 ]; do
      prev=$((i-1))
      [ "$prev" -eq 0 ] && src="$LOG" || src="$LOG.$prev"
      dst="$LOG.$i"
      [ -f "$src" ] && mv "$src" "$dst" 2>/dev/null
      i=$((i-1))
    done
    : > "$LOG"
  fi
}

log_storage_guard() {
  dir=$(dirname "$LOG")
  [ -d "$dir" ] || return 0
  max_kb=$(( ${LOG_MAX_TOTAL_MB:-10} * 1024 ))
  total=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
  [ -z "$total" ] && return 0
  [ "$total" -le "$max_kb" ] && return 0
  # Keep the newest small active log and remove old rotated/exported log files first.
  find "$dir" -type f ! -name 'bt-stability.log' -delete 2>/dev/null
  : > "$LOG" 2>/dev/null
  echo "$(date '+%F %T')  Log storage guard trimmed logs after exceeding ${LOG_MAX_TOTAL_MB:-10}MB" >> "$LOG"
}

log() {
  msg="$1"
  _log_should_keep "$msg" || return 0
  _log_dedup_ok "$msg" || return 0
  mkdir -p "$(dirname "$LOG")" "$STATE_DIR" 2>/dev/null
  log_rotate_enforce
  echo "$(date '+%F %T')  $msg" >> "$LOG"
  log_storage_guard
}

package_running() { pkg="$1"; [ -n "$pkg" ] || return 1; pidof "$pkg" >/dev/null 2>&1 && return 0; ps -A 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; ps 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; return 1; }
package_installed() { pkg="$1"; [ -n "$pkg" ] || return 1; cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; }
first_installed_from_list() { for pkg in $1; do package_installed "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
first_running_from_list() { for pkg in $1; do package_running "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
whitelist_pkg() {
  pkg="$1"; [ -n "$pkg" ] || return 0
  if cmd deviceidle whitelist 2>/dev/null | grep -qx "$pkg"; then return 0; fi
  if cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1; then
    echo "$pkg" >> "$MODDIR/state/added-idle-whitelist.txt" 2>/dev/null
    log "Whitelisted from idle: $pkg"
  fi
}
appops_allow_safe() { pkg="$1"; op="$2"; package_installed "$pkg" || return 0; cmd appops set "$pkg" "$op" allow >/dev/null 2>&1 && log "AppOps allow: $pkg $op"; }

module_version() { sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n1; }

# Never source executable shell from shared storage. Only a documented set of
# scalar overrides is accepted, validated, and copied into a private state file.
load_user_config() {
  cfg="$1"; [ -f "$cfg" ] || return 0
  safe="$STATE_DIR/user-config.safe"
  : > "$safe" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key=${line%%=*}; value=${line#*=}
    [ "$key" != "$line" ] || { log "Config warning: ignored malformed override"; continue; }
    case "$value" in
      \"*\") value=${value#\"}; value=${value%\"} ;;
      \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    case "$key" in
      WATCHDOG_INTERVAL|LOG_IMPORTANT_ONLY|LOG_DEDUP_SECONDS|LOG_BOOT_CLEAN|LOG_ROTATE_SIZE_KB|LOG_KEEP_ROTATED_COUNT|LOG_MAX_TOTAL_MB|EXPORT_MAX_FILES|METRICS_MAX_KB|SNAPSHOT_MAX_FILES|LOGCAT_CAPTURE_LINES|LOGCAT_CAPTURE_WINDOW_SECONDS|MAX_RESTARTS_PER_HOUR|FAILURE_THRESHOLD|FAILURE_WINDOW_SECONDS|RECOVERY_COOLDOWN|FRESH_FAULT_MAX_AGE_SECONDS|STALE_SESSION_MINUTES|ENABLE_STALE_SESSION_WATCHDOG|STALE_SESSION_BT_REFRESH|ENABLE_INTERACTION_FREEZE_GUARD|INTERACTION_FREEZE_RECOVERY_AFTER_MATCHES|ENABLE_ADAPTER_TOGGLE_RECOVERY|ENABLE_BLUETOOTH_APP_FORCE_STOP|ENABLE_A2DP_OFFLOAD_DISABLE|ENABLE_BLE_SCAN_ALWAYS|ENABLE_WIFI_SCAN_THROTTLE_OFF|ENABLE_LOCATION_BG_THROTTLE_OFF|APPLY_APP_OPS_FIXES|APPLY_RESTRICTED_STANDBY_FIXES|WHITELIST_BLUETOOTH|WHITELIST_GMS|WHITELIST_POKEMON_GO|WHITELIST_POKEMOD|RUN_DIAGNOSTICS_ON_BOOT)
        printf '%s' "$value" | grep -Eq '^[0-9]+$' || { log "Config warning: ignored invalid numeric override: $key"; continue; }
        printf '%s=%s\n' "$key" "$value" >> "$safe"
        ;;
      STALE_SESSION_ACTION)
        case "$value" in log|diagnose) printf '%s=%s\n' "$key" "$value" >> "$safe" ;; *) log "Config warning: ignored unsafe stale-session action" ;; esac
        ;;
      WHITELIST_EXTRA_PACKAGES)
        printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._ -]*$' || { log "Config warning: ignored invalid package list"; continue; }
        printf '%s="%s"\n' "$key" "$value" >> "$safe"
        ;;
      *) log "Config warning: ignored unsupported override: $key" ;;
    esac
  done < "$cfg"
  . "$safe"
}

# Return success once for each new, recent matching log event. Re-reading the
# same logcat line can no longer increment the failure ladder every loop.
fresh_log_fault() {
  observer="$1"; pattern="$2"; lines="${3:-240}"
  match=$(logcat -d -v epoch -t "$lines" 2>/dev/null | grep -iE "$pattern" | tail -n1)
  [ -n "$match" ] || return 1
  event_epoch=$(echo "$match" | awk '{print int($1)}')
  now=$(date +%s)
  case "$event_epoch" in ''|*[!0-9]*) event_epoch="$now" ;; esac
  [ $((now-event_epoch)) -le "${FRESH_FAULT_MAX_AGE_SECONDS:-180}" ] || return 1
  signature=$(printf '%s' "$match" | cksum 2>/dev/null | awk '{print $1":"$2}')
  [ -n "$signature" ] || return 1
  sigfile="$STATE_DIR/fault-signature-$observer"
  [ "$(cat "$sigfile" 2>/dev/null)" = "$signature" ] && return 1
  echo "$signature" > "$sigfile"
  echo "$event_epoch" > "$STATE_DIR/last-fresh-fault-epoch"
  printf '%s\n' "$match" > "$STATE_DIR/last-fresh-fault.txt"
  return 0
}


sdk_int() { getprop ro.build.version.sdk 2>/dev/null; }
build_id() { getprop ro.build.id 2>/dev/null; }
build_fingerprint() { getprop ro.build.fingerprint 2>/dev/null; }
security_patch() { getprop ro.build.version.security_patch 2>/dev/null; }
build_family() { build_id | sed 's/[0-9].*//' 2>/dev/null; }
write_metric_json() { file="$1"; shift; mkdir -p "$STATE_DIR" "${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"; printf '%s\n' "$*" > "$file"; }
is_pixel_android16_may2026() { is_pixel_device || return 1; [ "$(sdk_int)" -ge "$ANDROID16_SDK" ] || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; echo "$bid $fp" | grep -q "$PIXEL_ANDROID16_MAY2026_BUILD_PREFIX"; }
is_android17_or_newer() { [ "$(sdk_int)" -ge "$ANDROID17_SDK" ]; }
is_pixel_android17() { is_pixel_device || return 1; is_android17_or_newer || return 1; }
is_known_pixel_android17_build_family() { is_pixel_android17 || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; for prefix in $PIXEL_ANDROID17_KNOWN_BUILD_PREFIXES; do echo "$bid $fp" | grep -q "$prefix" && return 0; done; return 1; }
is_pixel_android17_july2026_cp2a() { is_pixel_android17 || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; echo "$bid $fp" | grep -q "${PIXEL_ANDROID17_JULY2026_BUILD_PREFIX:-CP2A.260705}"; }
brand_lc() { getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
manufacturer_lc() { getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
is_pixel_device() { [ "$(brand_lc)" = "google" ] || echo "$(getprop ro.product.model 2>/dev/null)" | grep -qi '^pixel'; }
device_profile_id() {
  brand=$(brand_lc); maker=$(manufacturer_lc); model=$(getprop ro.product.model 2>/dev/null | tr '[:upper:]' '[:lower:]')
  all="$brand $maker $model"
  case "$all" in
    *google*|*pixel*) echo pixel ;;
    *samsung*) echo samsung ;;
    *xiaomi*|*redmi*|*poco*) echo xiaomi ;;
    *oneplus*|*oppo*|*realme*) echo oplus ;;
    *nothing*) echo nothing ;;
    *motorola*|*moto\ *) echo motorola ;;
    *asus*|*rog\ phone*) echo asus ;;
    *sony*|*xperia*) echo sony ;;
    *vivo*|*iqoo*) echo vivo ;;
    *huawei*|*honor*) echo huawei ;;
    *) echo generic ;;
  esac
}
recent_bt_stall_score_penalty() {
  active_bluetooth_game >/dev/null 2>&1 || { echo 0; return; }
  last=$(cat "$STATE_DIR/last-fresh-fault-epoch" 2>/dev/null); now=$(date +%s)
  [ -n "$last" ] && [ $((now-last)) -le "${FRESH_FAULT_MAX_AGE_SECONDS:-180}" ] && echo 20 || echo 0
}
bluetooth_health_score() {
  score=100
  [ "$(bt_enabled_setting)" = 1 ] || score=$((score-35))
  [ "$(bt_process_count)" -gt 0 ] || score=$((score-25))
  health_bad_state && score=$((score-20))
  penalty=$(recent_bt_stall_score_penalty); score=$((score-penalty))
  active_bluetooth_game >/dev/null 2>&1 && [ "$penalty" -gt 0 ] && score=$((score-10))
  [ "$score" -lt 0 ] && score=0
  echo "$score"
}
export_bluetooth_health_score() {
  [ "${ENABLE_BLUETOOTH_HEALTH_SCORE:-1}" = 1 ] || return 0
  metrics_dir="${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"; mkdir -p "$metrics_dir"
  score=$(bluetooth_health_score)
  cat > "$metrics_dir/bluetooth-health.json" <<EOF
{
  "timestamp": "$(date '+%F %T')",
  "score": $score,
  "device": "$(getprop ro.product.brand 2>/dev/null) $(getprop ro.product.model 2>/dev/null)",
  "sdk": "$(sdk_int)",
  "android": "$(getprop ro.build.version.release 2>/dev/null)",
  "build_id": "$(build_id)",
  "security_patch": "$(security_patch)",
  "active_pokemon_go": "$(active_pokemon_go 2>/dev/null)",
  "active_pokemod_vpgp3": "$(active_pokemod 2>/dev/null)",
  "bt_enabled_setting": "$(bt_enabled_setting)",
  "bt_process_count": "$(bt_process_count)"
}
EOF
  echo "$score"
}
check_android_support() { [ "$ENABLE_ANDROID_VERSION_WARNINGS" = 1 ] || return; sdk=$(sdk_int); [ -z "$sdk" ] && return; if [ "$sdk" -lt "$SUPPORTED_SDK_MIN" ] || [ "$sdk" -gt "$SUPPORTED_SDK_MAX" ]; then log "Android SDK warning: sdk=$sdk outside tested range $SUPPORTED_SDK_MIN-$SUPPORTED_SDK_MAX"; fi; }
apply_device_profile() {
  [ "$ENABLE_SDK_AWARE_TUNING" = 1 ] || return
  profile=$(device_profile_id)
  sdk=$(sdk_int)
  case "$sdk" in
    ''|*[!0-9]*) profile="unsupported" ;;
    *) [ "$sdk" -ge "$SUPPORTED_SDK_MIN" ] && [ "$sdk" -le "$SUPPORTED_SDK_MAX" ] || profile="unsupported" ;;
  esac
  . "$MODDIR/common/profiles/generic.sh"
  profile_file="$MODDIR/common/profiles/$profile.sh"
  [ -f "$profile_file" ] && . "$profile_file"
  case "$profile" in
    pixel) apply_profile_pixel ;;
    samsung) apply_profile_samsung ;;
    xiaomi) apply_profile_xiaomi ;;
    oplus) apply_profile_oplus ;;
    nothing) apply_profile_nothing ;;
    motorola) apply_profile_motorola ;;
    asus) apply_profile_asus ;;
    sony) apply_profile_sony ;;
    vivo) apply_profile_vivo ;;
    huawei) apply_profile_huawei ;;
    unsupported)
      apply_profile_generic
      PROFILE_ID="unsupported"
      PROFILE_LABEL="Unsupported Android diagnostic fallback"
      ENABLE_ADAPTER_TOGGLE_RECOVERY=0
      APPLY_RESTRICTED_STANDBY_FIXES=0
      log "Android version outside validated range; automatic recovery disabled"
      ;;
    *) apply_profile_generic ;;
  esac
}

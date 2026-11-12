#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
LOG="${LOG:-/sdcard/Bluetooth-Stability-Helper/logs/bt-stability.log}"
STATE_DIR="${STATE_DIR:-/data/adb/bsh-state}"
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

_numeric_override_in_range() {
  key="$1"; value="$2"; min=0; max=2147483647
  case "$key" in
    WATCHDOG_INTERVAL) min=10; max=300 ;;
    LOG_DEDUP_SECONDS) min=0; max=3600 ;;
    LOG_ROTATE_SIZE_KB) min=64; max=4096 ;;
    LOG_KEEP_ROTATED_COUNT) min=1; max=10 ;;
    LOG_MAX_TOTAL_MB) min=1; max=100 ;;
    EXPORT_MAX_FILES) min=1; max=50 ;;
    METRICS_MAX_KB) min=64; max=4096 ;;
    SNAPSHOT_MAX_FILES) min=1; max=20 ;;
    LOGCAT_CAPTURE_LINES) min=20; max=500 ;;
    LOGCAT_CAPTURE_WINDOW_SECONDS) min=30; max=1800 ;;
    MAX_RESTARTS_PER_HOUR) min=0; max=6 ;;
    FAILURE_THRESHOLD) min=1; max=10 ;;
    FAILURE_WINDOW_SECONDS) min=30; max=1800 ;;
    RECOVERY_COOLDOWN) min=60; max=7200 ;;
    FRESH_FAULT_MAX_AGE_SECONDS) min=30; max=900 ;;
    STALE_SESSION_MINUTES) min=5; max=240 ;;
    INTERACTION_FREEZE_RECOVERY_AFTER_MATCHES) min=1; max=10 ;;
    ACL_INSTABILITY_WINDOW_SECONDS) min=60; max=1800 ;;
    ACL_INSTABILITY_THRESHOLD) min=2; max=20 ;;
    ACL_INSTABILITY_MAX_NEW_PER_TICK) min=1; max=50 ;;
    WATCHDOG_JITTER_SECONDS) min=0; max=60 ;;
    LOG_IMPORTANT_ONLY|LOG_BOOT_CLEAN|ENABLE_STALE_SESSION_WATCHDOG|STALE_SESSION_BT_REFRESH|ENABLE_INTERACTION_FREEZE_GUARD|ENABLE_ADAPTER_TOGGLE_RECOVERY|ENABLE_BLUETOOTH_APP_FORCE_STOP|ENABLE_A2DP_OFFLOAD_DISABLE|ENABLE_BLE_SCAN_ALWAYS|ENABLE_WIFI_SCAN_THROTTLE_OFF|ENABLE_LOCATION_BG_THROTTLE_OFF|APPLY_APP_OPS_FIXES|APPLY_RESTRICTED_STANDBY_FIXES|WHITELIST_BLUETOOTH|WHITELIST_GMS|WHITELIST_POKEMON_GO|WHITELIST_POKEMOD|RUN_DIAGNOSTICS_ON_BOOT|ENABLE_ACL_INSTABILITY_GUARD|ACL_INSTABILITY_RECOVERY_ENABLED) min=0; max=1 ;;
  esac
  [ "$value" -ge "$min" ] 2>/dev/null && [ "$value" -le "$max" ] 2>/dev/null
}
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
      WATCHDOG_INTERVAL|LOG_IMPORTANT_ONLY|LOG_DEDUP_SECONDS|LOG_BOOT_CLEAN|LOG_ROTATE_SIZE_KB|LOG_KEEP_ROTATED_COUNT|LOG_MAX_TOTAL_MB|EXPORT_MAX_FILES|METRICS_MAX_KB|SNAPSHOT_MAX_FILES|LOGCAT_CAPTURE_LINES|LOGCAT_CAPTURE_WINDOW_SECONDS|MAX_RESTARTS_PER_HOUR|FAILURE_THRESHOLD|FAILURE_WINDOW_SECONDS|RECOVERY_COOLDOWN|FRESH_FAULT_MAX_AGE_SECONDS|STALE_SESSION_MINUTES|ENABLE_STALE_SESSION_WATCHDOG|STALE_SESSION_BT_REFRESH|ENABLE_INTERACTION_FREEZE_GUARD|INTERACTION_FREEZE_RECOVERY_AFTER_MATCHES|ENABLE_ADAPTER_TOGGLE_RECOVERY|ENABLE_BLUETOOTH_APP_FORCE_STOP|ENABLE_A2DP_OFFLOAD_DISABLE|ENABLE_BLE_SCAN_ALWAYS|ENABLE_WIFI_SCAN_THROTTLE_OFF|ENABLE_LOCATION_BG_THROTTLE_OFF|APPLY_APP_OPS_FIXES|APPLY_RESTRICTED_STANDBY_FIXES|WHITELIST_BLUETOOTH|WHITELIST_GMS|WHITELIST_POKEMON_GO|WHITELIST_POKEMOD|RUN_DIAGNOSTICS_ON_BOOT|ENABLE_ACL_INSTABILITY_GUARD|ACL_INSTABILITY_WINDOW_SECONDS|ACL_INSTABILITY_THRESHOLD|ACL_INSTABILITY_MAX_NEW_PER_TICK|ACL_INSTABILITY_RECOVERY_ENABLED|WATCHDOG_JITTER_SECONDS)
        printf '%s' "$value" | grep -Eq '^[0-9]+$' || { log "Config warning: ignored invalid numeric override: $key"; continue; }
        _numeric_override_in_range "$key" "$value" || { log "Config warning: ignored out-of-range override: $key=$value"; continue; }
        printf '%s=%s\n' "$key" "$value" >> "$safe"
        ;;
      STALE_SESSION_ACTION)
        case "$value" in log|diagnose) printf '%s=%s\n' "$key" "$value" >> "$safe" ;; *) log "Config warning: ignored unsafe stale-session action" ;; esac
        ;;
      WHITELIST_EXTRA_PACKAGES)
        printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._ -]*$' || { log "Config warning: ignored invalid package list"; continue; }
        printf '%s="%s"\n' "$key" "$value" >> "$safe"
        ;;
      ACL_ABNORMAL_DISCONNECT_REASONS)
        printf '%s' "$value" | grep -Eq '^[0-9 ]*$' || { log "Config warning: ignored invalid ACL reason list"; continue; }
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
  echo "$observer" > "$STATE_DIR/last-fault-type"
  command -v record_event >/dev/null 2>&1 && record_event "fault" "warning" "$observer" "Fresh fault evidence accepted" "" ""
  return 0
}


# --- ACL link-instability evidence -----------------------------------------
# Pixel Bluetooth HALs rarely crash. The real-world instability symptom is a
# cluster of abnormal ACL disconnects (link-supervision / LL response timeouts)
# while the adapter stays ON. These are reported by dumpsys bluetooth_manager as
# "aclStateChangeCallback: State:Disconnected ... reason:N" lines, which the
# log-pattern observers never matched. Parsing is kept pure and testable.

# Read dumpsys bluetooth_manager text on stdin and print, oldest-first, each
# abnormal disconnect as "reason|<full line>". Normal reasons (19 remote-user
# terminated, 22 local-host terminated, 16) are intentionally excluded.
acl_abnormal_lines() {
  awk -v reasons=" ${ACL_ABNORMAL_DISCONNECT_REASONS:-8 11 34 40 61} " '
    /aclStateChangeCallback/ && /State:Disconnected/ {
      if (match($0, /reason:[0-9]+/)) {
        r = substr($0, RSTART + 7, RLENGTH - 7)
        if (index(reasons, " " r " ") > 0) print r "|" $0
      }
    }'
}

# Count abnormal disconnects that are NEW since the last scan. The dump is a
# bounded, chronological ring buffer, so we anchor on the previously seen newest
# line: everything after it is new. First run establishes a baseline (new=0) so
# startup never injects a storm, and a per-tick cap bounds buffer rollovers.
acl_new_abnormal_count() {
  dump="$1"
  prevfile="$STATE_DIR/acl-last-line"
  prev=""
  [ -f "$prevfile" ] && prev=$(cat "$prevfile" 2>/dev/null)
  lines=$(acl_abnormal_lines < "$dump")
  [ -n "$lines" ] || { echo 0; return; }
  newest=$(printf '%s\n' "$lines" | tail -n1)
  total=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
  if [ -z "$prev" ]; then
    new=0
  else
    idx=$(printf '%s\n' "$lines" | grep -nFx "$prev" | head -n1 | cut -d: -f1)
    if [ -n "$idx" ]; then new=$((total - idx)); else new=$total; fi
  fi
  cap="${ACL_INSTABILITY_MAX_NEW_PER_TICK:-10}"
  [ "$new" -gt "$cap" ] && new=$cap
  printf '%s\n' "$newest" > "$prevfile" 2>/dev/null
  echo "$new"
}

acl_record_new_events() {
  n="$1"; now=$(date +%s); f="$STATE_DIR/acl-events"
  i=0; while [ "$i" -lt "$n" ]; do echo "$now" >> "$f" 2>/dev/null; i=$((i + 1)); done
}

# Prune the rolling event file to the window and return how many remain.
acl_abnormal_window_count() {
  now=$(date +%s); win="${ACL_INSTABILITY_WINDOW_SECONDS:-240}"; cutoff=$((now - win))
  f="$STATE_DIR/acl-events"
  [ -f "$f" ] || { echo 0; return; }
  awk -v c="$cutoff" '$1 ~ /^[0-9]+$/ && $1 >= c' "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f" 2>/dev/null
  wc -l < "$f" 2>/dev/null | tr -d ' '
}

# Health-score contribution. Reads the cached window count written by the
# observer so scoring stays side-effect free (no second prune/dump per tick).
acl_instability_penalty() {
  [ "${ENABLE_ACL_INSTABILITY_GUARD:-1}" = 1 ] || { echo 0; return; }
  c=0
  [ -f "$STATE_DIR/acl-window-count" ] && c=$(cat "$STATE_DIR/acl-window-count" 2>/dev/null)
  case "$c" in ''|*[!0-9]*) c=0 ;; esac
  [ "$c" -le 0 ] && { echo 0; return; }
  p=$((c * 7)); [ "$p" -gt 30 ] && p=30; echo "$p"
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
is_pixel_android17_october2026() { is_pixel_android17 || return 1; bid="$(build_id)"; fp="$(build_fingerprint)"; for prefix in $PIXEL_ANDROID17_OCTOBER2026_BUILD_PREFIXES; do echo "$bid $fp" | grep -q "$prefix" && return 0; done; return 1; }
android_codename() { getprop ro.build.version.codename 2>/dev/null; }
# Beta/canary firmware: a non-REL codename, or a known Pixel beta build family.
# Reported for diagnostics only; recovery policy is unchanged.
is_android_preview_build() {
  codename="$(android_codename)"
  [ -n "$codename" ] && [ "$codename" != "REL" ] && return 0
  is_pixel_device || return 1
  bid="$(build_id)"
  for prefix in $PIXEL_PREVIEW_BUILD_PREFIXES; do
    case "$bid" in "$prefix"*) return 0 ;; esac
  done
  return 1
}
brand_lc() { getprop ro.product.brand 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
manufacturer_lc() { getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]'; }
is_pixel_device() { [ "$(brand_lc)" = "google" ] || echo "$(getprop ro.product.model 2>/dev/null)" | grep -qi '^pixel'; }

# Pixel hardware generation, parsed from the model name (e.g. "Pixel 10",
# "Pixel 9 Pro XL", "Pixel 6a" -> 10/9/6). The model string is reliable and
# human-readable, so it is the primary source; a codename fallback covers the
# confirmed current device. Returns 0 when it cannot be determined.
pixel_generation() {
  is_pixel_device || { echo 0; return; }
  model=$(getprop ro.product.model 2>/dev/null)
  gen=""
  case "$model" in
    [Pp]ixel\ [0-9]*) rest=${model#* }; gen=${rest%%[!0-9]*} ;;
  esac
  if [ -z "$gen" ]; then
    case "$(getprop ro.product.device 2>/dev/null)" in
      frankel) gen=10 ;;   # confirmed via device: Pixel 10 (frankel)
      *) gen=0 ;;
    esac
  fi
  echo "${gen:-0}"
}

# Coarse, defensible SoC-era grouping. Pixel 6/7 use the first Tensor designs
# (Exynos-modem era, historically more connectivity quirks); 8/9 are the
# refined middle generations; 10+ are the current designs. Used only for
# diagnostics/bucketing — it does not change recovery policy on its own.
pixel_soc_era() {
  gen=$(pixel_generation)
  case "$gen" in
    6|7) echo "early-tensor" ;;
    8|9) echo "mid-tensor" ;;
    1[0-9]) echo "current-tensor" ;;
    *) echo "unknown" ;;
  esac
}

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
  score=$((score - $(acl_instability_penalty)))
  [ "$score" -lt 0 ] && score=0
  echo "$score"
}
export_bluetooth_health_score() {
  [ "${ENABLE_BLUETOOTH_HEALTH_SCORE:-1}" = 1 ] || return 0
  metrics_dir="${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"; mkdir -p "$metrics_dir"
  score=$(bluetooth_health_score)
  stall_pen=$(recent_bt_stall_score_penalty 2>/dev/null); case "$stall_pen" in ''|*[!0-9]*) stall_pen=0 ;; esac
  acl_pen=$(acl_instability_penalty 2>/dev/null); case "$acl_pen" in ''|*[!0-9]*) acl_pen=0 ;; esac
  acl_count=$(cat "$STATE_DIR/acl-window-count" 2>/dev/null); case "$acl_count" in ''|*[!0-9]*) acl_count=0 ;; esac
  [ "$(bt_enabled_setting)" = 1 ] && bt_off_pen=0 || bt_off_pen=35
  [ "$(bt_process_count)" -gt 0 ] && proc_pen=0 || proc_pen=25
  health_bad_state && state_pen=20 || state_pen=0
  cat > "$metrics_dir/bluetooth-health.json" <<EOF
{
  "timestamp": "$(date '+%F %T')",
  "score": $score,
  "components": {
    "bluetooth_off": $bt_off_pen,
    "no_bt_process": $proc_pen,
    "adapter_bad_state": $state_pen,
    "recent_stall": $stall_pen,
    "acl_instability": $acl_pen
  },
  "acl_abnormal_window_count": $acl_count,
  "device": "$(getprop ro.product.brand 2>/dev/null) $(getprop ro.product.model 2>/dev/null)",
  "sdk": "$(sdk_int)",
  "android": "$(getprop ro.build.version.release 2>/dev/null)",
  "build_id": "$(build_id)",
  "security_patch": "$(security_patch)",
  "active_pokemon_go": "$(active_pokemon_go 2>/dev/null)",
  "active_pokemod_vpgp3": "$(active_pokemod 2>/dev/null)",
  "bt_enabled_setting": "$(bt_enabled_setting)",
  "bt_process_count": "$(bt_process_count)",
  "recovery_state": "$(cat "$STATE_DIR/recovery-state" 2>/dev/null || echo UNKNOWN)",
  "last_fault_type": "$(cat "$STATE_DIR/last-fault-type" 2>/dev/null || echo none)",
  "recoveries_last_hour": "$(count_recent_restarts 2>/dev/null || echo 0)",
  "recovery_history_count": "$(cat "$metrics_dir/recovery-history.jsonl" 2>/dev/null | wc -l | tr -d ' ')",
  "event_history_count": "$(cat "$metrics_dir/events.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
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

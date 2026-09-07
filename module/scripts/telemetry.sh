#!/system/bin/sh
# Bluetooth Stability Helper telemetry primitives.
# Structured, bounded, human-readable data for diagnostics and the future manager app.

TELEMETRY_DIR="${CONFIG_DIR:-/sdcard/Bluetooth-Stability-Helper}/metrics"
EVENT_HISTORY_FILE="${EVENT_HISTORY_FILE:-$TELEMETRY_DIR/events.jsonl}"
RECOVERY_STATE_FILE="${RECOVERY_STATE_FILE:-${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/recovery-state}"
LAST_RECOVERY_OUTCOME_FILE="${LAST_RECOVERY_OUTCOME_FILE:-${STATE_DIR:-/sdcard/Bluetooth-Stability-Helper/state}/last-recovery-outcome}"
TELEMETRY_SCHEMA_VERSION=1

telemetry_init() {
  mkdir -p "$TELEMETRY_DIR" "$(dirname "$RECOVERY_STATE_FILE")" 2>/dev/null
  [ -f "$EVENT_HISTORY_FILE" ] || : > "$EVENT_HISTORY_FILE"
  [ -f "$RECOVERY_STATE_FILE" ] || echo "HEALTHY" > "$RECOVERY_STATE_FILE"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/ /g; s// /g; s/
/ /g'
}

trim_jsonl() {
  file="$1"; keep="$2"
  [ -f "$file" ] || return 0
  lines=$(wc -l < "$file" 2>/dev/null)
  [ -n "$lines" ] || return 0
  [ "$lines" -le "$keep" ] && return 0
  tail -n "$keep" "$file" > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
}

set_recovery_state() {
  telemetry_init
  next="$1"
  current=$(cat "$RECOVERY_STATE_FILE" 2>/dev/null)
  [ "$current" = "$next" ] && return 0
  echo "$next" > "$RECOVERY_STATE_FILE"
  record_event "state_change" "info" "engine" "$current->$next" "" ""
}

recovery_state() {
  telemetry_init
  cat "$RECOVERY_STATE_FILE" 2>/dev/null || echo "UNKNOWN"
}

record_event() {
  telemetry_init
  type="$1"; severity="$2"; source="$3"; message="$4"; action="${5:-}"; outcome="${6:-}"
  now=$(date +%s)
  printf '{"schema":%s,"epoch":%s,"timestamp":"%s","type":"%s","severity":"%s","source":"%s","message":"%s","action":"%s","outcome":"%s"}\n'     "$TELEMETRY_SCHEMA_VERSION" "$now" "$(date '+%F %T')"     "$(json_escape "$type")" "$(json_escape "$severity")" "$(json_escape "$source")"     "$(json_escape "$message")" "$(json_escape "$action")" "$(json_escape "$outcome")" >> "$EVENT_HISTORY_FILE"
  trim_jsonl "$EVENT_HISTORY_FILE" "${EVENT_HISTORY_MAX_LINES:-500}"
}

set_last_recovery_outcome() {
  printf '%s|%s|%s\n' "$(date +%s)" "$1" "$2" > "$LAST_RECOVERY_OUTCOME_FILE"
}

last_recovery_outcome() {
  [ -f "$LAST_RECOVERY_OUTCOME_FILE" ] && cat "$LAST_RECOVERY_OUTCOME_FILE" || echo "none"
}

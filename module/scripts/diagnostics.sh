#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
. "$MODDIR/common/config.sh"
. "$MODDIR/scripts/lib.sh"
apply_device_profile
load_user_config "$LOCAL_USER_CONFIG"
OUT="$EXPORT_DIR/status.txt"
mkdir -p "$EXPORT_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STATE_DIR"
{
 echo "Bluetooth Stability Helper adaptive Bluetooth diagnostics"
 echo "Timestamp: $(date '+%F %T')"
 echo "Version: $(module_version)"
echo "Build ID: $(getprop ro.build.id 2>/dev/null)"
echo "Fingerprint: $(getprop ro.build.fingerprint 2>/dev/null)"
 echo "Profile: ${PROFILE_LABEL:-$(device_profile_id)}"
 echo "Recovery policy: ${FAILURE_THRESHOLD} faults/${FAILURE_WINDOW_SECONDS}s; max ${MAX_RESTARTS_PER_HOUR}/hour; cooldown ${RECOVERY_COOLDOWN}s"
 echo "Automatic adapter recovery: $ENABLE_ADAPTER_TOGGLE_RECOVERY"
 echo "Config dir: $CONFIG_DIR"
 echo "Brand: $(getprop ro.product.brand)"
 echo "Manufacturer: $(getprop ro.product.manufacturer)"
 echo "Model: $(getprop ro.product.model)"
 echo "Device: $(getprop ro.product.device)"
 echo "Android: $(getprop ro.build.version.release) / SDK $(getprop ro.build.version.sdk)"
 echo "Security patch: $(getprop ro.build.version.security_patch)"
 echo "Build fingerprint: $(getprop ro.build.fingerprint)"
 echo "Zygisk: $(magisk --zygisk 2>/dev/null || echo unknown)"
 echo "Bluetooth health score: $(bluetooth_health_score 2>/dev/null)"
 echo "Build family: $(build_family 2>/dev/null)"
 echo "Patch awareness: SDK/build/security-patch profile, no unreleased-patch hard-coding"
 echo "Vector/LSPosed safety: no Zygisk or ART hooks are installed by this module"
 echo
 echo "Bluetooth/location settings:"
 echo "  bluetooth_on=$(settings get global bluetooth_on 2>/dev/null)"
 echo "  ble_scan_always_enabled=$(settings get global ble_scan_always_enabled 2>/dev/null)"
 echo "  wifi_scan_always_enabled=$(settings get global wifi_scan_always_enabled 2>/dev/null)"
 echo "  wifi_scan_throttle_enabled=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)"
 echo "  location_mode=$(settings get secure location_mode 2>/dev/null)"
 echo "  location_background_throttle_interval_ms=$(settings get global location_background_throttle_interval_ms 2>/dev/null)"
 echo
 echo "VPGP³+ / Bluetooth game session:"
 echo "  key=$(cat "$STATE_DIR/vpgp3_session_key" 2>/dev/null)"
 echo "  start_epoch=$(cat "$STATE_DIR/vpgp3_session_start" 2>/dev/null)"
 echo "  last_stale_epoch=$(cat "$STATE_DIR/vpgp3_last_stale" 2>/dev/null)"
 echo
 echo "Bluetooth properties:"
 getprop | grep -iE 'bluetooth|bt\.|a2dp|gabeldorsche' | head -n 80
 echo
 echo "bluetooth_manager summary:"
 dumpsys bluetooth_manager 2>/dev/null | grep -E "enabled:|state:|name:|address:|quiet|callback|profile" | head -n 32
 echo
 echo "Bluetooth processes:"
 echo "  detected_count=$(bt_process_count)"
 ps -A 2>/dev/null | grep -iE 'com\.android\.bluetooth|android\.hardware\.bluetooth|vendor\..*bluetooth' | head -n 24
 echo
 echo "Pokémon GO / Pokemod / VPGP³+ / Bluetooth game package-name checks and appops:"
 seen=""
 for pkg in $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES $BLUETOOTH_GAME_PACKAGE_CANDIDATES; do
   echo " $seen " | grep -q " $pkg " && continue; seen="$seen $pkg"
   inst=no; run=no; package_installed "$pkg" && inst=yes; package_running "$pkg" && run=yes
   [ "$inst" = yes ] || [ "$run" = yes ] || continue
   echo "  $pkg installed=$inst running=$run"
   cmd appops get "$pkg" 2>/dev/null | grep -E "WAKE_LOCK|RUN_ANY|RUN_IN|BLUETOOTH|LOCATION|FOREGROUND|NOTIFICATION|ALARM" | sed 's/^/    /'
 done
 echo
 echo "Android 16/17 companion/bond/permission state:"
dumpsys companiondevice 2>/dev/null | head -160
echo
echo "Role/permission related state:"
dumpsys role 2>/dev/null | head -120
echo
echo "Recent Bluetooth/location/VPGP³+/game logs:"
 logcat -d -t ${LOGCAT_CAPTURE_WINDOW_SECONDS:-180} 2>/dev/null | grep -iE "bluetooth|bt_stack|a2dp|gatt|ble|adapter|hci|companion|cdm|nearby|permission|rpa|privacy|location|gnss|fused|go plus|pokemod|vpgp|lmkd|audio focus" | tail -n ${LOGCAT_CAPTURE_LINES:-80}
} > "$OUT"
cp "$OUT" "$LOCAL_STATUS_FILE" 2>/dev/null
tail -n 80 "$LOG_DIR/bt-stability.log" > "$EXPORT_DIR/log-tail.txt" 2>/dev/null
cp "$LOCAL_USER_CONFIG" "$EXPORT_DIR/user-config.sh" 2>/dev/null
cp "$CONFIG_DIR/install-report.txt" "$EXPORT_DIR/install-report.txt" 2>/dev/null
MODDIR="$MODDIR" sh "$MODDIR/verify.sh" > "$EXPORT_DIR/verification.txt" 2>&1
cp "$CONFIG_DIR/metrics/bluetooth-health.json" "$EXPORT_DIR/bluetooth-health.json" 2>/dev/null
tail -n 60 "$CONFIG_DIR/metrics/recovery-history.jsonl" > "$EXPORT_DIR/recovery-history.jsonl" 2>/dev/null

#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
. "$MODDIR/common/config.sh"
[ -f "$LOCAL_USER_CONFIG" ] && . "$LOCAL_USER_CONFIG"
[ -f "$MODDIR/user-config.sh" ] && . "$MODDIR/user-config.sh"
. "$MODDIR/scripts/lib.sh"
OUT="$EXPORT_DIR/status.txt"
mkdir -p "$EXPORT_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STATE_DIR"
{
 echo "Bluetooth Stability Helper adaptive Bluetooth diagnostics"
 echo "Timestamp: $(date '+%F %T')"
 echo "Version: 0.9.0"
 echo "Profile: adaptive Bluetooth stability engine"
 echo "Config dir: $CONFIG_DIR"
 echo "Brand: $(getprop ro.product.brand)"
 echo "Manufacturer: $(getprop ro.product.manufacturer)"
 echo "Model: $(getprop ro.product.model)"
 echo "Device: $(getprop ro.product.device)"
 echo "Android: $(getprop ro.build.version.release) / SDK $(getprop ro.build.version.sdk)"
 echo "Security patch: $(getprop ro.build.version.security_patch)"
 echo "Build fingerprint: $(getprop ro.build.fingerprint)"
 echo "Zygisk: $(magisk --zygisk 2>/dev/null || echo unknown)"
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
 for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service android.hardware.bluetooth.audio-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do
   if pidof "$name" >/dev/null 2>&1; then echo "  alive: $name"; else echo "  missing: $name"; fi
 done
 echo
 echo "Pokémon GO / Pokemod / VPGP³+ / Bluetooth game packages and appops:"
 seen=""
 for pkg in $POKEMON_GO_PACKAGE_CANDIDATES $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES $BLUETOOTH_GAME_PACKAGE_CANDIDATES; do
   echo " $seen " | grep -q " $pkg " && continue; seen="$seen $pkg"
   inst=no; run=no; package_installed "$pkg" && inst=yes; package_running "$pkg" && run=yes
   [ "$inst" = yes ] || [ "$run" = yes ] || continue
   echo "  $pkg installed=$inst running=$run"
   cmd appops get "$pkg" 2>/dev/null | grep -E "WAKE_LOCK|RUN_ANY|RUN_IN|BLUETOOTH|LOCATION|FOREGROUND|NOTIFICATION|ALARM" | sed 's/^/    /'
 done
 echo
 echo "Recent Bluetooth/location/VPGP³+/game logs:"
 logcat -d -t 260 2>/dev/null | grep -iE "bluetooth|bt_stack|a2dp|gatt|ble|adapter|hci|location|gnss|fused|go plus|pokemod|vpgp" | tail -n 110
} > "$OUT"
cp "$OUT" "$LOCAL_STATUS_FILE" 2>/dev/null
tail -n 160 "$LOG_DIR/bt-stability.log" > "$EXPORT_DIR/log-tail.txt" 2>/dev/null
cp "$LOCAL_USER_CONFIG" "$EXPORT_DIR/user-config.sh" 2>/dev/null

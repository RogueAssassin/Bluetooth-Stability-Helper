#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
. "$MODDIR/common/config.sh"
[ -f "$MODDIR/user-config.sh" ] && . "$MODDIR/user-config.sh"
. "$MODDIR/scripts/lib.sh"
OUT="$EXPORT_DIR/status.txt"
mkdir -p "$EXPORT_DIR"
{
 echo "Bluetooth Stability Helper PRO diagnostics"
 echo "Timestamp: $(date '+%F %T')"
 echo "Version: 0.7.0"
 echo "Mode file: $(cat "$MODDIR/user-mode.txt" 2>/dev/null)"
 echo "Brand: $(getprop ro.product.brand)"
 echo "Manufacturer: $(getprop ro.product.manufacturer)"
 echo "Device: $(getprop ro.product.device)"
 echo "Android: $(getprop ro.build.version.release) / SDK $(getprop ro.build.version.sdk)"
 echo "Zygisk: $(magisk --zygisk 2>/dev/null || echo unknown)"
 echo
 echo "Bluetooth settings:"
 echo "  bluetooth_on=$(settings get global bluetooth_on 2>/dev/null)"
 echo "  ble_scan_always_enabled=$(settings get global ble_scan_always_enabled 2>/dev/null)"
 echo "  wifi_scan_always_enabled=$(settings get global wifi_scan_always_enabled 2>/dev/null)"
 echo "  location_mode=$(settings get secure location_mode 2>/dev/null)"
 echo
 echo "bluetooth_manager summary:"
 dumpsys bluetooth_manager 2>/dev/null | grep -E "enabled:|state:|name:|address:|quiet" | head -n 16
 echo
 echo "Bluetooth processes:"
 for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service android.hardware.bluetooth.audio-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do
   if pidof "$name" >/dev/null 2>&1; then echo "  alive: $name"; else echo "  missing: $name"; fi
 done
 echo
 echo "Pokémon / Pokemod / vPGP3 packages:"
 for pkg in $POKEMON_GO_PACKAGE $POKEMOD_PACKAGE_CANDIDATES $VPGP3_PACKAGE_CANDIDATES; do
   seen=" $seen " ; echo "$seen" | grep -q " $pkg " && continue; seen="$seen $pkg"
   inst=no; run=no; package_installed "$pkg" && inst=yes; package_running "$pkg" && run=yes
   [ "$inst" = yes ] || [ "$run" = yes ] || continue
   echo "  $pkg installed=$inst running=$run"
 done
 echo
 echo "Recent Bluetooth logs:"
 logcat -d -t 120 2>/dev/null | grep -iE "bluetooth|bt_stack|a2dp|gatt|ble|adapter|hci" | tail -n 60
} > "$OUT"
tail -n 100 "$LOG" > "$EXPORT_DIR/log-tail.txt" 2>/dev/null
cp "$MODDIR/user-mode.txt" "$EXPORT_DIR/mode.txt" 2>/dev/null
cp "$MODDIR/user-config.sh" "$EXPORT_DIR/user-config.sh" 2>/dev/null

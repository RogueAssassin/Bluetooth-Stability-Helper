#!/system/bin/sh
MODDIR=${0%/*}
MODEFILE="$MODDIR/user-mode.txt"
USERCFG="$MODDIR/user-config.sh"
EXPORT_DIR="/sdcard/Download/Bluetooth-Stability-Helper/export"
IMPORT_DIR="/sdcard/Download/Bluetooth-Stability-Helper/import"
STATUS_FILE="$EXPORT_DIR/status.txt"
LOG="$MODDIR/bt-stability.log"

mkdir -p "$EXPORT_DIR" "$IMPORT_DIR"
[ -f "$MODEFILE" ] || echo safe > "$MODEFILE"

current_mode() {
  cat "$MODEFILE" 2>/dev/null
}

next_mode() {
  case "$(current_mode)" in
    safe) echo monitor ;;
    monitor) echo recover ;;
    recover) echo pixel_aggressive ;;
    *) echo safe ;;
  esac
}

write_status() {
  {
    echo "Bluetooth Stability Helper status"
    echo "Timestamp: $(date '+%F %T')"
    echo "Mode: $(current_mode)"
    echo "Brand: $(getprop ro.product.brand)"
    echo "Manufacturer: $(getprop ro.product.manufacturer)"
    echo "Device: $(getprop ro.product.device)"
    echo "Android: $(getprop ro.build.version.release)"
    echo "Bluetooth setting: $(settings get global bluetooth_on 2>/dev/null)"
    echo
    echo "bluetooth_manager summary:"
    dumpsys bluetooth_manager 2>/dev/null | grep -E "enabled:|state:|name:|address:" | head -n 12
    echo
    echo "Known process count:"
    count=0
    for name in com.android.bluetooth android.hardware.bluetooth@1.0-service android.hardware.bluetooth-service vendor.qti.bluetooth@1.0-service vendor.bluetooth_service; do
      if pidof "$name" >/dev/null 2>&1; then
        count=$((count+1))
        echo "  alive: $name"
      fi
    done
    echo "  total: $count"
    echo
    echo "Pokemod checker:"
    POKEMOD_PACKAGE_CANDIDATES="dev.pokemod com.pokemod com.pokemod.app com.pokemod.app.public com.pokemod.espresso com.roswell108.pokemodko"
    [ -f "$MODDIR/common/config.sh" ] && . "$MODDIR/common/config.sh"
    [ -f "$USERCFG" ] && . "$USERCFG"
    found_installed=0
    found_running=0
    for pkg in $POKEMOD_PACKAGE_CANDIDATES; do
      if cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; then
        found_installed=1
        echo "  installed: $pkg"
      fi
      if pidof "$pkg" >/dev/null 2>&1 || ps -A 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" || ps 2>/dev/null | awk '{print $9}' | grep -qx "$pkg"; then
        found_running=1
        echo "  running: $pkg"
      fi
    done
    [ "$found_installed" = "0" ] && echo "  installed: not detected from configured candidates"
    [ "$found_running" = "0" ] && echo "  running: not detected from configured candidates"
    echo "  checker enabled: ${POKEMOD_CHECK_ENABLED:-0}"
    echo "  warn only: ${POKEMOD_WARN_ONLY:-1}"
  } > "$STATUS_FILE"
  cp "$MODEFILE" "$EXPORT_DIR/user-mode.txt" 2>/dev/null
  [ -f "$USERCFG" ] && cp "$USERCFG" "$EXPORT_DIR/user-config.sh" 2>/dev/null
  tail -n 60 "$LOG" > "$EXPORT_DIR/log-tail.txt" 2>/dev/null
}

import_bundle_if_present() {
  imported=0
  if [ -f "$IMPORT_DIR/user-mode.txt" ]; then
    cp "$IMPORT_DIR/user-mode.txt" "$MODEFILE"
    chmod 0644 "$MODEFILE"
    imported=1
  fi
  if [ -f "$IMPORT_DIR/user-config.sh" ]; then
    cp "$IMPORT_DIR/user-config.sh" "$USERCFG"
    chmod 0644 "$USERCFG"
    imported=1
  fi
  echo "$imported"
}

CUR="$(current_mode)"
ui_print "Current Mode: $CUR"

IMPORTED="$(import_bundle_if_present)"
if [ "$IMPORTED" = "1" ]; then
  NEWCUR="$(current_mode)"
  ui_print "Import detected and applied."
  ui_print "Imported Mode: $NEWCUR"
  write_status
  ui_print "Exported status bundle to:"
  ui_print "$EXPORT_DIR"
  exit 0
fi

NEW="$(next_mode)"
echo "$NEW" > "$MODEFILE"
ui_print "New Mode: $NEW"
write_status
ui_print "Exported status bundle to:"
ui_print "$EXPORT_DIR"

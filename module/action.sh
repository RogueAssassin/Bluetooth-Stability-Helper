#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common/config.sh"
MODEFILE="$MODDIR/user-mode.txt"
USERCFG="$MODDIR/user-config.sh"
mkdir -p "$EXPORT_DIR" "$IMPORT_DIR"
[ -f "$MODEFILE" ] || echo "$MODE_DEFAULT" > "$MODEFILE"
current_mode() { cat "$MODEFILE" 2>/dev/null; }
next_mode() { case "$(current_mode)" in safe) echo monitor ;; monitor) echo standard ;; standard) echo pokemon ;; pokemon) echo aggressive ;; aggressive) echo diagnostics ;; *) echo safe ;; esac; }
import_bundle_if_present() { imported=0; [ -f "$IMPORT_DIR/mode.txt" ] && cp "$IMPORT_DIR/mode.txt" "$MODEFILE" && imported=1; [ -f "$IMPORT_DIR/user-mode.txt" ] && cp "$IMPORT_DIR/user-mode.txt" "$MODEFILE" && imported=1; [ -f "$IMPORT_DIR/user-config.sh" ] && cp "$IMPORT_DIR/user-config.sh" "$USERCFG" && chmod 0644 "$USERCFG" && imported=1; echo "$imported"; }
ui_print "Bluetooth Stability Helper PRO"
ui_print "Current Mode: $(current_mode)"
if [ "$(import_bundle_if_present)" = 1 ]; then ui_print "Imported config from $IMPORT_DIR"; else NEW=$(next_mode); echo "$NEW" > "$MODEFILE"; ui_print "New Mode: $NEW"; fi
MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
ui_print "Status exported to: $EXPORT_DIR"
ui_print "Tip: edit $CONFIG_DIR/mode.txt to change mode without pressing Action."

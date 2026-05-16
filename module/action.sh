#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common/config.sh"
USERCFG="$LOCAL_USER_CONFIG"
mkdir -p "$EXPORT_DIR" "$IMPORT_DIR" "$LOG_DIR" "$STATE_DIR"
[ -f "$USERCFG" ] || cat > "$USERCFG" <<'EOF'
# Bluetooth Stability Helper local overrides.
# This module now uses one adaptive engine instead of mode cycling.
# Example:
# WATCHDOG_INTERVAL=40
# STALE_SESSION_MINUTES=42
# ENABLE_A2DP_OFFLOAD_DISABLE=1
EOF
import_bundle_if_present() { imported=0; [ -f "$IMPORT_DIR/user-config.sh" ] && cp "$IMPORT_DIR/user-config.sh" "$USERCFG" && chmod 0644 "$USERCFG" && imported=1; echo "$imported"; }
ui_print "Bluetooth Stability Helper v0.9.2"
ui_print "Profile: Adaptive Bluetooth Stability Engine"
ui_print "Focus: Pixel Android 12-16, Pokémon GO, Pokemod VPGP³+, and Bluetooth apps"
if [ "$(import_bundle_if_present)" = 1 ]; then ui_print "Imported config from $IMPORT_DIR"; fi
MODDIR="$MODDIR" sh "$MODDIR/scripts/diagnostics.sh" >/dev/null 2>&1
ui_print "Diagnostics exported to: $EXPORT_DIR"
ui_print "Config file: $USERCFG"
ui_print "Logs: $LOG_DIR/bt-stability.log"

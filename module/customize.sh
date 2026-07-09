#!/system/bin/sh
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true
print_modname() {
  ui_print "*******************************"
  ui_print " Bluetooth Stability Helper    "
  ui_print " v1.0.3 Adaptive Engine        "
  ui_print "*******************************"
  ui_print "Pixel-first Android 12-17 BT/BLE stabiliser."
  ui_print "Pokémon GO + Pokemod VPGP³+ aware."
  ui_print "Does not modify Vector/LSPosed."
}
on_install() {
  ui_print "Installing module files..."
  unzip -o "$ZIPFILE" 'module/*' -d $MODPATH >&2
  mv "$MODPATH/module"/* "$MODPATH"/
  rm -rf "$MODPATH/module"
  [ -f "$MODPATH/user-config.sh" ] || cat > "$MODPATH/user-config.sh" <<'CFG'
#!/system/bin/sh
# User overrides for Bluetooth Stability Helper.
# One adaptive engine is used by default; no mode switching required.
# Example:
# WATCHDOG_INTERVAL=40
# STALE_SESSION_MINUTES=42
# ENABLE_A2DP_OFFLOAD_DISABLE=1
CFG
}
set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/action.sh" 0 0 0755
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
}

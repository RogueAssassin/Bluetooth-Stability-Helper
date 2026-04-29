#!/system/bin/sh
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true
print_modname() {
  ui_print "*******************************"
  ui_print " Bluetooth Stability Helper PRO "
  ui_print " v0.8.1                     "
  ui_print "*******************************"
  ui_print "Magisk-side BT/location stabiliser."
  ui_print "Does not modify Vector/LSPosed."
}
on_install() {
  ui_print "Installing module files..."
  unzip -o "$ZIPFILE" 'module/*' -d $MODPATH >&2
  mv "$MODPATH/module"/* "$MODPATH"/
  rm -rf "$MODPATH/module"
  [ -f "$MODPATH/user-mode.txt" ] || echo standard > "$MODPATH/user-mode.txt"
  [ -f "$MODPATH/user-config.sh" ] || cat > "$MODPATH/user-config.sh" <<'CFG'
#!/system/bin/sh
# User overrides for Bluetooth Stability Helper PRO.
# Modes: safe, monitor, standard, pokemon, pokemonplus, pixel, aggressive, diagnostics
# Example:
# MODE_DEFAULT="pokemonplus"
# ENABLE_A2DP_OFFLOAD_DISABLE=1
# POKEMOD_WARN_ONLY=1
CFG
}
set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/action.sh" 0 0 0755
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
}

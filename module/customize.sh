#!/system/bin/sh
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

print_modname() {
  ui_print "***************************************"
  ui_print " Bluetooth Stability Helper PRO"
  ui_print " v1.1.0 Evidence-Based Recovery"
  ui_print "***************************************"
  ui_print "Adaptive Android Bluetooth/BLE stability"
  ui_print "Pixel-first, with safe multi-OEM detection"
}

on_install() {
  # Support both layouts:
  # 1) GitHub release ZIP with module files at archive root.
  # 2) Source-repository ZIP with module files under module/.
  if unzip -l "$ZIPFILE" 2>/dev/null | grep -q 'module/scripts/install_utils.sh'; then
    unzip -o "$ZIPFILE" 'module/scripts/install_utils.sh' -d "$TMPDIR" >&2
    . "$TMPDIR/module/scripts/install_utils.sh"
    PAYLOAD_LAYOUT="repo"
  elif unzip -l "$ZIPFILE" 2>/dev/null | grep -q 'scripts/install_utils.sh'; then
    unzip -o "$ZIPFILE" 'scripts/install_utils.sh' -d "$TMPDIR" >&2
    . "$TMPDIR/scripts/install_utils.sh"
    PAYLOAD_LAYOUT="release"
  else
    abort "! Installer compatibility helper is missing"
  fi

  bsh_validate_environment
  bsh_print_environment

  ui_print ""
  ui_print "Installing module payload..."
  if [ "$PAYLOAD_LAYOUT" = "repo" ]; then
    unzip -o "$ZIPFILE" 'module/*' -d "$MODPATH" >&2
    mv "$MODPATH/module"/* "$MODPATH"/
    rm -rf "$MODPATH/module"
  else
    unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2
  fi

  bsh_verify_payload
  ui_print ""
  ui_print "Enabled after reboot"
  ui_print "- Bluetooth/BLE/GATT health monitoring"
  ui_print "- Adaptive OEM profile selection"
  ui_print "- Safe staged recovery"
  ui_print "- Pokémon GO and Pokemod VPGP³+ context detection"
  ui_print "- Existing capped event logging"
  ui_print ""
  ui_print "Runtime data: /sdcard/Bluetooth-Stability-Helper/"
  ui_print "This module does not modify apps, LSPosed, Vector,"
  ui_print "Play Integrity, device identity, or user data."
  ui_print "Reboot is required."
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  for f in service.sh action.sh post-fs-data.sh uninstall.sh verify.sh; do
    [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
  done
  set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
}

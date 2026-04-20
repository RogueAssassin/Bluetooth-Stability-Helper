SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

print_modname() {
  ui_print "*******************************"
  ui_print "  Bluetooth Stability Helper  "
  ui_print "        by RogueAssassin      "
  ui_print "*******************************"
}

on_install() {
  ui_print "- Installing module files"
  unzip -o "$ZIPFILE" 'module.prop' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'customize.sh' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'action.sh' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'service.sh' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'post-fs-data.sh' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'uninstall.sh' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'README.md' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'common/*' -d "$MODPATH" >&2

  chmod 0755 "$MODPATH/action.sh"
  chmod 0755 "$MODPATH/service.sh"
  chmod 0755 "$MODPATH/post-fs-data.sh"
  chmod 0755 "$MODPATH/uninstall.sh"
  chmod 0755 "$MODPATH/common/config.sh"
  find "$MODPATH/common/profiles" -type f -name '*.sh' -exec chmod 0755 {} \;
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/action.sh" 0 0 0755
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm "$MODPATH/uninstall.sh" 0 0 0755
}

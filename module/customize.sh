#!/system/bin/sh
# Modern Magisk/KernelSU/APatch installers source this file directly after the
# payload is extracted. Keep the install flow top-level and fail transactionally.
SKIPUNZIP=0

ui_print "***************************************"
ui_print " Bluetooth Stability Helper PRO"
ui_print " v1.2.0 Universal Compatibility"
ui_print "***************************************"
ui_print "Pixel-first evidence-based BT stability"

[ -f "$MODPATH/scripts/install_utils.sh" ] || abort "! Installer helper is missing"
. "$MODPATH/scripts/install_utils.sh"

bsh_validate_environment
bsh_print_environment

ui_print ""
ui_print "Preparing safe installation..."
bsh_copy_upgrade_state
bsh_write_profile_state
bsh_write_install_report
bsh_verify_payload

ui_print ""
ui_print "Applying permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
for file in service.sh action.sh post-fs-data.sh uninstall.sh verify.sh; do
  [ -f "$MODPATH/$file" ] && set_perm "$MODPATH/$file" 0 0 0755
done
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
set_perm_recursive "$MODPATH/common/profiles" 0 0 0755 0755

ui_print ""
ui_print "Installation verified"
ui_print "- Starts only after Android completes booting"
ui_print "- No app, Zygisk, LSPosed/Vector or identity modification"
ui_print "- No vendor property changes in the default profiles"
ui_print "- Existing external user configuration is preserved"
ui_print "- Previous uninstall restoration data was preserved"
ui_print ""
ui_print "After reboot"
ui_print "- Status: /sdcard/Bluetooth-Stability-Helper/status.txt"
ui_print "- Install report: /sdcard/Bluetooth-Stability-Helper/install-report.txt"
ui_print "- Tap the module Action button for diagnostics"
ui_print ""
ui_print "Reboot is required."

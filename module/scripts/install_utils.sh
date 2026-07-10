#!/system/bin/sh

bsh_prop() { getprop "$1" 2>/dev/null; }
bsh_bool_word() { [ "$1" = "1" ] && echo yes || echo no; }

bsh_manager_name() {
  if [ -n "${KSU:-}" ] || [ -d /data/adb/ksu ]; then echo "KernelSU";
  elif [ -n "${APATCH:-}" ] || [ -d /data/adb/ap ]; then echo "APatch";
  else echo "Magisk"; fi
}

bsh_detect_oem() {
  oem="$(bsh_prop ro.product.manufacturer)"
  [ -z "$oem" ] && oem="$(bsh_prop ro.product.brand)"
  [ -z "$oem" ] && oem="Unknown"
  echo "$oem"
}

bsh_detect_profile() {
  brand="$(bsh_prop ro.product.brand | tr '[:upper:]' '[:lower:]')"
  maker="$(bsh_prop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')"
  model="$(bsh_prop ro.product.model | tr '[:upper:]' '[:lower:]')"
  all="$brand $maker $model"
  case "$all" in
    *google*|*pixel*) echo "Google Pixel" ;;
    *samsung*) echo "Samsung One UI" ;;
    *xiaomi*|*redmi*|*poco*) echo "Xiaomi / Redmi / Poco" ;;
    *oneplus*|*oppo*|*realme*) echo "OnePlus / Oppo / Realme" ;;
    *nothing*) echo "Nothing" ;;
    *motorola*) echo "Motorola" ;;
    *) echo "Generic Android" ;;
  esac
}

bsh_android_supported() {
  sdk="$(bsh_prop ro.build.version.sdk)"
  [ -n "$sdk" ] && [ "$sdk" -ge 31 ] && [ "$sdk" -le 37 ]
}

bsh_selinux_mode() {
  if command -v getenforce >/dev/null 2>&1; then getenforce 2>/dev/null; else echo "Unknown"; fi
}

bsh_print_environment() {
  ui_print ""
  ui_print "Device compatibility"
  ui_print "- Root manager: $(bsh_manager_name)"
  ui_print "- Manufacturer: $(bsh_detect_oem)"
  ui_print "- Model: $(bsh_prop ro.product.model)"
  ui_print "- Android: $(bsh_prop ro.build.version.release) (SDK $(bsh_prop ro.build.version.sdk))"
  ui_print "- Build: $(bsh_prop ro.build.id)"
  ui_print "- Security patch: $(bsh_prop ro.build.version.security_patch)"
  ui_print "- Architecture: $(bsh_prop ro.product.cpu.abi)"
  ui_print "- SELinux: $(bsh_selinux_mode)"
  ui_print "- Selected profile: $(bsh_detect_profile)"
}

bsh_validate_environment() {
  if ! bsh_android_supported; then
    ui_print "! Android SDK is outside the tested Android 12-17 range."
    ui_print "! Installation will continue using conservative generic behaviour."
  fi
  [ -n "${MODPATH:-}" ] || abort "! Missing module installation path"
  [ -n "${ZIPFILE:-}" ] || abort "! Missing installer ZIP path"
  return 0
}

bsh_verify_payload() {
  missing=0
  for f in module.prop service.sh post-fs-data.sh action.sh common/config.sh scripts/lib.sh; do
    if [ ! -f "$MODPATH/$f" ]; then
      ui_print "! Missing required module file: $f"
      missing=1
    fi
  done
  [ "$missing" = 0 ] || abort "! Module payload verification failed"

  id="$(sed -n 's/^id=//p' "$MODPATH/module.prop" | head -n1)"
  version="$(sed -n 's/^version=//p' "$MODPATH/module.prop" | head -n1)"
  code="$(sed -n 's/^versionCode=//p' "$MODPATH/module.prop" | head -n1)"
  [ "$id" = "btstabilityhelper" ] || abort "! Unexpected module ID: $id"
  [ -n "$version" ] || abort "! Missing module version"
  [ -n "$code" ] || abort "! Missing module versionCode"
  ui_print "- Payload verified: $id v$version ($code)"
}

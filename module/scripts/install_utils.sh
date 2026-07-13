#!/system/bin/sh

BSH_ID="btstabilityhelper"
BSH_OLD_MODPATH="/data/adb/modules/$BSH_ID"

bsh_prop() { getprop "$1" 2>/dev/null; }
bsh_lc() { tr '[:upper:]' '[:lower:]'; }

bsh_manager_name() {
  if [ -n "${KSU:-}" ] || [ -d /data/adb/ksu ]; then echo "KernelSU"
  elif [ -n "${APATCH:-}" ] || [ -d /data/adb/ap ]; then echo "APatch"
  else echo "Magisk"
  fi
}

bsh_manager_version() {
  case "$(bsh_manager_name)" in
    Magisk)
      ver=$(magisk -v 2>/dev/null); code=$(magisk -V 2>/dev/null)
      echo "${ver:-unknown}${code:+ ($code)}"
      ;;
    KernelSU) echo "${KSU_VER:-${KSU_VERSION:-unknown}}${KSU_VER_CODE:+ ($KSU_VER_CODE)}" ;;
    APatch) echo "${APATCH_VER:-${APATCH_VERSION:-unknown}}${APATCH_VER_CODE:+ ($APATCH_VER_CODE)}" ;;
  esac
}

bsh_detect_oem() {
  oem=$(bsh_prop ro.product.manufacturer)
  [ -n "$oem" ] || oem=$(bsh_prop ro.product.brand)
  echo "${oem:-Unknown}"
}

bsh_detect_oem_profile_id() {
  brand=$(bsh_prop ro.product.brand | bsh_lc)
  maker=$(bsh_prop ro.product.manufacturer | bsh_lc)
  model=$(bsh_prop ro.product.model | bsh_lc)
  all="$brand $maker $model"
  case "$all" in
    *google*|*pixel*) echo pixel ;;
    *samsung*) echo samsung ;;
    *xiaomi*|*redmi*|*poco*) echo xiaomi ;;
    *oneplus*|*oppo*|*realme*) echo oplus ;;
    *nothing*) echo nothing ;;
    *motorola*|*moto\ *) echo motorola ;;
    *asus*|*rog\ phone*) echo asus ;;
    *sony*|*xperia*) echo sony ;;
    *vivo*|*iqoo*) echo vivo ;;
    *huawei*|*honor*) echo huawei ;;
    *) echo generic ;;
  esac
}

bsh_detect_profile_id() {
  if bsh_android_supported; then bsh_detect_oem_profile_id
  else echo unsupported
  fi
}

bsh_profile_label() {
  case "$1" in
    pixel) echo "Google Pixel (primary)" ;;
    samsung) echo "Samsung / One UI (conservative)" ;;
    xiaomi) echo "Xiaomi / Redmi / Poco (conservative)" ;;
    oplus) echo "OnePlus / Oppo / Realme (conservative)" ;;
    nothing) echo "Nothing OS (conservative)" ;;
    motorola) echo "Motorola (conservative)" ;;
    asus) echo "ASUS / ROG (conservative)" ;;
    sony) echo "Sony Xperia (conservative)" ;;
    vivo) echo "Vivo / iQOO (conservative)" ;;
    huawei) echo "Huawei / Honor (diagnostic fallback)" ;;
    unsupported) echo "Unsupported Android (diagnostic fallback)" ;;
    *) echo "Generic Android (safe fallback)" ;;
  esac
}

bsh_detect_soc() {
  maker=$(bsh_prop ro.soc.manufacturer)
  model=$(bsh_prop ro.soc.model)
  board=$(bsh_prop ro.board.platform)
  hardware=$(bsh_prop ro.hardware)
  result="$maker $model"
  [ -n "$(echo "$result" | tr -d ' ')" ] || result="$board $hardware"
  echo "${result:-Unknown}"
}

bsh_bt_stack_summary() {
  manager=no; package=no; aidl=no; hidl=no
  service list 2>/dev/null | grep -qi bluetooth_manager && manager=yes
  (cmd package path com.android.bluetooth 2>/dev/null || pm path com.android.bluetooth 2>/dev/null) | grep -q . && package=yes
  service list 2>/dev/null | grep -qi 'android.hardware.bluetooth.IBluetoothHci' && aidl=yes
  ps -A 2>/dev/null | grep -q 'android.hardware.bluetooth@' && hidl=yes
  echo "manager=$manager package=$package aidl=$aidl legacy_hidl=$hidl"
}

bsh_package_state() {
  pkg="$1"
  if cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; then echo installed
  else echo not-installed
  fi
}

bsh_android_supported() {
  sdk=$(bsh_prop ro.build.version.sdk)
  case "$sdk" in ''|*[!0-9]*) return 1 ;; esac
  [ "$sdk" -ge 31 ] && [ "$sdk" -le 37 ]
}

bsh_selinux_mode() {
  if command -v getenforce >/dev/null 2>&1; then getenforce 2>/dev/null
  else echo Unknown
  fi
}

bsh_install_mode() {
  new_version=$(sed -n 's/^version=//p' "$MODPATH/module.prop" 2>/dev/null | head -n1)
  old_version=""
  if [ "$BSH_OLD_MODPATH" != "$MODPATH" ] && [ -f "$BSH_OLD_MODPATH/module.prop" ]; then
    old_version=$(sed -n 's/^version=//p' "$BSH_OLD_MODPATH/module.prop" | head -n1)
  fi
  if [ -n "$old_version" ]; then echo "upgrade $old_version -> $new_version"
  else echo "clean install $new_version"
  fi
}

bsh_validate_environment() {
  [ -n "${MODPATH:-}" ] || abort "! Missing module installation path"
  [ -n "${ZIPFILE:-}" ] || abort "! Missing installer ZIP path"
  [ -f "$MODPATH/module.prop" ] || abort "! module.prop was not extracted"
  if ! bsh_android_supported; then
    ui_print "! Android SDK is outside the validated Android 12-17 range."
    ui_print "! Safe generic diagnostics will be used; vendor tuning is disabled."
  fi
}

bsh_copy_upgrade_state() {
  [ "$BSH_OLD_MODPATH" != "$MODPATH" ] || return 0
  [ -d "$BSH_OLD_MODPATH/state" ] || return 0
  mkdir -p "$MODPATH/state"
  for file in original-global-settings.txt original-properties.txt added-idle-whitelist.txt; do
    [ -f "$BSH_OLD_MODPATH/state/$file" ] && cp -p "$BSH_OLD_MODPATH/state/$file" "$MODPATH/state/$file"
  done
}

bsh_write_profile_state() {
  profile=$(bsh_detect_profile_id)
  mkdir -p "$MODPATH/state"
  {
    echo "PROFILE_ID=$profile"
    echo "PROFILE_LABEL=$(bsh_profile_label "$profile")"
    echo "DETECTED_OEM=$(bsh_detect_oem)"
    echo "DETECTED_MODEL=$(bsh_prop ro.product.model)"
    echo "DETECTED_SDK=$(bsh_prop ro.build.version.sdk)"
    echo "DETECTED_BUILD=$(bsh_prop ro.build.id)"
    echo "DETECTED_ROOT_MANAGER=$(bsh_manager_name)"
  } > "$MODPATH/state/install-profile.txt"
}

bsh_write_install_report() {
  version=$(sed -n 's/^version=//p' "$MODPATH/module.prop" | head -n1)
  profile=$(bsh_detect_profile_id)
  mkdir -p "$MODPATH/state"
  {
    echo "Bluetooth Stability Helper installation report"
    echo "Version: $version"
    echo "Install mode: $(bsh_install_mode)"
    echo "Timestamp: $(date '+%F %T')"
    echo "Root manager: $(bsh_manager_name) $(bsh_manager_version)"
    echo "Boot-mode install: ${BOOTMODE:-unknown}"
    echo "Device: $(bsh_detect_oem) $(bsh_prop ro.product.model)"
    echo "Profile: $(bsh_profile_label "$profile")"
    echo "SoC: $(bsh_detect_soc)"
    echo "Android: $(bsh_prop ro.build.version.release) / SDK $(bsh_prop ro.build.version.sdk)"
    echo "Build: $(bsh_prop ro.build.id)"
    echo "Security patch: $(bsh_prop ro.build.version.security_patch)"
    echo "Architecture: $(bsh_prop ro.product.cpu.abi)"
    echo "SELinux: $(bsh_selinux_mode)"
    echo "Bluetooth stack: $(bsh_bt_stack_summary)"
    echo "Pokemon GO: $(bsh_package_state com.nianticlabs.pokemongo)"
    echo "Pokemod: $(bsh_package_state com.pokemod.app.public)"
  } > "$MODPATH/state/install-report.txt"
}

bsh_print_environment() {
  profile=$(bsh_detect_profile_id)
  ui_print ""
  ui_print "Installation"
  ui_print "- Mode: $(bsh_install_mode)"
  ui_print "- Root: $(bsh_manager_name) $(bsh_manager_version)"
  ui_print "- App install mode: ${BOOTMODE:-unknown}"
  ui_print ""
  ui_print "Detected device"
  ui_print "- Device: $(bsh_detect_oem) $(bsh_prop ro.product.model)"
  ui_print "- Android: $(bsh_prop ro.build.version.release) (SDK $(bsh_prop ro.build.version.sdk))"
  ui_print "- Build: $(bsh_prop ro.build.id)"
  ui_print "- Patch: $(bsh_prop ro.build.version.security_patch)"
  ui_print "- SoC: $(bsh_detect_soc)"
  ui_print "- ABI: $(bsh_prop ro.product.cpu.abi)"
  ui_print "- SELinux: $(bsh_selinux_mode)"
  ui_print "- Bluetooth: $(bsh_bt_stack_summary)"
  ui_print ""
  ui_print "Selected profile"
  ui_print "- $(bsh_profile_label "$profile")"
  case "$profile" in
    pixel)
      ui_print "- Pixel evidence threshold: 2 faults / 3 minutes"
      ui_print "- Recovery limit: 2 per hour / 10-minute cooldown"
      ;;
    huawei|unsupported)
      ui_print "- Diagnostics-first; automatic adapter recovery disabled"
      ;;
    *)
      ui_print "- Conservative threshold: 3 faults / 4 minutes"
      ui_print "- Recovery limit: 1 per hour / 15-minute cooldown"
      ;;
  esac
  ui_print "- Pokemon GO: $(bsh_package_state com.nianticlabs.pokemongo)"
  ui_print "- Pokemod: $(bsh_package_state com.pokemod.app.public)"
}

bsh_verify_payload() {
  missing=0
  for file in module.prop service.sh post-fs-data.sh action.sh uninstall.sh verify.sh common/config.sh scripts/lib.sh scripts/diagnostics.sh scripts/install_utils.sh; do
    if [ ! -f "$MODPATH/$file" ]; then
      ui_print "! Missing required file: $file"
      missing=1
    fi
  done
  [ "$missing" = 0 ] || abort "! Module payload verification failed"

  id=$(sed -n 's/^id=//p' "$MODPATH/module.prop" | head -n1)
  version=$(sed -n 's/^version=//p' "$MODPATH/module.prop" | head -n1)
  code=$(sed -n 's/^versionCode=//p' "$MODPATH/module.prop" | head -n1)
  [ "$id" = "$BSH_ID" ] || abort "! Unexpected module ID: $id"
  [ -n "$version" ] || abort "! Missing module version"
  case "$code" in ''|*[!0-9]*) abort "! Invalid module versionCode: $code" ;; esac

  for file in "$MODPATH"/*.sh "$MODPATH"/scripts/*.sh "$MODPATH"/common/*.sh "$MODPATH"/common/profiles/*.sh; do
    sh -n "$file" >/dev/null 2>&1 || abort "! Shell validation failed: ${file#$MODPATH/}"
  done
  ui_print "- Payload and shell syntax verified: $id v$version ($code)"
}

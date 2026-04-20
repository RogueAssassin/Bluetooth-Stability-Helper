#!/system/bin/sh
apply_profile_generic() {
  log "Applying generic profile"
  [ "$ENABLE_BLE_SCAN_ALWAYS" = "1" ] && settings put global ble_scan_always_enabled 1
  [ "$ENABLE_WIFI_SCAN_THROTTLE_OFF" = "1" ] && settings put global wifi_scan_throttle_enabled 0
  [ "$ENABLE_LOCATION_BG_THROTTLE_OFF" = "1" ] && settings put global location_background_throttle_interval_ms 0

  if [ "$ENABLE_DEVICE_IDLE_TUNING" = "1" ]; then
    settings put global device_idle_constants "$DEVICE_IDLE_CONSTANTS"
    log "Applied device idle constants"
  fi
}

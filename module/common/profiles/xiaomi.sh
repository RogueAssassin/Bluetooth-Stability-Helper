#!/system/bin/sh

apply_profile_xiaomi() {
  apply_profile_generic_defaults
  PROFILE_ID="xiaomi"
  PROFILE_LABEL="Xiaomi Redmi Poco conservative"
  log "Device profile: $PROFILE_LABEL"
}

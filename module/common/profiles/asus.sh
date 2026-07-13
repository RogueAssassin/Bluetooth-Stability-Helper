#!/system/bin/sh

apply_profile_asus() {
  apply_profile_generic_defaults
  PROFILE_ID="asus"
  PROFILE_LABEL="ASUS ROG conservative"
  log "Device profile: $PROFILE_LABEL"
}

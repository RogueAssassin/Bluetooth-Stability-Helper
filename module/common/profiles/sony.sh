#!/system/bin/sh

apply_profile_sony() {
  apply_profile_generic_defaults
  PROFILE_ID="sony"
  PROFILE_LABEL="Sony Xperia conservative"
  log "Device profile: $PROFILE_LABEL"
}

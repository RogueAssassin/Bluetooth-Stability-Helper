#!/system/bin/sh

apply_profile_motorola() {
  apply_profile_generic_defaults
  PROFILE_ID="motorola"
  PROFILE_LABEL="Motorola conservative"
  log "Device profile: $PROFILE_LABEL"
}

#!/system/bin/sh

apply_profile_nothing() {
  apply_profile_generic_defaults
  PROFILE_ID="nothing"
  PROFILE_LABEL="Nothing OS conservative"
  log "Device profile: $PROFILE_LABEL"
}

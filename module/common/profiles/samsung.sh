#!/system/bin/sh

apply_profile_samsung() {
  apply_profile_generic_defaults
  PROFILE_ID="samsung"
  PROFILE_LABEL="Samsung One UI conservative"
  log "Device profile: $PROFILE_LABEL"
}

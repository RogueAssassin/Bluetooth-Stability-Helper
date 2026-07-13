#!/system/bin/sh

apply_profile_vivo() {
  apply_profile_generic_defaults
  PROFILE_ID="vivo"
  PROFILE_LABEL="Vivo iQOO conservative"
  log "Device profile: $PROFILE_LABEL"
}

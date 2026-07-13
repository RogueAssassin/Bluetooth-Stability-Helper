#!/system/bin/sh

apply_profile_huawei() {
  apply_profile_generic_defaults
  PROFILE_ID="huawei"
  PROFILE_LABEL="Huawei Honor diagnostic fallback"
  ENABLE_ADAPTER_TOGGLE_RECOVERY=0
  APPLY_RESTRICTED_STANDBY_FIXES=0
  log "Device profile: $PROFILE_LABEL; automatic adapter recovery disabled"
}

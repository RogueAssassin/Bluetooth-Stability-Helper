package com.rogueassassin.bsh

import org.json.JSONObject

data class BshSettings(
    val watchdogEnabled:String, val watchdogInterval:String, val failureThreshold:String,
    val failureWindowSeconds:String, val recoveryCooldown:String, val maxRestartsPerHour:String,
    val adapterRecovery:String, val interactionFreezeGuard:String, val staleSessionMinutes:String,
    val bleScanAlways:String, val locationMode:String
)

data class BshStatus(
    val schema:Int, val timestamp:String, val epoch:Long, val moduleVersion:String,
    val serviceState:String, val serviceStartEpoch:Long, val serviceUptimeSeconds:Long,
    val rootProvider:String, val zygisk:String, val profile:String, val healthScore:Int,
    val recoveryState:String, val lastFaultType:String, val lastRecoveryOutcome:String,
    val bluetoothEnabled:String, val bluetoothProcessCount:String, val heartbeatAgeSeconds:Long,
    val androidSdk:String, val androidRelease:String, val brand:String, val manufacturer:String,
    val model:String, val device:String, val buildId:String, val buildFingerprint:String,
    val securityPatch:String, val activePokemonGo:String, val activePokemod:String,
    val settings:BshSettings
) {
 companion object {
  fun parse(raw:String):BshStatus {
   val j=JSONObject(raw); val s=j.optJSONObject("settings") ?: JSONObject()
   return BshStatus(
    j.optInt("schema",0),j.optString("timestamp","unknown"),j.optLong("epoch",0),j.optString("module_version","unknown"),
    j.optString("service_state","UNKNOWN"),j.optLong("service_start_epoch",0),j.optLong("service_uptime_seconds",0),
    j.optString("root_provider","unknown"),j.optString("zygisk","unknown"),j.optString("profile","unknown"),j.optInt("health_score",0),
    j.optString("recovery_state","UNKNOWN"),j.optString("last_fault_type","none"),j.optString("last_recovery_outcome","none"),
    j.optString("bluetooth_enabled","unknown"),j.optString("bluetooth_process_count","unknown"),j.optLong("watchdog_heartbeat_age_seconds",-1),
    j.optString("android_sdk","unknown"),j.optString("android_release","unknown"),j.optString("brand","unknown"),j.optString("manufacturer","unknown"),
    j.optString("model","unknown"),j.optString("device","unknown"),j.optString("build_id","unknown"),j.optString("build_fingerprint","unknown"),
    j.optString("security_patch","unknown"),j.optString("active_pokemon_go","none"),j.optString("active_pokemod_vpgp3","none"),
    BshSettings(s.optString("watchdog_enabled","unknown"),s.optString("watchdog_interval","unknown"),s.optString("failure_threshold","unknown"),
     s.optString("failure_window_seconds","unknown"),s.optString("recovery_cooldown","unknown"),s.optString("max_restarts_per_hour","unknown"),
     s.optString("adapter_toggle_recovery","unknown"),s.optString("interaction_freeze_guard","unknown"),s.optString("stale_session_minutes","unknown"),
     s.optString("ble_scan_always_enabled","unknown"),s.optString("location_mode","unknown"))
   )
  }
 }
}

data class BshEvent(val epoch:Long,val timestamp:String,val type:String,val severity:String,val source:String,val message:String,val action:String,val outcome:String) {
 companion object { fun parse(line:String):BshEvent?=runCatching { val j=JSONObject(line); BshEvent(j.optLong("epoch",0),j.optString("timestamp",""),j.optString("type","event"),j.optString("severity","info"),j.optString("source","engine"),j.optString("message",""),j.optString("action",""),j.optString("outcome","")) }.getOrNull() }
}
data class ModuleInfo(val detected:Boolean,val version:String,val enabled:Boolean)
data class CompanionSnapshot(val rootAvailable:Boolean,val rootProvider:String,val module:ModuleInfo,val status:BshStatus?,val apiSource:String,val events:List<BshEvent>,val error:String?)

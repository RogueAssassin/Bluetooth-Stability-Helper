package com.rogueassassin.bsh

import org.json.JSONObject

data class BshStatus(
    val schema: Int, val timestamp: String, val moduleVersion: String, val profile: String,
    val healthScore: Int, val recoveryState: String, val lastFaultType: String,
    val lastRecoveryOutcome: String, val bluetoothEnabled: String, val bluetoothProcessCount: String,
    val heartbeatAgeSeconds: Long, val androidSdk: String, val buildId: String,
    val securityPatch: String, val activePokemonGo: String, val activePokemod: String
) {
    companion object {
        fun parse(raw: String): BshStatus {
            val j = JSONObject(raw)
            return BshStatus(
                j.optInt("schema", 0), j.optString("timestamp", "unknown"),
                j.optString("module_version", "unknown"), j.optString("profile", "unknown"),
                j.optInt("health_score", 0), j.optString("recovery_state", "UNKNOWN"),
                j.optString("last_fault_type", "none"), j.optString("last_recovery_outcome", "none"),
                j.optString("bluetooth_enabled", "unknown"), j.optString("bluetooth_process_count", "unknown"),
                j.optLong("watchdog_heartbeat_age_seconds", -1), j.optString("android_sdk", "unknown"),
                j.optString("build_id", "unknown"), j.optString("security_patch", "unknown"),
                j.optString("active_pokemon_go", "none"), j.optString("active_pokemod_vpgp3", "none")
            )
        }
    }
}

data class BshEvent(
    val epoch: Long, val timestamp: String, val type: String, val severity: String,
    val source: String, val message: String, val action: String, val outcome: String
) {
    companion object {
        fun parse(line: String): BshEvent? = runCatching {
            val j = JSONObject(line)
            BshEvent(
                j.optLong("epoch", 0), j.optString("timestamp", ""), j.optString("type", "event"),
                j.optString("severity", "info"), j.optString("source", "engine"),
                j.optString("message", ""), j.optString("action", ""), j.optString("outcome", "")
            )
        }.getOrNull()
    }
}

data class CompanionSnapshot(
    val rootAvailable: Boolean, val status: BshStatus?, val events: List<BshEvent>, val error: String?
)

package com.rogueassassin.bsh

object BshRepository {
    private const val MODULE_PROP = "/data/adb/modules/btstabilityhelper/module.prop"
    private const val MODULE_DISABLE = "/data/adb/modules/btstabilityhelper/disable"
    private const val PRIVATE_STATUS = "/data/adb/modules/btstabilityhelper/runtime/api/status.json"
    private const val EXTERNAL_STATUS = "/sdcard/Bluetooth-Stability-Helper/api/status.json"
    private const val EVENTS = "/sdcard/Bluetooth-Stability-Helper/metrics/events.jsonl"

    fun load(): CompanionSnapshot {
        if (!RootBridge.rootAvailable()) {
            return CompanionSnapshot(false, "Unavailable", ModuleInfo(false, "unknown", false), null, "none", emptyList(), "Root access was not granted.")
        }

        val moduleProp = RootBridge.read(MODULE_PROP).getOrNull()
        val module = if (moduleProp != null) {
            ModuleInfo(true, property(moduleProp, "version") ?: "unknown", !RootBridge.exists(MODULE_DISABLE))
        } else {
            ModuleInfo(false, "unknown", false)
        }

        if (!module.detected) {
            return CompanionSnapshot(
                true, RootBridge.rootProvider(), module, null, "none", emptyList(),
                "Bluetooth Stability Helper module was not found under /data/adb/modules."
            )
        }

        val candidates = listOf(
            PRIVATE_STATUS to "Private module API",
            EXTERNAL_STATUS to "Shared-storage mirror"
        )

        var status: BshStatus? = null
        var source = "none"
        var parseError: String? = null
        for ((path, label) in candidates) {
            val raw = RootBridge.read(path).getOrNull() ?: continue
            val parsed = runCatching { BshStatus.parse(raw) }
            if (parsed.isSuccess) {
                status = parsed.getOrNull()
                source = label
                break
            }
            parseError = "Found " + label + " but could not parse its status snapshot."
        }

        val events = RootBridge.tail(EVENTS, 150).getOrDefault("")
            .lineSequence().filter { it.isNotBlank() }
            .mapNotNull(BshEvent::parse).sortedByDescending { it.epoch }.toList()

        val error = when {
            status == null && parseError != null -> parseError
            status == null -> "Module detected, but no manager API snapshot exists yet. Use the Magisk Action once or reboot to regenerate it."
            !module.enabled -> "The module is installed but currently disabled in the root manager."
            status.schema !in 1..2 -> "Unsupported manager API schema: " + status.schema
            else -> null
        }

        return CompanionSnapshot(true, RootBridge.rootProvider(), module, status, source, events, error)
    }

    private fun property(raw: String, key: String): String? =
        raw.lineSequence().firstOrNull { it.startsWith(key + "=") }?.substringAfter("=")?.trim()
}

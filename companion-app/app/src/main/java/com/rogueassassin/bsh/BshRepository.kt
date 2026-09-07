package com.rogueassassin.bsh

object BshRepository {
    private const val STATUS = "/sdcard/Bluetooth-Stability-Helper/api/status.json"
    private const val EVENTS = "/sdcard/Bluetooth-Stability-Helper/metrics/events.jsonl"

    fun load(): CompanionSnapshot {
        if (!RootBridge.rootAvailable()) {
            return CompanionSnapshot(false, null, emptyList(), "Root access was not granted or no su provider is available.")
        }
        val raw = RootBridge.read(STATUS).getOrElse {
            return CompanionSnapshot(true, null, emptyList(), "Bluetooth Stability Helper API is unavailable. Enable the module and reboot.")
        }
        val status = runCatching { BshStatus.parse(raw) }.getOrElse {
            return CompanionSnapshot(true, null, emptyList(), "Unable to parse manager API status.json.")
        }
        val events = RootBridge.tail(EVENTS, 100).getOrDefault("").lineSequence()
            .filter { it.isNotBlank() }.mapNotNull(BshEvent::parse).sortedByDescending { it.epoch }.toList()
        val error = if (status.schema == 1) null else "Unsupported manager API schema: " + status.schema
        return CompanionSnapshot(true, status, events, error)
    }
}

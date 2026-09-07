package com.rogueassassin.bsh

import java.io.IOException

object RootBridge {
    private val allowedRoots = listOf(
        "/data/adb/modules/btstabilityhelper",
        "/data/adb/modules_update/btstabilityhelper",
        "/sdcard/Bluetooth-Stability-Helper"
    )

    fun read(path: String): Result<String> {
        if (!allowed(path)) return Result.failure(SecurityException("Path outside BSH runtime"))
        return runCatching { runRoot("cat " + quote(path)) }
    }

    fun tail(path: String, lines: Int): Result<String> {
        if (!allowed(path)) return Result.failure(SecurityException("Path outside BSH runtime"))
        return runCatching { runRoot("tail -n " + lines.coerceIn(1, 500) + " " + quote(path)) }
    }

    fun exists(path: String): Boolean {
        if (!allowed(path)) return false
        return runCatching { runRoot("[ -e " + quote(path) + " ] && echo yes || echo no").trim() == "yes" }
            .getOrDefault(false)
    }

    fun rootAvailable(): Boolean = runCatching { runRoot("id").contains("uid=0") }.getOrDefault(false)

    fun rootProvider(): String = runCatching {
        runRoot("command -v magisk >/dev/null 2>&1 && echo Magisk || (command -v ksud >/dev/null 2>&1 && echo KernelSU || echo Root)")
            .trim().ifBlank { "Root" }
    }.getOrDefault("Unknown")

    private fun allowed(path: String) = allowedRoots.any { path == it || path.startsWith(it + "/") }

    private fun runRoot(command: String): String {
        val process = ProcessBuilder("su", "-c", command).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().use { it.readText() }
        val code = process.waitFor()
        if (code != 0) throw IOException(output.trim().ifBlank { "Root command failed (" + code + ")" })
        return output
    }

    private fun quote(value: String) = "'" + value.replace("'", "'\\''") + "'"
}

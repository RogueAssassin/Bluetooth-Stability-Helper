package com.rogueassassin.bsh

import java.io.IOException

object RootBridge {
    private const val BASE = "/sdcard/Bluetooth-Stability-Helper"

    fun read(path: String): Result<String> {
        if (!path.startsWith(BASE)) return Result.failure(SecurityException("Path outside BSH runtime"))
        return runCatching { runRoot("cat " + quote(path)) }
    }

    fun tail(path: String, lines: Int): Result<String> {
        if (!path.startsWith(BASE)) return Result.failure(SecurityException("Path outside BSH runtime"))
        return runCatching { runRoot("tail -n " + lines.coerceIn(1, 500) + " " + quote(path)) }
    }

    fun rootAvailable(): Boolean = runCatching { runRoot("id").contains("uid=0") }.getOrDefault(false)

    private fun runRoot(command: String): String {
        val process = ProcessBuilder("su", "-c", command).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().use { it.readText() }
        val code = process.waitFor()
        if (code != 0) throw IOException(output.trim().ifBlank { "Root command failed" })
        return output
    }

    private fun quote(value: String) = "'" + value.replace("'", "'\\''") + "'"
}

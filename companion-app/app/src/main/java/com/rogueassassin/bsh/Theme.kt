package com.rogueassassin.bsh

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

// Rogue brand fallback palette, used only if a device cannot provide Material You
// dynamic color. minSdk is 31, so in practice dynamic color is always available;
// these keep the app coherent in previews and on any non-dynamic surface.
private val BrandCyan = Color(0xFF00D7F2)
private val BrandPurple = Color(0xFF8B5CF6)

private val FallbackDark = darkColorScheme(
    primary = BrandCyan,
    secondary = BrandPurple,
    background = Color(0xFF090B10),
    surface = Color(0xFF141821),
    surfaceVariant = Color(0xFF1B202B),
    onSurfaceVariant = Color(0xFF9AA5B4),
)

private val FallbackLight = lightColorScheme(
    primary = Color(0xFF006877),
    secondary = BrandPurple,
    background = Color(0xFFF6F8FB),
    surface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFFE3E8F0),
    onSurfaceVariant = Color(0xFF55606E),
)

// Semantic status colors for the health ring / grading. These stay constant
// across light and dark (like a battery indicator) so a score always reads the
// same way regardless of the device accent.
object Status {
    val good = Color(0xFF2BD672)
    val ok = Color(0xFF00C2DB)
    val warn = Color(0xFFF2A33C)
    val bad = Color(0xFFF2516B)
}

@Composable
fun BshTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val scheme = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        dark -> FallbackDark
        else -> FallbackLight
    }
    MaterialTheme(colorScheme = scheme, content = content)
}

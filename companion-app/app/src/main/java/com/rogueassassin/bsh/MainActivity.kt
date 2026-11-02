package com.rogueassassin.bsh

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { BshTheme { BshApp() } }
    }
}

private fun scoreColor(score: Int): Color = when {
    score >= 85 -> Status.good
    score >= 65 -> Status.ok
    score >= 40 -> Status.warn
    else -> Status.bad
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BshApp() {
    var tab by remember { mutableIntStateOf(0) }
    var refresh by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var snapshot by remember { mutableStateOf<CompanionSnapshot?>(null) }

    LaunchedEffect(refresh) {
        loading = true
        snapshot = withContext(Dispatchers.IO) { BshRepository.load() }
        loading = false
    }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            refresh++
        }
    }

    val labels = listOf("Overview", "Activity", "Device", "Support")
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Bluetooth Stability Helper", fontWeight = FontWeight.SemiBold) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        },
        bottomBar = {
            NavigationBar {
                labels.forEachIndexed { index, label ->
                    NavigationBarItem(
                        selected = tab == index,
                        onClick = { tab = index },
                        icon = { NavGlyph(index, tab == index) },
                        label = { Text(label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                loading -> CenterMessage("Reading Bluetooth Stability Helper…")
                snapshot == null -> CenterMessage("Unable to load companion state.")
                tab == 0 -> Overview(snapshot!!) { refresh++ }
                tab == 1 -> Activity(snapshot!!)
                tab == 2 -> Device(snapshot!!)
                else -> Support(snapshot!!) { refresh++ }
            }
        }
    }
}

@Composable
private fun Overview(snapshot: CompanionSnapshot, onRefresh: () -> Unit) {
    val s = snapshot.status
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { Spacer(Modifier.height(4.dp)) }
        item { StatusStrip(snapshot.module.detected && snapshot.module.enabled, s != null, snapshot.rootAvailable) }
        snapshot.error?.let { item { WarningCard(it) } }

        if (s != null) {
            item { HeroHealthCard(s) }
            snapshot.health?.let { h -> if (h.components.any { it.second > 0 }) item { ComponentCard(h) } }
            s.acl?.let { item { AclCard(it) } }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("Bluetooth", if (s.bluetoothEnabled == "1") "On" else s.bluetoothEnabled, Modifier.weight(1f))
                    SmallMetric("Heartbeat", heartbeat(s.heartbeatAgeSeconds), Modifier.weight(1f))
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("BT services", s.bluetoothProcessCount, Modifier.weight(1f))
                    SmallMetric("API schema", "v" + s.schema, Modifier.weight(1f))
                }
            }
            item { InfoCard("Last fault", friendlyNone(s.lastFaultType)) }
            item { InfoCard("Last recovery", friendlyNone(s.lastRecoveryOutcome)) }
        } else if (snapshot.module.detected) {
            item { InfoCard("Module detected", "v" + snapshot.module.version) }
            item { InfoCard("Manager API", "Waiting for first snapshot") }
        }

        item { Button(onClick = onRefresh, Modifier.fillMaxWidth()) { Text("Refresh now") } }
        item { Spacer(Modifier.height(8.dp)) }
    }
}

@Composable
private fun HeroHealthCard(s: BshStatus) {
    val color = scoreColor(s.healthScore)
    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(116.dp), contentAlignment = Alignment.Center) {
                HealthRing(s.healthScore, color, MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.16f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        s.healthScore.toString(),
                        color = color,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text("HEALTH", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall)
                }
            }
            Column(Modifier.padding(start = 20.dp)) {
                Text(
                    s.recoveryState.replace('_', ' '),
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(Modifier.height(6.dp))
                Chip(s.profile, MaterialTheme.colorScheme.primary)
                Text(
                    "Adaptive recovery status",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun HealthRing(score: Int, ringColor: Color, trackColor: Color) {
    val sweep by animateFloatAsState(
        targetValue = 360f * (score.coerceIn(0, 100) / 100f),
        label = "healthRing"
    )
    Canvas(Modifier.size(116.dp).padding(6.dp)) {
        val strokeW = 13.dp.toPx()
        val inset = strokeW / 2f
        val arc = Size(size.width - strokeW, size.height - strokeW)
        drawArc(trackColor, 0f, 360f, false, topLeft = Offset(inset, inset), size = arc, style = Stroke(strokeW, cap = StrokeCap.Round))
        drawArc(ringColor, -90f, sweep, false, topLeft = Offset(inset, inset), size = arc, style = Stroke(strokeW, cap = StrokeCap.Round))
    }
}

@Composable
private fun ComponentCard(h: BshHealth) {
    Card(shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text("Why this score", fontWeight = FontWeight.SemiBold)
            Text(
                "Points deducted per signal",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            h.components.filter { it.second > 0 }.sortedByDescending { it.second }.forEach { (name, penalty) ->
                ComponentBar(componentLabel(name), penalty)
            }
        }
    }
}

@Composable
private fun ComponentBar(label: String, penalty: Int) {
    val fraction = (penalty / 35f).coerceIn(0f, 1f)
    Column(Modifier.padding(top = 10.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            Text("-$penalty", color = Status.warn, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
        Box(
            Modifier.fillMaxWidth().padding(top = 4.dp).height(6.dp)
                .clip(RoundedCornerShape(3.dp)).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.14f))
        ) {
            Box(
                Modifier.fillMaxWidth(fraction).height(6.dp)
                    .clip(RoundedCornerShape(3.dp)).background(Status.warn)
            )
        }
    }
}

@Composable
private fun AclCard(acl: BshAcl) {
    val count = acl.abnormalWindowCount
    val threshold = acl.threshold.toIntOrNull() ?: 4
    val color = when {
        count >= threshold -> Status.bad
        count > 0 -> Status.warn
        else -> Status.good
    }
    Card(shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Link stability (ACL)", fontWeight = FontWeight.SemiBold)
                Text("$count / $threshold", color = color, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            }
            Text(
                "Abnormal disconnects in the last " + acl.windowSeconds + "s",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 2.dp)
            )
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Chip(if (acl.guardEnabled == "1") "Guard on" else "Guard off", if (acl.guardEnabled == "1") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                Chip(if (acl.recoveryEnabled == "1") "Auto-recover" else "Observe-only", if (acl.recoveryEnabled == "1") Status.ok else MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (acl.abnormalReasons.isNotBlank()) {
                Text(
                    "Reason codes watched: " + acl.abnormalReasons,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 10.dp)
                )
            }
        }
    }
}

@Composable
private fun Activity(snapshot: CompanionSnapshot) {
    if (snapshot.events.isEmpty()) {
        CenterMessage("No recent fault or recovery events have been recorded.")
        return
    }
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { SectionHeader("Activity", "Newest bounded engine events") }
        items(snapshot.events) { event ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(event.type.replace('_', ' '), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                        SeverityPill(event.severity)
                    }
                    if (event.message.isNotBlank()) Text(event.message, Modifier.padding(top = 7.dp))
                    if (event.action.isNotBlank() || event.outcome.isNotBlank()) {
                        Text(
                            listOf(event.action, event.outcome).filter { it.isNotBlank() }.joinToString(" • "),
                            color = Status.good,
                            modifier = Modifier.padding(top = 6.dp)
                        )
                    }
                    Text(
                        event.timestamp + " • " + event.source,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 9.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun Device(snapshot: CompanionSnapshot) {
    val s = snapshot.status
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SectionHeader("Device", "Detected platform and module profile") }
        item { InfoCard("Module", if (snapshot.module.detected) "v" + snapshot.module.version else "Not detected") }
        item { InfoCard("Module state", if (snapshot.module.enabled) "Enabled" else "Disabled / unavailable") }
        item { InfoCard("Profile", s?.profile ?: "Waiting for API") }
        item { InfoCard("Service", s?.let { it.serviceState + " • uptime " + formatUptime(it.serviceUptimeSeconds) } ?: "Waiting for API") }
        item { InfoCard("Root environment", s?.let { it.rootProvider + " • Zygisk " + it.zygisk } ?: snapshot.rootProvider) }
        item { InfoCard("Manufacturer", s?.manufacturer ?: "Waiting for API") }
        item { InfoCard("Brand / model", s?.let { it.brand + " / " + it.model } ?: "Waiting for API") }
        item { InfoCard("Device", s?.device ?: "Waiting for API") }
        if (s != null && s.pixelGeneration != "0") {
            item { InfoCard("Pixel generation", "Gen " + s.pixelGeneration + " • " + s.pixelSocEra.replace('-', ' ')) }
        }
        item { InfoCard("Android", if (s != null) s.androidRelease + " / SDK " + s.androidSdk else "Waiting for API") }
        item { InfoCard("Build", s?.let { if (it.previewBuild == "yes") it.buildId + " • preview/beta" else it.buildId } ?: "Waiting for API") }
        item { InfoCard("Security patch", s?.securityPatch ?: "Waiting for API") }
        item { InfoCard("Build fingerprint", s?.buildFingerprint ?: "Waiting for API") }
        if (s != null) {
            item { Text("Effective engine settings", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            item { InfoCard("Watchdog", "Enabled " + s.settings.watchdogEnabled + " • every " + s.settings.watchdogInterval + "s") }
            item { InfoCard("Fault confirmation", s.settings.failureThreshold + " faults / " + s.settings.failureWindowSeconds + "s") }
            item { InfoCard("Recovery limits", "Cooldown " + s.settings.recoveryCooldown + "s • max " + s.settings.maxRestartsPerHour + "/hour") }
            item { InfoCard("Recovery guards", "Adapter " + s.settings.adapterRecovery + " • freeze " + s.settings.interactionFreezeGuard) }
            item { InfoCard("BLE / Location", "BLE always " + s.settings.bleScanAlways + " • location mode " + s.settings.locationMode) }
        }
        item {
            val active = s?.let { status ->
                listOf(status.activePokemonGo, status.activePokemod).filter { p -> p != "none" && p.isNotBlank() }
            }.orEmpty()
            InfoCard("Supported apps active", active.joinToString().ifBlank { "None detected" })
        }
    }
}

@Composable
private fun Support(snapshot: CompanionSnapshot, onRefresh: () -> Unit) {
    val s = snapshot.status
    var diagnosticState by remember { mutableStateOf("") }
    var generating by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SectionHeader("Support", "Installation and manager API diagnostics") }
        item { InfoCard("Root access", if (snapshot.rootAvailable) "Granted • " + snapshot.rootProvider else "Unavailable") }
        item { InfoCard("Module", if (snapshot.module.detected) "Detected • v" + snapshot.module.version else "Not detected") }
        item { InfoCard("Module enabled", if (snapshot.module.enabled) "Yes" else "No") }
        item { InfoCard("Manager API", if (s != null) s.serviceState + " • schema " + s.schema + " • " + apiFreshness(s) else "Unavailable") }
        item { InfoCard("API source", snapshot.apiSource) }
        item { InfoCard("Status updated", s?.timestamp ?: "No snapshot") }
        snapshot.error?.let { item { WarningCard(it) } }
        item { InfoCard("Recovery ownership", "The app is a monitor/support surface. Bluetooth recovery and policy remain inside the Magisk module.") }
        item {
            Button(enabled = snapshot.rootAvailable && snapshot.module.detected && !generating, onClick = {
                generating = true; diagnosticState = "Generating sanitized support bundle…"
                scope.launch {
                    val result = withContext(Dispatchers.IO) { RootBridge.generateDiagnostics() }
                    generating = false
                    diagnosticState = result.fold(
                        onSuccess = { path -> "Report ready: " + path },
                        onFailure = { err -> "Report failed: " + (err.message ?: "unknown error") }
                    )
                }
            }, modifier = Modifier.fillMaxWidth()) { Text(if (generating) "Generating…" else "Generate Diagnostic Report") }
        }
        if (diagnosticState.isNotBlank()) item { InfoCard("Diagnostics", diagnosticState) }
        item { InfoCard("Privacy", "Support reports redact Bluetooth MAC addresses and are generated locally. Review the report before sharing.") }
        item { Button(onClick = onRefresh, Modifier.fillMaxWidth()) { Text("Run detection again") } }
    }
}

@Composable
private fun NavGlyph(index: Int, selected: Boolean) {
    val c = if (selected) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
    Canvas(Modifier.size(22.dp)) {
        val w = size.width; val h = size.height
        val sw = 2.2.dp.toPx()
        val stroke = Stroke(sw, cap = StrokeCap.Round)
        when (index) {
            0 -> drawCircle(c, radius = w * 0.33f, style = stroke) // Overview: health ring
            1 -> for (i in 0..2) { // Activity: event lines
                val y = h * (0.28f + 0.22f * i)
                drawLine(c, Offset(w * 0.18f, y), Offset(w * 0.82f, y), strokeWidth = sw, cap = StrokeCap.Round)
            }
            2 -> drawRoundRect( // Device: chip
                c, topLeft = Offset(w * 0.2f, h * 0.22f), size = Size(w * 0.6f, h * 0.56f),
                cornerRadius = CornerRadius(w * 0.14f), style = stroke
            )
            else -> { // Support: ring + center dot
                drawCircle(c, radius = w * 0.33f, style = stroke)
                drawCircle(c, radius = sw, center = Offset(w / 2f, h / 2f))
            }
        }
    }
}

@Composable
private fun StatusStrip(moduleOk: Boolean, apiOk: Boolean, rootOk: Boolean) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        StatusPill("ROOT", rootOk, Modifier.weight(1f))
        StatusPill("MODULE", moduleOk, Modifier.weight(1f))
        StatusPill("API", apiOk, Modifier.weight(1f))
    }
}

@Composable
private fun StatusPill(label: String, ok: Boolean, modifier: Modifier) {
    val color = if (ok) Status.good else Status.bad
    Surface(modifier = modifier, color = color.copy(alpha = 0.16f), shape = RoundedCornerShape(14.dp)) {
        Text(
            label + if (ok) "  ✓" else "  !",
            color = color,
            modifier = Modifier.padding(vertical = 10.dp),
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun Chip(text: String, color: Color) {
    Surface(color = color.copy(alpha = 0.16f), shape = RoundedCornerShape(12.dp)) {
        Text(text, color = color, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SeverityPill(severity: String) {
    val color = when (severity.lowercase()) {
        "error", "critical" -> Status.bad
        "warning", "warn" -> Status.warn
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Surface(color = color.copy(alpha = 0.16f), shape = RoundedCornerShape(12.dp)) {
        Text(severity.uppercase(), color = color, modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp), style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun SectionHeader(title: String, subtitle: String) {
    Column(Modifier.padding(top = 4.dp)) {
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun CenterMessage(message: String) =
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    }

@Composable
private fun SmallMetric(title: String, value: String, modifier: Modifier) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(14.dp)) {
            Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            Text(value, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 3.dp))
        }
    }
}

@Composable
private fun InfoCard(title: String, value: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.fillMaxWidth().padding(14.dp)) {
            Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            Text(value, Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
private fun WarningCard(message: String) {
    Surface(color = Status.warn.copy(alpha = 0.16f), shape = RoundedCornerShape(18.dp)) {
        Text(message, Modifier.fillMaxWidth().padding(14.dp), color = Status.warn)
    }
}

private fun componentLabel(name: String): String = when (name) {
    "bluetooth_off" -> "Bluetooth off"
    "no_bt_process" -> "No BT service process"
    "adapter_bad_state" -> "Adapter bad state"
    "recent_stall" -> "Recent stall"
    "acl_instability" -> "ACL link instability"
    else -> name.replace('_', ' ')
}

private fun heartbeat(age: Long) = when {
    age < 0 -> "Unknown"
    age < 90 -> age.toString() + "s"
    else -> "Stale " + age + "s"
}

private fun friendlyNone(value: String) =
    if (value.isBlank() || value == "none" || value == "unknown") "None recorded" else value

private fun formatUptime(seconds: Long): String {
    if (seconds < 0) return "unknown"
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    return if (h > 0) "${h}h ${m}m" else "${m}m"
}

private fun apiFreshness(status: BshStatus): String {
    val now = System.currentTimeMillis() / 1000
    val age = if (status.epoch > 0) now - status.epoch else -1
    return when {
        age < 0 -> "age unknown"
        age <= 90 -> "fresh"
        else -> "stale ${age}s"
    }
}

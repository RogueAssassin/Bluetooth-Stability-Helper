package com.rogueassassin.bsh

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Bg = Color(0xFF090B10)
private val Surface = Color(0xFF141821)
private val Surface2 = Color(0xFF1B202B)
private val Accent = Color(0xFF00D7F2)
private val Purple = Color(0xFF8B5CF6)
private val Green = Color(0xFF34E77B)
private val Amber = Color(0xFFFFB454)
private val Red = Color(0xFFFF657A)
private val Muted = Color(0xFF9AA5B4)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { BshApp() }
    }
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

    MaterialTheme(colorScheme = darkColorScheme(primary = Accent, secondary = Purple, background = Bg, surface = Surface)) {
        Scaffold(
            containerColor = Bg,
            topBar = {
                TopAppBar(
                    title = { Text("BSH Companion", fontWeight = FontWeight.SemiBold) },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Bg)
                )
            },
            bottomBar = {
                NavigationBar(containerColor = Surface) {
                    listOf("Overview", "Activity", "Device", "Support").forEachIndexed { index, label ->
                        NavigationBarItem(
                            selected = tab == index,
                            onClick = { tab = index },
                            icon = { Text(listOf("●", "≡", "◇", "?")[index]) },
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
}

@Composable
private fun Overview(snapshot: CompanionSnapshot, onRefresh: () -> Unit) {
    val s = snapshot.status
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(R.drawable.bsh_logo), "BSH logo", Modifier.size(74.dp))
                Column(Modifier.padding(start = 14.dp)) {
                    Text("Bluetooth Stability Helper", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text("Pixel-first recovery engine", color = Muted)
                }
            }
        }
        item { StatusStrip(snapshot.module.detected && snapshot.module.enabled, s != null, snapshot.rootAvailable) }
        snapshot.error?.let { item { WarningCard(it) } }

        if (s != null) {
            item { HealthCard(s.healthScore, s.recoveryState, s.profile) }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("Bluetooth", if (s.bluetoothEnabled == "1") "On" else s.bluetoothEnabled, Modifier.weight(1f))
                    SmallMetric("Heartbeat", heartbeat(s.heartbeatAgeSeconds), Modifier.weight(1f))
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("BT services", s.bluetoothProcessCount, Modifier.weight(1f))
                    SmallMetric("API", "v" + s.schema, Modifier.weight(1f))
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
private fun Activity(snapshot: CompanionSnapshot) {
    if (snapshot.events.isEmpty()) {
        CenterMessage("No recent fault or recovery events have been recorded.")
        return
    }
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Text("Activity", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Newest bounded engine events", color = Muted)
        }
        items(snapshot.events) { event ->
            Card(colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(event.type.replace('_', ' '), color = Accent, fontWeight = FontWeight.SemiBold)
                        SeverityPill(event.severity)
                    }
                    if (event.message.isNotBlank()) Text(event.message, Modifier.padding(top = 7.dp))
                    if (event.action.isNotBlank() || event.outcome.isNotBlank()) {
                        Text(listOf(event.action, event.outcome).filter { it.isNotBlank() }.joinToString(" • "), color = Green, modifier = Modifier.padding(top = 6.dp))
                    }
                    Text(event.timestamp + " • " + event.source, color = Muted, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 9.dp))
                }
            }
        }
    }
}

@Composable
private fun Device(snapshot: CompanionSnapshot) {
    val s = snapshot.status
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text("Device", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Detected platform and module profile", color = Muted)
        }
        item { InfoCard("Module", if (snapshot.module.detected) "v" + snapshot.module.version else "Not detected") }
        item { InfoCard("Module state", if (snapshot.module.enabled) "Enabled" else "Disabled / unavailable") }
        item { InfoCard("Profile", s?.profile ?: "Waiting for API") }
        item { InfoCard("Service", s?.let { it.serviceState + " • uptime " + formatUptime(it.serviceUptimeSeconds) } ?: "Waiting for API") }
        item { InfoCard("Root environment", s?.let { it.rootProvider + " • Zygisk " + it.zygisk } ?: snapshot.rootProvider) }
        item { InfoCard("Manufacturer", s?.manufacturer ?: "Waiting for API") }
        item { InfoCard("Brand / model", s?.let { it.brand + " / " + it.model } ?: "Waiting for API") }
        item { InfoCard("Device", s?.device ?: "Waiting for API") }
        item { InfoCard("Android", if (s != null) s.androidRelease + " / SDK " + s.androidSdk else "Waiting for API") }
        item { InfoCard("Build", s?.buildId ?: "Waiting for API") }
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
    val context = androidx.compose.ui.platform.LocalContext.current
    var diagnosticState by remember { mutableStateOf("") }
    var generating by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text("Support", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Installation and manager API diagnostics", color = Muted)
        }
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
private fun StatusStrip(moduleOk: Boolean, apiOk: Boolean, rootOk: Boolean) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        StatusPill("ROOT", rootOk, Modifier.weight(1f))
        StatusPill("MODULE", moduleOk, Modifier.weight(1f))
        StatusPill("API", apiOk, Modifier.weight(1f))
    }
}

@Composable
private fun StatusPill(label: String, ok: Boolean, modifier: Modifier) {
    Surface(modifier = modifier, color = if (ok) Color(0xFF153328) else Color(0xFF35232A), shape = RoundedCornerShape(14.dp)) {
        Text(
            label + if (ok) "  ✓" else "  !",
            color = if (ok) Green else Red,
            modifier = Modifier.padding(vertical = 10.dp),
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun HealthCard(score: Int, state: String, profile: String) {
    val accent = when {
        score >= 85 -> Green
        score >= 65 -> Accent
        score >= 40 -> Amber
        else -> Red
    }
    Card(colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(22.dp)) {
        Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
            Surface(shape = CircleShape, color = accent.copy(alpha = 0.14f), modifier = Modifier.size(92.dp)) {
                Box(contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(score.toString(), color = accent, style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                        Text("HEALTH", color = Muted, style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
            Column(Modifier.padding(start = 18.dp)) {
                Text(state.replace('_', ' '), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text(profile, color = Accent)
                Text("Adaptive recovery status", color = Muted, modifier = Modifier.padding(top = 3.dp))
            }
        }
    }
}

@Composable
private fun SeverityPill(severity: String) {
    val color = when (severity.lowercase()) {
        "error", "critical" -> Red
        "warning", "warn" -> Amber
        else -> Muted
    }
    Surface(color = color.copy(alpha = 0.14f), shape = RoundedCornerShape(12.dp)) {
        Text(severity.uppercase(), color = color, modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp), style = MaterialTheme.typography.labelSmall)
    }
}

@Composable private fun CenterMessage(message: String) =
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) { Text(message, color = Muted) }

@Composable
private fun SmallMetric(title: String, value: String, modifier: Modifier) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = Surface2), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(14.dp)) {
            Text(title, color = Muted, style = MaterialTheme.typography.bodySmall)
            Text(value, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 3.dp))
        }
    }
}

@Composable
private fun InfoCard(title: String, value: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.fillMaxWidth().padding(14.dp)) {
            Text(title, color = Muted, style = MaterialTheme.typography.bodySmall)
            Text(value, Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
private fun WarningCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF342518)), shape = RoundedCornerShape(18.dp)) {
        Text(message, Modifier.fillMaxWidth().padding(14.dp), color = Color(0xFFFFD39A))
    }
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

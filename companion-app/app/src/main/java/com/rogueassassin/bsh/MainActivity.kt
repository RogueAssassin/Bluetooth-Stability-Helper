package com.rogueassassin.bsh

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private val Bg = Color(0xFF0B0D12)
private val Surface = Color(0xFF151821)
private val Accent = Color(0xFF00D7F2)
private val Purple = Color(0xFF8B5CF6)
private val Green = Color(0xFF34E77B)
private val Muted = Color(0xFF9AA5B4)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { CompanionApp() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CompanionApp() {
    var tab by remember { mutableIntStateOf(0) }
    var refresh by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var snapshot by remember { mutableStateOf<CompanionSnapshot?>(null) }

    LaunchedEffect(refresh) {
        loading = true
        snapshot = withContext(Dispatchers.IO) { BshRepository.load() }
        loading = false
    }

    MaterialTheme(colorScheme = darkColorScheme(primary = Accent, secondary = Purple, background = Bg, surface = Surface)) {
        Scaffold(
            containerColor = Bg,
            topBar = { TopAppBar(title = { Text("Bluetooth Stability Helper") }, colors = TopAppBarDefaults.topAppBarColors(containerColor = Bg)) },
            bottomBar = {
                NavigationBar(containerColor = Surface) {
                    listOf("Dashboard", "Timeline", "Support").forEachIndexed { index, label ->
                        NavigationBarItem(
                            selected = tab == index, onClick = { tab = index },
                            icon = { Text(if (index == 0) "●" else if (index == 1) "≡" else "?") },
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
                    tab == 0 -> Dashboard(snapshot!!) { refresh++ }
                    tab == 1 -> Timeline(snapshot!!)
                    else -> Support(snapshot!!) { refresh++ }
                }
            }
        }
    }
}

@Composable
private fun Dashboard(snapshot: CompanionSnapshot, onRefresh: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(R.drawable.bsh_logo), "BSH logo", Modifier.size(72.dp))
                Column(Modifier.padding(start = 14.dp)) {
                    Text("Companion", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text("Root engine status and telemetry", color = Muted)
                }
            }
        }
        snapshot.error?.let { item { WarningCard(it) } }
        snapshot.status?.let { s ->
            item {
                MetricCard(
                    "Health", s.healthScore.toString() + "/100", s.recoveryState + " • profile " + s.profile,
                    if (s.healthScore >= 85) Green else if (s.healthScore >= 65) Accent else Purple
                )
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("Bluetooth", if (s.bluetoothEnabled == "1") "On" else s.bluetoothEnabled, Modifier.weight(1f))
                    SmallMetric("BT processes", s.bluetoothProcessCount, Modifier.weight(1f))
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallMetric("Heartbeat", heartbeat(s.heartbeatAgeSeconds), Modifier.weight(1f))
                    SmallMetric("SDK", s.androidSdk, Modifier.weight(1f))
                }
            }
            item { InfoCard("Last fault", s.lastFaultType) }
            item { InfoCard("Last recovery", s.lastRecoveryOutcome) }
            item { InfoCard("Build", s.buildId + " • patch " + s.securityPatch) }
            item {
                val active = listOf(s.activePokemonGo, s.activePokemod).filter { it != "none" && it.isNotBlank() }
                InfoCard("Active supported apps", active.joinToString().ifBlank { "None detected" })
            }
        }
        item { Button(onClick = onRefresh, Modifier.fillMaxWidth()) { Text("Refresh") } }
    }
}

@Composable
private fun Timeline(snapshot: CompanionSnapshot) {
    if (snapshot.events.isEmpty()) {
        CenterMessage("No recent normalized events are available yet.")
        return
    }
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Text("Recent events", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Newest 100 bounded telemetry events", color = Muted)
        }
        items(snapshot.events) { event ->
            Card(colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(event.type, color = Accent, fontWeight = FontWeight.SemiBold)
                        Text(event.severity.uppercase(), color = Muted)
                    }
                    if (event.message.isNotBlank()) Text(event.message, Modifier.padding(top = 6.dp))
                    if (event.action.isNotBlank() || event.outcome.isNotBlank()) {
                        Text(listOf(event.action, event.outcome).filter { it.isNotBlank() }.joinToString(" • "), color = Green, modifier = Modifier.padding(top = 6.dp))
                    }
                    Text(event.timestamp + " • " + event.source, color = Muted, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun Support(snapshot: CompanionSnapshot, onRefresh: () -> Unit) {
    val s = snapshot.status
    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text("Support", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Read-only companion diagnostics", color = Muted)
        }
        item { InfoCard("Root access", if (snapshot.rootAvailable) "Granted" else "Unavailable") }
        item { InfoCard("Manager API", if (s != null) "Schema " + s.schema else "Unavailable") }
        item { InfoCard("Module", s?.moduleVersion ?: "Not detected") }
        item { InfoCard("Profile", s?.profile ?: "Unknown") }
        item { InfoCard("Status updated", s?.timestamp ?: "Unknown") }
        snapshot.error?.let { item { WarningCard(it) } }
        item { InfoCard("Security boundary", "Read-only fixed BSH paths. Recovery remains inside the Magisk module; no generic root console is exposed.") }
        item { Button(onClick = onRefresh, Modifier.fillMaxWidth()) { Text("Re-check module and root") } }
    }
}

@Composable private fun CenterMessage(message: String) = Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text(message, color = Muted) }

@Composable
private fun MetricCard(title: String, value: String, detail: String, accent: Color) {
    Card(colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(20.dp)) {
        Column(Modifier.fillMaxWidth().padding(18.dp)) {
            Text(title, color = Muted)
            Text(value, color = accent, style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Text(detail)
        }
    }
}

@Composable
private fun SmallMetric(title: String, value: String, modifier: Modifier) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = Surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(14.dp)) {
            Text(title, color = Muted, style = MaterialTheme.typography.bodySmall)
            Text(value, fontWeight = FontWeight.SemiBold)
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
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF2A2034)), shape = RoundedCornerShape(18.dp)) {
        Text(message, Modifier.fillMaxWidth().padding(14.dp), color = Color(0xFFFFD7A3))
    }
}

private fun heartbeat(age: Long) = when {
    age < 0 -> "Unknown"
    age < 90 -> age.toString() + "s"
    else -> "Stale " + age + "s"
}

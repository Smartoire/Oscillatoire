package com.smartoire.brainwave

import android.Manifest
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.ui.graphics.Color
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.FabPosition
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.IconButton
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.ui.Alignment
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CompareArrows
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Tune
import androidx.compose.ui.graphics.vector.ImageVector
import com.smartoire.brainwave.ui.BrainwaveTheme
import com.smartoire.brainwave.ui.appBackground
import com.smartoire.brainwave.ui.Splash
import com.smartoire.brainwave.ui.Walkthrough
import com.smartoire.brainwave.ui.walkthroughTarget
import com.smartoire.brainwave.ui.HeadsetIcon
import com.smartoire.brainwave.ui.LotusIcon
import com.smartoire.brainwave.ui.BrandButton
import com.smartoire.brainwave.ui.NavFan
import com.smartoire.brainwave.ui.card
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.ui.text.font.FontWeight
import com.smartoire.brainwave.ui.Segmented
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.smartoire.brainwave.R
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.smartoire.brainwave.kit.ActivityFrame
import com.smartoire.brainwave.kit.Band
import com.smartoire.brainwave.kit.Capture
import com.smartoire.brainwave.kit.CaptureRecorder
import com.smartoire.brainwave.kit.CaptureSample
import com.smartoire.brainwave.kit.CaptureStore
import com.smartoire.brainwave.kit.Electrode
import com.smartoire.brainwave.kit.Metric
import com.smartoire.brainwave.kit.ScoreTracker
import com.smartoire.brainwave.kit.TraceBuffer
import com.smartoire.brainwave.kit.parseCapture
import com.smartoire.brainwave.muse.MuseConnection
import com.smartoire.brainwave.muse.MuseState
import com.smartoire.brainwave.ui.BrainScreen
import com.smartoire.brainwave.ui.CalmScreen
import com.smartoire.brainwave.ui.CapturesScreen
import com.smartoire.brainwave.ui.CompareScreen
import com.smartoire.brainwave.ui.FinishedCaptureScreen
import com.smartoire.brainwave.ui.MindScreen
import com.smartoire.brainwave.ui.Prefs
import com.smartoire.brainwave.ui.SettingsScreen
import com.smartoire.brainwave.ui.SignalsScreen
import com.smartoire.brainwave.ui.StartCheckScreen
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun attachBaseContext(newBase: android.content.Context) {
        val code = Prefs.get(newBase, "language", "en")
        val config = android.content.res.Configuration(newBase.resources.configuration)
        config.setLocale(java.util.Locale.forLanguageTag(code))
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Keep the screen on while the app is open, so the headband session is not interrupted by the lock.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContent {
            Root()
        }
    }
}

/// The app's tabs, as on iPhone. Advanced (brain map and signals) appears when the setting is on.
/// Reads the saved appearance, applies the theme, and runs the app.
@Composable
fun Root() {
    val context = LocalContext.current
    var appearance by remember { mutableStateOf(Prefs.get(context, "appearance", "dark")) }
    var splashDone by rememberSaveable { mutableStateOf(false) }
    BrainwaveTheme(appearance) {
        // A new language recreates the activity, which applies it through attachBaseContext.
        // The walkthrough reads the on-screen frames of the controls it points at, filled in as the screen lays out.
        val targets = remember { androidx.compose.runtime.mutableStateMapOf<String, androidx.compose.ui.geometry.Rect>() }
        androidx.compose.runtime.CompositionLocalProvider(com.smartoire.brainwave.ui.LocalWalkthroughTargets provides targets) {
            if (!splashDone) Splash { splashDone = true } else App(appearance, { appearance = it }, { (context as? android.app.Activity)?.recreate() })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun App(appearance: String, onAppearance: (String) -> Unit, onLanguage: (String) -> Unit = {}) {
    var tab by remember { mutableStateOf("Mind") }
    val context = LocalContext.current
    val muse = remember { MuseConnection(context) }
    val state by muse.state.collectAsState()
    val tracker = remember { ScoreTracker() }
    var tick by remember { mutableIntStateOf(0) }
    var scores by remember { mutableStateOf<Map<Metric, Double?>>(emptyMap()) }
    val latest by rememberUpdatedState(state)
    val clockStart = remember { System.currentTimeMillis() }
    val recorder = remember { CaptureRecorder() }
    var recording by remember { mutableStateOf(false) }
    var captures by remember { mutableStateOf(CaptureStore.loadAll(context)) }
    var finished by remember { mutableStateOf<Capture?>(null) }
    var importMessage by remember { mutableStateOf<String?>(null) }
    val activity = remember { mutableStateListOf<ActivityFrame>() }
    var advanced by remember { mutableStateOf(Prefs.flag(context, "advanced", false)) }

    // Once a second: turn the latest band powers into scores, as Session does on iPhone, and add a capture sample.
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            val now = (System.currentTimeMillis() - clockStart) / 1000.0
            val bad = latest.contact.filterValues { it >= 4.0 }.keys
            muse.demoTick()
            tracker.tick(now, latest.bands, bad)
            tick++
            scores = Metric.entries.associateWith { tracker.latest(it) }
            val overall = tracker.activity()
            if (overall.isNotEmpty()) {
                activity.add(ActivityFrame(now, overall))
                if (activity.size > 3600) activity.removeAt(0)  // one hour at 1 Hz
            }
            if (recorder.isRecording) {
                recorder.add(CaptureSample(
                    time = recorder.elapsed(now),
                    power = Band.entries.flatMap { b -> Electrode.entries.map { e -> latest.bands[b]?.get(e) } },
                    activation = Band.entries.flatMap { b -> Electrode.entries.map { e -> tracker.activation[b]?.get(e) } },
                    scores = Metric.entries.map { tracker.latest(it) },
                    contact = Electrode.entries.map { contactLabel(latest.contact[it]) },
                    movement = latest.movement,
                ))
            }
        }
    }

    val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }
    var granted by remember {
        mutableStateOf(permissions.all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED })
    }
    val askPermissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        granted = result.values.all { it }
    }
    DisposableEffect(granted) {
        if (granted) muse.startSearching()
        onDispose { muse.stopSearching() }
    }

    // Download writes the capture that is under review; import reads a JSON file.
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        val capture = finished
        if (uri != null && capture != null) {
            context.contentResolver.openOutputStream(uri)?.use { it.write(capture.toJson().toString(2).toByteArray()) }
        }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val capture = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { parseCapture(it.readText()) }
            if (capture != null) {
                CaptureStore.save(context, capture)
                captures = CaptureStore.loadAll(context)
                importMessage = null
            } else {
                importMessage = "Couldn't import that file. Choose a capture exported from Brainwave as JSON."
            }
        }
    }

    fun toggleRecording() {
        val now = (System.currentTimeMillis() - clockStart) / 1000.0
        if (recording) {
            recording = false
            finished = recorder.stop(now)
        } else {
            val device = if (state.status == "Demo headband") "Demo headband" else state.status.removePrefix("Connecting to ")
            recorder.start(now, System.currentTimeMillis(), device)
            recording = true
        }
    }

    var showCalm by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var showCheck by remember { mutableStateOf(false) }
    var checkPassed by remember { mutableStateOf(false) }
    // The Before you start check opens once a headband is connected, until the user presses Start.
    val connectedNow = state.status.startsWith("Connected") || state.status == "Demo headband"
    // The page the user came from to open Connect; after connecting, the app goes back there.
    var returnTo by remember { mutableStateOf<String?>(null) }
    fun goBackToSource() {
        val target = returnTo ?: "Mind"
        returnTo = null
        if (target == "Calm") { showCalm = true; tab = "Mind" } else { showCalm = false; tab = target }
    }
    val isDemo = state.status == "Demo headband"
    LaunchedEffect(connectedNow) {
        if (connectedNow && isDemo) goBackToSource()                 // the demo needs no check
        else if (connectedNow && !checkPassed) showCheck = true      // a real headband gets the start check first
    }

    if (showCheck) {
        Box(Modifier.fillMaxSize().appBackground()) {
            StartCheckScreen(state = state) { showCheck = false; checkPassed = true; goBackToSource() }
        }
        return
    }
    val done = finished
    if (done != null) {
        FinishedCaptureScreen(
            capture = done,
            onCancel = { finished = null },
            onSave = { CaptureStore.save(context, done); captures = CaptureStore.loadAll(context); finished = null },
            onDownload = { exportLauncher.launch("Brainwave capture.json") },
        )
        return
    }
    val recordingSeconds = if (recording) recorder.elapsed((System.currentTimeMillis() - clockStart) / 1000.0) else null

    // Four tabs in the bar, with Calm in the centre. Connect opens from the top bar; Advanced opens from Settings.
    val barTabs = listOf("Mind", "Compare", "Captures", "Settings", "Advanced")
    val screens = listOf("Mind", "Compare", "Captures", "Settings", "Advanced", "Connect")
    val current = if (tab in screens) tab else "Mind"

    // Edge to edge: the backdrop runs behind the status bar and the top bar, with no screen titles.
    Box(modifier = Modifier.fillMaxSize().appBackground()) {
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            // Three labelled controls: Record (left), Calm session (middle), Headband (right). Back replaces Record on sub-pages.
            TopAppBar(
                title = {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                        if (current == "Advanced" || current == "Connect") {
                            TopAction(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.top_back), null) { tab = "Settings" }
                        } else {
                            TopAction(
                                Icons.Filled.FiberManualRecord,
                                if (recording) stringResource(R.string.nav_stop) else stringResource(R.string.top_record),
                                if (recording) Color.Red else null,
                            ) { toggleRecording() }
                        }
                        if (showCalm) TopAction(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.top_back), null) { showCalm = false } else TopAction(LotusIcon, stringResource(R.string.top_calm), MaterialTheme.colorScheme.primary, target = "calm") { showCalm = true }
                        TopAction(
                            HeadsetIcon,
                            stringResource(R.string.top_headband),
                            if (connectedNow) Color(0xFF34C759) else null,
                            target = "headband",
                        ) {
                            // Remember where the user came from, unless they are already on Connect.
                            if (!(tab == "Connect" && !showCalm)) returnTo = if (showCalm) "Calm" else tab
                            showCalm = false
                            tab = "Connect"
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        // Keep page content clear of the menu button: a right margin in landscape, a bottom margin in portrait.
        val landscapeNow = LocalConfiguration.current.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE
        Column(
            modifier = Modifier.fillMaxSize().padding(padding)
                .padding(end = if (landscapeNow) 72.dp else 0.dp, bottom = if (landscapeNow) 0.dp else 88.dp),
        ) {
            if (showCalm) CalmScreen(calmScore = scores[Metric.CALM]) { showCalm = false } else when (current) {
                "Mind" -> Column {
                    MindScreen(tracker = tracker, scores = scores, tick = tick, connected = connectedNow, clockStart = clockStart)
                }
                "Compare" -> CompareScreen(frames = activity.toList(), origin = clockStart)
                "Captures" -> CapturesScreen(
                    captures = captures,
                    message = importMessage,
                    recordingSeconds = recordingSeconds,
                    connected = connectedNow,
                    onToggleRecording = { toggleRecording() },
                    onImport = { importLauncher.launch(arrayOf("*/*")) },
                    onDelete = { CaptureStore.delete(context, it); captures = CaptureStore.loadAll(context) },
                )
                "Settings" -> SettingsScreen(advanced = advanced, onAppearance = onAppearance, onLanguage = onLanguage, onOpenAdvanced = { tab = "Advanced" }, onAdvanced = {
                    advanced = it
                    Prefs.setFlag(context, "advanced", it)
                })
                "Advanced" -> AdvancedTab(
                    tracker = tracker,
                    tick = tick,
                    state = state,
                    connected = connectedNow,
                    traces = muse.traces.snapshot(),
                )
                else -> ConnectTab(state.status, state.headbands, granted, onAllow = { askPermissions.launch(permissions) }, onConnect = muse::connect, onDisconnect = muse::disconnect, onDemo = { muse.startDemo() }, battery = state.battery)
            }
        }
    }
        NavFan(
            items = listOf(
                "Mind" to Icons.Filled.Psychology,
                "Compare" to Icons.Filled.CompareArrows,
                "Captures" to Icons.Filled.FolderOpen,
                "Settings" to Icons.Filled.Settings,
                "Advanced" to Icons.Filled.Tune,
            ),
            labels = mapOf(
                "Mind" to stringResource(R.string.tab_mind),
                "Compare" to stringResource(R.string.tab_compare),
                "Captures" to stringResource(R.string.tab_captures),
                "Settings" to stringResource(R.string.tab_settings),
                "Advanced" to stringResource(R.string.tab_advanced),
            ),
            current = current,
            connected = connectedNow,
            open = menuOpen,
            onOpenChange = { menuOpen = it },
            onPick = { tab = it; menuOpen = false },
        )
        Walkthrough()
    }
}

/// One tab in the bottom bar: icon and label, tinted when chosen.
@Composable
private fun RowScope.BarItem(title: String, current: String, onClick: () -> Unit) {
    val selected = current == title
    val tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.weight(1f).clickable(onClick = onClick).padding(vertical = 6.dp),
    ) {
        Icon(tabIcon(title), contentDescription = title, tint = tint)
        Text(title, style = MaterialTheme.typography.labelSmall, color = tint, maxLines = 1)
    }
}

private fun tabIcon(title: String): ImageVector = when (title) {
    "Mind" -> Icons.Filled.Psychology
    "Compare" -> Icons.Filled.CompareArrows
    "Captures" -> Icons.Filled.FolderOpen
    "Settings" -> Icons.Filled.Settings
    "Advanced" -> Icons.Filled.Tune
    else -> HeadsetIcon
}

/// Brain and Signals, one tab, chosen with a switch at the top.
@Composable
private fun AdvancedTab(
    tracker: ScoreTracker,
    tick: Int,
    state: MuseState,
    connected: Boolean,
    traces: Map<Electrode, List<TraceBuffer.Point>>,
) {
    var part by remember { mutableStateOf(0) }
    Column(modifier = Modifier.fillMaxSize()) {
        Segmented(
            options = listOf(0 to stringResource(R.string.adv_brain), 1 to stringResource(R.string.adv_signals)),
            selected = part,
            onSelect = { part = it },
            modifier = Modifier.padding(16.dp),
        )
        Box(modifier = Modifier.weight(1f)) {
            if (part == 0) {
                BrainScreen(tracker, tick, connected, state.movement, state.contact, advanced = true)
            } else {
                SignalsScreen(traces, state.bands)
            }
        }
    }
}

/// Contact quality as the capture file names it: the SDK's 1 good, 2 ok, 4 bad.
private fun contactLabel(value: Double?): String? = when {
    value == null -> null
    value >= 4.0 -> "bad"
    value >= 2.0 -> "ok"
    else -> "good"
}

@Composable
private fun ConnectTab(
    status: String,
    headbands: List<String>,
    granted: Boolean,
    onAllow: () -> Unit,
    onConnect: (String) -> Unit,
    onDisconnect: () -> Unit,
    onDemo: () -> Unit,
    battery: Double?,
) {
    val connected = status.startsWith("Connected") || status == "Demo headband"
    val accent = if (connected) Color(0xFF34C759) else MaterialTheme.colorScheme.onSurfaceVariant
    // Top margin so the title sits below the clock, not against it.
    Column(modifier = Modifier.fillMaxSize().padding(start = 16.dp, end = 16.dp, top = 40.dp, bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Headband", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        // Status hero card, like the Mind state cards: the headband icon, the state and the battery.
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().card().padding(18.dp)) {
            Icon(HeadsetIcon, contentDescription = null, tint = accent, modifier = Modifier.size(56.dp))
            Column(modifier = Modifier.weight(1f).padding(start = 14.dp)) {
                Text(status, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = accent)
                Text(
                    if (connected) stringResource(R.string.hb_ready) else stringResource(R.string.hb_not_connected),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            battery?.let {
                Text("${it.toInt()}%", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
        }
        if (!granted) {
            BrandButton(onClick = onAllow, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.hb_allow)) }
        } else {
            // One card: the demo headband first, then the nearby headbands. When connected, the only control is Disconnect.
            Column(modifier = Modifier.fillMaxWidth().card().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (connected) {
                    // Only the stop control while connected.
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                        IconButton(onClick = onDisconnect) {
                            Icon(Icons.Filled.Stop, contentDescription = "Stop", tint = Color(0xFFE94E89))
                        }
                    }
                } else {
                    if (headbands.isEmpty()) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                            Text(stringResource(R.string.hb_searching), style = MaterialTheme.typography.bodyMedium)
                        }
                        Text(stringResource(R.string.hb_turn_on), style = MaterialTheme.typography.bodySmall)
                    } else {
                        Text(stringResource(R.string.hb_nearby), style = MaterialTheme.typography.bodyMedium)
                    }
                    BrandButton(onClick = onDemo, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.hb_demo)) }
                    headbands.forEach { name ->
                        BrandButton(onClick = { onConnect(name) }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.hb_connect).format(name)) }
                    }
                }
            }
        }
    }
}

/// One labelled action in the top bar: an icon with its name under it.
@Composable
private fun TopAction(icon: ImageVector, label: String, tint: Color?, target: String? = null, onClick: () -> Unit) {
    val named = if (target != null) Modifier.walkthroughTarget(target) else Modifier
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = named.clickable(onClick = onClick).padding(horizontal = 8.dp, vertical = 2.dp)) {
        Icon(icon, contentDescription = label, tint = tint ?: MaterialTheme.colorScheme.onSurfaceVariant)
        Text(label, style = MaterialTheme.typography.labelSmall, color = tint ?: MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
    }
}

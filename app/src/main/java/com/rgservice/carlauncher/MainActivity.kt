package com.rgservice.carlauncher

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rgservice.carlauncher.core.DesignScale
import com.rgservice.carlauncher.data.ThemeMode
import com.rgservice.carlauncher.data.apps.Slot
import com.rgservice.carlauncher.data.location.LiveGps
import com.rgservice.carlauncher.data.location.TripService
import com.rgservice.carlauncher.data.media.LiveNav
import com.rgservice.carlauncher.ui.apps.AppsScreen
import com.rgservice.carlauncher.ui.components.PerfMeter
import com.rgservice.carlauncher.ui.home.HomeActions
import com.rgservice.carlauncher.ui.home.HomeDialog
import com.rgservice.carlauncher.ui.home.HomeDialogs
import com.rgservice.carlauncher.ui.home.HomeScreen
import com.rgservice.carlauncher.ui.home.HomeViewModel
import com.rgservice.carlauncher.ui.maint.MaintActions
import com.rgservice.carlauncher.ui.maint.MaintScreen
import com.rgservice.carlauncher.ui.pages.RightActions
import com.rgservice.carlauncher.ui.pages.RightData
import com.rgservice.carlauncher.ui.settings.SettingsActions
import com.rgservice.carlauncher.ui.settings.SettingsData
import com.rgservice.carlauncher.ui.settings.SettingsScreen
import com.rgservice.carlauncher.ui.theme.CarLauncherTheme
import com.rgservice.carlauncher.ui.welcome.WelcomeScreen

/** Pantallas de la app. */
enum class Screen { Home, Maint, Apps, Settings }

class MainActivity : ComponentActivity() {

    private val vm: HomeViewModel by viewModels()
    private val dialog = mutableStateOf<HomeDialog?>(null)
    private val screen = mutableStateOf(Screen.Home)
    private val welcome = mutableStateOf(false)
    private val welcomePref = mutableStateOf(true)
    private val ignPref = mutableStateOf(true)
    /** Sube al volver a la app: refresca los estados de permisos en Ajustes. */
    private val resumeTick = mutableIntStateOf(0)

    private val askLocation = registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) TripService.start(this)
        else toast("Sin permiso de ubicación no se puede medir velocidad ni km")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Red de seguridad: si se cerró por error varias veces seguidas, ofrecer volver al launcher original
        if (CarApp.tooManyCrashes(application)) {
            toast("Car Launcher falló varias veces. Podés elegir otra pantalla de inicio.")
            openHomeSettings()
        }
        welcomePref.value = vm.welcomeOn
        ignPref.value = vm.ignitionOpen
        welcome.value = savedInstanceState == null && vm.welcomeOn

        val actions = HomeActions(
            onCycleTheme = {
                val m = vm.cycleTheme()
                toast(when (m) {
                    ThemeMode.Auto -> "Modo noche automático (según el sol)"
                    ThemeMode.Night -> "Modo noche siempre"
                    ThemeMode.Day -> "Modo día siempre"
                })
            },
            onSettings = { screen.value = Screen.Settings },
            onApps = { screen.value = Screen.Apps },
            onMaint = { screen.value = Screen.Maint },
            onToggleStats = vm::toggleStats,
            onComingSoon = { what -> toast("$what: llega en la próxima etapa") },
            onGauge = { id -> dialog.value = HomeDialog.GaugeEdit(id) },
            onOdometer = { dialog.value = HomeDialog.Odometer() },
            onName = { dialog.value = HomeDialog.Name },
            onLimit = { dialog.value = HomeDialog.Limit },
            onTrip = { dialog.value = HomeDialog.TripReset },
            onSlot = ::openSlot,
            onSlotLong = ::pickSlot,
            onBluetooth = {
                if (!vm.apps.start(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))) toast("No se pudo abrir Bluetooth")
            },
        )

        val rightActions = RightActions(
            onPage = vm::savePage,
            onPlayPause = { vm.music.playPause() },
            onNext = { vm.music.next() },
            onPrevious = { vm.music.previous() },
            onOpenMusic = {
                val pkg = vm.music.openPlayingApp()
                if (!vm.apps.launch(pkg)) openSlot(Slot.Music)
            },
            onMusicPermission = ::openMusicPermission,
            onMusicDiag = { dialog.value = HomeDialog.MusicDiag },
            onOpenMaps = { openSlot(Slot.Nav) },
            onNavBanner = { n ->
                val ok = try { n.intent?.send(); n.intent != null } catch (e: Exception) { false }
                if (!ok) vm.apps.launch(n.pkg)
            },
            onDest = { key, name ->
                val d = vm.apps.dest.value[key]
                if (d == null) dialog.value = HomeDialog.Destination(key, name)
                else if (!vm.apps.navigateTo(d)) toast("No hay app de mapas para navegar")
            },
            onDestLong = { key, name -> dialog.value = HomeDialog.Destination(key, name) },
            onZoom = vm::saveZoom,
            onFav = { pkg -> if (!vm.apps.launch(pkg)) toast("No se pudo abrir") },
            onFavLong = { pkg -> dialog.value = HomeDialog.FavMenu(pkg) },
            onFavAdd = { dialog.value = HomeDialog.PickApp("Agregar a accesos") },
        )

        val maintActions = MaintActions(
            onBack = ::goHome,
            onOdometer = { dialog.value = HomeDialog.Odometer() },
            onAdd = { dialog.value = HomeDialog.AddItem },
            onChangedNow = { id ->
                if (vm.repo.maint.hasOdo()) {
                    vm.repo.maint.changedNow(id)
                    toast("Listo: próximo cambio a los ${vm.repo.maint.next(id)?.let { String.format(java.util.Locale.US, "%,d", it).replace(',', '.') }} km")
                } else dialog.value = HomeDialog.Odometer(then = id)
            },
            onSticker = { id ->
                dialog.value = if (vm.repo.maint.hasOdo()) HomeDialog.NextKm(id) else HomeDialog.Odometer(then = id)
            },
            onMore = { id -> dialog.value = HomeDialog.GaugeEdit(id) },
            onDate = { id -> dialog.value = HomeDialog.DateEdit(id) },
            onClearDate = { id -> vm.repo.maint.setDate(id, null) },
        )

        val settingsActions = SettingsActions(
            onBack = ::goHome,
            onSize = vm::setSize,
            onTheme = { vm.repo.setTheme(it) },
            onStats = vm::setStats,
            onName = { dialog.value = HomeDialog.Name },
            onLimit = { dialog.value = HomeDialog.Limit },
            onOdometer = { dialog.value = HomeDialog.Odometer() },
            onTrip = { dialog.value = HomeDialog.TripReset },
            onSlot = { s -> dialog.value = HomeDialog.PickApp("App para ${s.label}", slot = s, launch = false) },
            onLocationPermission = {
                if (locationOk()) vm.apps.start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                else askLocation.launch(Manifest.permission.ACCESS_FINE_LOCATION)
            },
            onMusicPermission = ::openMusicPermission,
            onMusicDiag = { dialog.value = HomeDialog.MusicDiag },
            onAndroidSettings = { vm.apps.start(Intent(Settings.ACTION_SETTINGS)) },
            onWelcome = { on -> vm.welcomeOn = on; welcomePref.value = on },
            onIgnitionOpen = { on -> vm.ignitionOpen = on; ignPref.value = on },
            onHomeApp = {
                toast("Elegí \"Car Launcher 3\" como pantalla de inicio")
                openHomeSettings()
            },
            onOverlay = {
                vm.apps.start(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
            },
            onPreviewWelcome = { screen.value = Screen.Home; welcome.value = true },
        )

        val initialPage = vm.initialPage
        val initialZoom = vm.mapZoom
        val version = try { packageManager.getPackageInfo(packageName, 0).versionName ?: "" } catch (e: Exception) { "" }

        setContent {
            val state by vm.state.collectAsStateWithLifecycle()
            val size by vm.size.collectAsStateWithLifecycle()
            val stats by vm.showStats.collectAsStateWithLifecycle()
            val open by dialog
            val current by screen
            val showWelcome by welcome

            CarLauncherTheme(dark = state.dark) {
                DesignScale(size) {
                    Box(Modifier.fillMaxSize()) {
                        // El inicio se arma recién cuando termina la bienvenida (un solo video a la vez)
                        if (!showWelcome) AnimatedContent(
                            targetState = current,
                            transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(160)) },
                            label = "screen",
                        ) { sc ->
                            when (sc) {
                                Screen.Home -> {
                                    val media by vm.media.collectAsStateWithLifecycle()
                                    val nav by LiveNav.nav.collectAsStateWithLifecycle()
                                    val fix by LiveGps.fix.collectAsStateWithLifecycle()
                                    val favs by vm.apps.favs.collectAsStateWithLifecycle()
                                    val dest by vm.apps.dest.collectAsStateWithLifecycle()
                                    val right = RightData(
                                        media = media, nav = nav, fix = fix?.takeIf { state.gpsOk },
                                        fallbackLat = vm.lastLat(), fallbackLon = vm.lastLon(),
                                        favs = favs, dest = dest, apps = vm.apps,
                                        initialPage = initialPage, initialZoom = initialZoom,
                                    )
                                    HomeScreen(state, right, rightActions, actions)
                                }
                                Screen.Maint -> {
                                    val m by vm.maint.collectAsStateWithLifecycle()
                                    MaintScreen(m, vm.maintSel, onSelect = { vm.maintSel = it }, a = maintActions)
                                }
                                Screen.Apps -> AppsScreen(
                                    vm.apps, onBack = ::goHome,
                                    onOpen = { pkg -> if (!vm.apps.launch(pkg)) toast("No se pudo abrir") },
                                    onLong = { pkg ->
                                        if (pkg in vm.apps.favs.value) toast("Ya está en Accesos")
                                        else if (vm.apps.favs.value.size >= 6) toast("Accesos está lleno (6). Quitá una primero")
                                        else { vm.apps.addFav(pkg); toast("${vm.apps.label(pkg)} agregada a Accesos") }
                                    },
                                )
                                Screen.Settings -> {
                                    val slots by vm.apps.slots.collectAsStateWithLifecycle()
                                    val media by vm.media.collectAsStateWithLifecycle()
                                    val tick by resumeTick
                                    SettingsScreen(
                                        SettingsData(
                                            size = size, theme = state.theme, stats = stats,
                                            name = state.name, limit = state.speedLimit, odo = state.odoKm,
                                            slots = slots, slotLabel = vm.apps::label,
                                            locationOk = locationOk(), musicOk = media.hasPermission,
                                            version = version,
                                            welcome = welcomePref.value,
                                            ignitionOpen = ignPref.value,
                                            isHome = remember(tick) { isDefaultHome() },
                                            overlayOk = remember(tick) { Settings.canDrawOverlays(this@MainActivity) },
                                        ),
                                        settingsActions,
                                    )
                                }
                            }
                        }
                        AnimatedVisibility(showWelcome, enter = fadeIn(tween(1)), exit = fadeOut(tween(450))) {
                            val m by vm.maint.collectAsStateWithLifecycle()
                            WelcomeScreen(state.name, m) { welcome.value = false }
                        }
                        if (stats) PerfMeter(Modifier.align(Alignment.TopCenter).padding(top = 4.dp), onClick = vm::toggleStats)
                    }
                    HomeDialogs(open, state, vm) { dialog.value = it }
                }
            }
        }

        if (locationOk()) TripService.start(this)
        else askLocation.launch(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Botón Inicio o contacto: cierra ventanas y vuelve a la pantalla principal
        dialog.value = null
        screen.value = Screen.Home
        if (intent.getBooleanExtra("ign", false) && vm.welcomeOn) welcome.value = true
    }

    override fun onResume() {
        super.onResume()
        resumeTick.intValue++
    }

    private fun isDefaultHome(): Boolean {
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val r = packageManager.resolveActivity(i, PackageManager.MATCH_DEFAULT_ONLY)
        return r?.activityInfo?.packageName == packageName
    }

    private fun openHomeSettings() {
        if (!vm.apps.start(Intent(Settings.ACTION_HOME_SETTINGS))) vm.apps.start(Intent(Settings.ACTION_SETTINGS))
    }

    private fun locationOk() =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun goHome() { screen.value = Screen.Home }

    /** Abre la app del botón; si todavía no se eligió (o ya no está), pide elegirla. */
    private fun openSlot(slot: Slot) {
        val pkg = vm.apps.slots.value[slot]
        if (!vm.apps.launch(pkg)) pickSlot(slot)
    }

    private fun pickSlot(slot: Slot) { dialog.value = HomeDialog.PickApp("App para ${slot.label}", slot = slot) }

    private fun openMusicPermission() {
        toast("Activá \"Car Launcher 3\" en la lista")
        vm.apps.start(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun toast(t: String) = Toast.makeText(this, t, Toast.LENGTH_SHORT).show()

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Un launcher no se cierra con Atrás: cierra la ventana abierta o vuelve al inicio
        when {
            dialog.value != null -> dialog.value = null
            screen.value != Screen.Home -> screen.value = Screen.Home
        }
    }
}

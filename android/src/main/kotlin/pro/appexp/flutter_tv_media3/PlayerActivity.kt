package pro.appexp.flutter_tv_media3

import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Metadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.PlayerTransferState
import androidx.media3.common.Timeline
import androidx.media3.common.Tracks
import androidx.media3.common.util.StuckPlayerException
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import pro.appexp.flutter_tv_media3.audio.VolumeManager
import pro.appexp.flutter_tv_media3.player.MediaSourceBuilder
import pro.appexp.flutter_tv_media3.player.MetadataParser
import pro.appexp.flutter_tv_media3.player.PlaylistManager
import pro.appexp.flutter_tv_media3.player.TrackManager
import pro.appexp.flutter_tv_media3.subtitle.SubtitleStyleManager

/**
 * The main Activity responsible for video playback and displaying the UI.
 *
 * This Activity is responsible only for:
 * - Lifecycle management (onCreate/onPause/onResume/onDestroy)
 * - ExoPlayer and FlutterEngine initialization
 * - Bridging MethodChannel calls to the appropriate delegates
 *
 * All business logic is delegated to:
 * - [PlaylistManager]      — playlist navigation, shuffle, repeat
 * - [TrackManager]         — track reading and selection
 * - [MediaSourceBuilder]   — MediaSource construction
 * - [SubtitleStyleManager] — subtitle styling
 * - [VolumeManager]        — system volume control
 * - [MetadataParser]       — media metadata parsing
 */
@UnstableApi
class PlayerActivity : AppCompatActivity() {

    // ─── ExoPlayer & UI ───────────────────────────────────────────────────────
    private lateinit var player: ExoPlayer
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var playerView: PlayerView
    private lateinit var playerListener: Player.Listener
    private lateinit var frameRateManager: FrameRateManager

    // ─── Flutter ──────────────────────────────────────────────────────────────
    private lateinit var flutterEngine: FlutterEngine
    private lateinit var flutterAppEngine: FlutterEngine
    private lateinit var methodChannel: MethodChannel
    private lateinit var methodUIChannel: MethodChannel
    private lateinit var flutterEngineId: String
    private lateinit var flutterAppEngineId: String

    // ─── Delegates ────────────────────────────────────────────────────────────
    private lateinit var playlistManager: PlaylistManager
    private lateinit var trackManager: TrackManager
    private lateinit var mediaSourceBuilder: MediaSourceBuilder
    private lateinit var subtitleStyleManager: SubtitleStyleManager
    private lateinit var volumeManager: VolumeManager
    private val metadataParser = MetadataParser()

    // ─── Media state ──────────────────────────────────────────────────────────
    private var playerSettings: Map<String, Any>? = null
    private var currentResolutionsMap: Map<String, String>? = null
    private var currentVideoUrl: String? = null
    private var currentVideoMimeType: String? = null
    private var currentHeaders: Map<String, String>? = null
    private var currentUserAgent: String? = null
    private var currentSubtitleTracks: List<Map<String, Any>>? = null
    private var currentAudioTracks: List<Map<String, Any>>? = null
    private var currentAudioTrackLabels: Map<String, String>? = null

    // ─── Player state ─────────────────────────────────────────────────────────
    private var isAfrEnabled: Boolean = false
    private var currentForceHighestBitrate: Boolean = true
    private var currentVideoQualityIndex: Int = 0
    private var currentVideoWidth: Int = 0
    private var currentVideoHeight: Int = 0
    private var currentMediaRequestToken: Any? = null
    private var lastActiveSubtitleId: String? = null
    private var stuckRetryCount = 0
    private var wakeLock: PowerManager.WakeLock? = null

    private val positionHandler = Handler(Looper.getMainLooper())
    private val aTag = "Media3Activity"
    private val activityChannelName   = "app_player_plugin_activity"
    private val activityChannelUIName = "ui_player_plugin_activity"

    // ══════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Called when the Activity is first created.
     *
     * Performs all major initializations:
     * - Retrieves FlutterEngine instances from the cache.
     * - Creates and configures ExoPlayer and PlayerView.
     * - Adds a FlutterFragment to display the UI overlay.
     * - Sets up MethodChannels for bidirectional communication.
     * - Initializes all delegate classes.
     * - Requests the first media item and applies initial settings.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (!initFlutterEngines()) return
        if (!initPlayer()) return
        if (!initFlutterFragment()) return

        initChannels()
        initDelegates()
        startPlaylist()
        applyInitialSettings()
    }

    /** Intercepts the system back button press and notifies Flutter. */
    override fun onBackPressed() {
        invokeOnBothChannels("onBack", null)
    }

    /**
     * Called when the Activity becomes inactive.
     *
     * Pauses the player, saves watch time, unregisters the volume observer,
     * and stops periodic position updates.
     */
    override fun onPause() {
        super.onPause()
        releaseWakeLock()
        if (this::volumeManager.isInitialized) volumeManager.unregister()
        if (this::player.isInitialized) {
            val hasVideo = player.currentTracks.groups.any {
                it.type == C.TRACK_TYPE_VIDEO && it.isSelected
            }
            if (hasVideo) {
                markWatchTime(playlistManager.playlistIndex)
                player.pause()
            }
        }
        positionHandler.removeCallbacks(positionRunnable)
    }

    /**
     * Called when the Activity becomes active again.
     *
     * Re-registers the volume observer and resumes periodic position updates
     * if the player is ready.
     */
    override fun onResume() {
        super.onResume()
        if (this::volumeManager.isInitialized) volumeManager.register()
        if (this::player.isInitialized && player.playWhenReady) {
            if (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING) {
                positionHandler.post(positionRunnable)
            }
        }
    }

    /**
     * Called before the Activity is destroyed.
     *
     * Releases all resources: stops the frame rate manager, releases the player,
     * destroys the FlutterEngine, and clears channel handlers.
     */
    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()

        positionHandler.removeCallbacks(positionRunnable)

        if (this::volumeManager.isInitialized) {
            volumeManager.unregister()
        }

        if (this::methodChannel.isInitialized) {
            methodChannel.invokeMethod("onActivityDestroyed", null)
            methodChannel.setMethodCallHandler(null)
        }
        if (this::methodUIChannel.isInitialized) {
            methodUIChannel.setMethodCallHandler(null)
        }

        if (this::playerView.isInitialized) {
            if (this::frameRateManager.isInitialized) frameRateManager.release()
            playerView.player = null
        }
        if (this::player.isInitialized) {
            if (this::playerListener.isInitialized) player.removeListener(playerListener)
            player.release()
        }

        // flutterAppEngine is intentionally not destroyed here — it is owned and cached
        // globally by the main Flutter app and must outlive this Activity.
        if (this::flutterEngine.isInitialized) {
            flutterEngine.lifecycleChannel.appIsDetached()
            flutterEngine.platformViewsController.detachFromView()
            if (this::flutterEngineId.isInitialized) {
                FlutterEngineCache.getInstance().remove(flutterEngineId)
            }
            flutterEngine.destroy()
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Initialization
    // ══════════════════════════════════════════════════════════════════════════

    private fun initFlutterEngines(): Boolean {
        flutterEngineId = intent.getStringExtra("flutter_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterEngine ID not found!"); finish(); return false
        }
        flutterEngine = FlutterEngineCache.getInstance().get(flutterEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterEngine '$flutterEngineId' not found in cache!"); finish(); return false
        }
        flutterAppEngineId = intent.getStringExtra("app_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterAPPEngine ID not found!"); finish(); return false
        }
        flutterAppEngine = FlutterEngineCache.getInstance().get(flutterAppEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterAPPEngine '$flutterAppEngineId' not found in cache!"); finish(); return false
        }
        return true
    }

    private fun initPlayer(): Boolean {
        playerView = PlayerView(this).apply {
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        }

        trackSelector = DefaultTrackSelector(this).apply {
            parameters = buildUponParameters()
                .setPreferredAudioMimeTypes(
                    "audio/true-hd", "audio/vnd.dts.hd", "audio/eac3",
                    "audio/vnd.dts", "audio/ac3", "audio/opus", "audio/mp4a-latm", "audio/mpeg"
                )
                .setAllowMultipleAdaptiveSelections(true)
                .build()
        }

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS * 4,
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS * 4,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS * 4,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS * 4
            )
            .setTargetBufferBytes(DefaultLoadControl.DEFAULT_TARGET_BUFFER_BYTES * 2)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setEnableDecoderFallback(true)

        player = ExoPlayer.Builder(this)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setSeekParameters(SeekParameters.EXACT)
            .setRenderersFactory(renderersFactory)
            .setStuckBufferingDetectionTimeoutMs(intent.getIntExtra("stuck_buffering_detection_timeout_ms", 240_000))
            .setStuckPlayingDetectionTimeoutMs(intent.getIntExtra("stuck_playing_detection_timeout_ms", 120_000))
            .setStuckPlayingNotEndingTimeoutMs(intent.getIntExtra("stuck_playing_not_ending_timeout_ms", 180_000))
            .setStuckSuppressedDetectionTimeoutMs(intent.getIntExtra("stuck_suppressed_detection_timeout_ms", 480_000))
            .build()

        frameRateManager = FrameRateManager(this, player, playerView)
        playerView.player = player

        setContentView(R.layout.activity_player)
        findViewById<FrameLayout>(R.id.media3_player_container).addView(playerView)
        return true
    }

    private fun initFlutterFragment(): Boolean {
        if (!flutterEngine.dartExecutor.isExecutingDart) {
            Log.e(aTag, "FlutterEngine is not executing Dart code!"); finish(); return false
        }
        return try {
            val fragment = FlutterFragment.withCachedEngine(flutterEngineId)
                .renderMode(io.flutter.embedding.android.RenderMode.texture)
                .transparencyMode(io.flutter.embedding.android.TransparencyMode.transparent)
                .build<FlutterFragment>()

            supportFragmentManager.beginTransaction()
                .replace(R.id.media3_flutter_container, fragment)
                .commitNowAllowingStateLoss()
            true
        } catch (e: Exception) {
            Log.e(aTag, "Error adding FlutterFragment: ${e.message}", e); finish(); false
        }
    }

    private fun initChannels() {
        methodChannel = MethodChannel(flutterAppEngine.dartExecutor.binaryMessenger, activityChannelName).also {
            it.setMethodCallHandler { call, result -> handleMethodCall(call, result, from = it) }
        }
        methodUIChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, activityChannelUIName).also {
            it.setMethodCallHandler { call, result -> handleMethodCall(call, result, from = it) }
        }
    }

    private fun initDelegates() {
        mediaSourceBuilder = MediaSourceBuilder(this)

        playlistManager = PlaylistManager(
            onRequestMedia  = { index -> requestMediaInfo(index) },
            onMarkWatchTime = { index -> markWatchTime(index) },
            onFinish        = { finish() }
        )

        trackManager = TrackManager(
            getPlayer        = { player },
            getTrackSelector = { trackSelector }
        )

        subtitleStyleManager = SubtitleStyleManager(
            playerView = playerView,
            onUiThread = { block -> runOnUiThread(block) }
        )

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        volumeManager = VolumeManager(
            context         = this,
            audioManager    = audioManager,
            onVolumeChanged = { state -> invokeOnBothChannels("onVolumeChanged", state) }
        )

        playerListener = createPlayerListener()
        player.addListener(playerListener)
    }

    private fun startPlaylist() {
        val index  = intent.getIntExtra("playlist_index", -1)
        val length = intent.getIntExtra("playlist_length", 0)

        playlistManager.playlistIndex  = index
        playlistManager.playlistLength = length

        if (index >= 0 && length > 0) {
            requestMediaInfo(index)
        } else {
            invokeOnBothChannels("onError", mapOf("code" to "INVALID_PLAYLIST", "message" to "Invalid playlist index or length"))
            finish()
        }
    }

    private fun applyInitialSettings() {
        val subtitleStyle = intent.getBundleExtra("subtitle_style")?.let { b ->
            listOfNotNull(
                b.getString("foregroundColor")?.let { "foregroundColor" to it },
                b.getString("backgroundColor")?.let { "backgroundColor" to it },
                b.getInt("edgeType", -1).takeIf { it != -1 }?.let { "edgeType" to it },
                b.getString("edgeColor")?.let { "edgeColor" to it },
                b.getDouble("textSizeFraction", 0.0).takeIf { it != 0.0 }?.let { "textSizeFraction" to it },
                b.getBoolean("applyEmbeddedStyles", false).takeIf { it }?.let { "applyEmbeddedStyles" to it },
                b.getString("windowColor")?.let { "windowColor" to it }
            ).toMap()
        }
        subtitleStyleManager.applySubtitleStyle(subtitleStyle)

        playerSettings = intent.getBundleExtra("player_settings")?.let { b ->
            listOfNotNull(
                b.getInt("videoQuality", -1).takeIf { it != -1 }?.let { "videoQuality" to it },
                b.getInt("width", -1).takeIf { it != -1 }?.let { "width" to it },
                b.getInt("height", -1).takeIf { it != -1 }?.let { "height" to it },
                b.getStringArrayList("preferredAudioLanguages")?.let { "preferredAudioLanguages" to it },
                b.getStringArrayList("preferredTextLanguages")?.let { "preferredTextLanguages" to it },
                "forcedAutoEnable"    to b.getBoolean("forcedAutoEnable", true),
                "isAfrEnabled"        to b.getBoolean("isAfrEnabled", false),
                "forceHighestBitrate" to b.getBoolean("forceHighestBitrate", true),
                "paginationEnable"    to b.getBoolean("paginationEnable", false),
                b.getInt("paginationThreshold", -1).takeIf { it != -1 }?.let { "paginationThreshold" to it },
                b.getBoolean("screenshotsEnable", false).takeIf { it }?.let { "screenshotsEnable" to it },
                b.getString("deviceLocale")?.let { "deviceLocale" to it }
            ).toMap()
        }
        applyTrackSelectionSettings(playerSettings)

        val initialVolumeState = volumeManager.getCurrentVolumeState()

        invokeOnBothChannels("onActivityReady", mapOf(
            "playlist"        to intent.getStringExtra("playlist"),
            "playlist_index"  to playlistManager.playlistIndex,
            "subtitle_style"  to subtitleStyle,
            "clock_settings"  to intent.getStringExtra("clock_settings"),
            "player_settings" to playerSettings,
            "locale_strings"  to intent.getStringExtra("locale_strings"),
            "subtitle_search" to intent.getStringExtra("subtitle_search"),
            "volume_state"    to initialVolumeState,
        ))
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Media loading
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Requests media item information from the main Flutter app.
     *
     * Invokes the `getMediaInfo` method via the `methodChannel` and, on success,
     * receives the URL, start position, and other data, then calls [loadAndPlayMedia].
     * @param index The index of the item in the playlist.
     */
    private fun requestMediaInfo(index: Int) {
        val token = Any().also { currentMediaRequestToken = it }

        invokeOnBothChannels("loadMediaInfo", mapOf("playlist_index" to index))

        methodChannel.invokeMethod("getMediaInfo", mapOf("index" to index), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (currentMediaRequestToken != token) {
                    Log.w(aTag, "Ignored outdated media info success response.")
                    return
                }
                if (result is Map<*, *>) {
                    val url = result["url"] as? String
                    var positionSec = (result["startPosition"] as? Number)?.toLong() ?: 0L
                    val durationSec = (result["duration"] as? Number)?.toLong() ?: 0L

                    currentHeaders          = result["headers"] as? Map<String, String>
                    currentUserAgent        = result["userAgent"] as? String
                    currentVideoMimeType    = result["mimeType"] as? String
                    currentResolutionsMap   = (result["resolutions"] as? Map<String, String>)
                        ?.entries?.associate { (label, url) -> url to label }
                    currentSubtitleTracks   = result["subtitles"] as? List<Map<String, Any>>
                    currentAudioTracks      = result["audioTracks"] as? List<Map<String, Any>>
                    currentAudioTrackLabels = result["audioTrackLabels"] as? Map<String, String>

                    if (durationSec > 0 && positionSec > 0 && durationSec - positionSec < 15) {
                        positionSec = 0L
                    }

                    if (url != null) {
                        resetPlayerViewAppearance()
                        val finalUrl = if (currentResolutionsMap?.isNotEmpty() == true) {
                            selectUrlByQuality(currentResolutionsMap!!, url)
                        } else url

                        loadAndPlayMedia(videoUrl = finalUrl, startPosition = positionSec * 1000)
                        invokeOnBothChannels("loadedMediaInfo", mapOf("playlist_index" to index))
                    } else {
                        invokeOnBothChannels("onError", mapOf("code" to "INVALID_URL", "message" to "Received null URL for playlist index $index"))
                        finish()
                    }
                } else {
                    invokeOnBothChannels("onError", mapOf("code" to "INVALID_FORMAT", "message" to "Invalid media info format"))
                    finish()
                }
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                if (currentMediaRequestToken != token) {
                    Log.w(aTag, "Ignored outdated media info error response.")
                    return
                }
                invokeOnBothChannels("onError", mapOf("code" to errorCode, "message" to "Error getting media info: $errorMessage"))
            }

            override fun notImplemented() {
                if (currentMediaRequestToken != token) {
                    Log.w(aTag, "Ignored outdated media info notImplemented response.")
                    return
                }
                invokeOnBothChannels("onError", mapOf("code" to "NOT_IMPLEMENTED", "message" to "getMediaInfo not implemented"))
                finish()
            }
        })
    }

    /**
     * Loads and starts playing media from the given URL.
     *
     * If a [PlayerTransferState] is provided, it is applied to preserve the player's
     * current state (position, settings) while switching to the new URL.
     */
    private fun loadAndPlayMedia(
        videoUrl: String,
        startPosition: Long = 0L,
        transferState: PlayerTransferState? = null
    ) {
        currentVideoUrl = videoUrl

        val (_, dataFactory) = mediaSourceBuilder.createDataSourceFactory(currentHeaders, currentUserAgent)

        if (transferState != null) {
            try {
                val idx   = transferState.currentMediaItemIndex
                val items = transferState.mediaItems.toMutableList()
                if (idx in items.indices) {
                    items[idx] = items[idx].buildUpon().setUri(Uri.parse(videoUrl)).build()
                    transferState.buildUpon()
                        .setMediaItems(ImmutableList.copyOf(items))
                        .build()
                        .setToPlayer(player)
                    player.prepare()
                } else {
                    loadWithoutTransferState(videoUrl, startPosition, dataFactory)
                }
            } catch (e: Exception) {
                loadWithoutTransferState(videoUrl, startPosition, dataFactory)
                invokeOnBothChannels("onError", mapOf("code" to "TRANSFER_STATE_FAILED", "message" to "Failed to apply transfer state: ${e.message}"))
            }
        } else {
            loadWithoutTransferState(videoUrl, startPosition, dataFactory)
        }
    }

    private fun loadWithoutTransferState(
        videoUrl: String,
        startPosition: Long,
        dataFactory: androidx.media3.datasource.DefaultDataSource.Factory
    ) {
        try {
            val source = mediaSourceBuilder.createCombinedMediaSource(
                videoUrl, currentVideoMimeType, currentSubtitleTracks, currentAudioTracks, dataFactory
            )
            player.setMediaSource(source, startPosition)
            player.prepare()
            player.play()
        } catch (e: Exception) {
            invokeOnBothChannels("onError", mapOf("code" to "PREPARATION_FAILED", "message" to "Failed to create media source: ${e.message}"))
        }
    }

    private fun rebuildMediaSourceAndResume() {
        val videoUrl = player.currentMediaItem?.localConfiguration?.uri?.toString() ?: return
        val state    = PlayerTransferState.fromPlayer(player)
        try {
            val (_, dataFactory) = mediaSourceBuilder.createDataSourceFactory(currentHeaders, currentUserAgent)
            val source = mediaSourceBuilder.createCombinedMediaSource(
                videoUrl, currentVideoMimeType, currentSubtitleTracks, currentAudioTracks, dataFactory
            )
            state.setToPlayer(player)
            player.setMediaSource(source, state.currentPosition)
            player.prepare()
        } catch (e: Exception) {
            invokeOnBothChannels("onError", mapOf("code" to "PREPARATION_FAILED", "message" to "Failed to create media source: ${e.message}"))
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MethodChannel handler
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * The central handler for method calls coming from Flutter.
     *
     * Distinguishes commands from the UI overlay and the main app and delegates
     * their execution to the appropriate player methods or delegate classes.
     */
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, from: MethodChannel) {
        if (!this::player.isInitialized) {
            reportErrorToOther(from, result, "PLAYER_NOT_READY", "Player not initialized.")
            return
        }

        when (call.method) {

            "loadMediaInfoState" -> {
                invokeOnBothChannels("loadMediaInfoState", mapOf(
                    "state"    to call.argument<String>("state"),
                    "progress" to call.argument<Number>("progress")
                ))
            }

            "playPause" -> {
                if (player.isPlaying) {
                    player.pause()
                    positionHandler.removeCallbacks(positionRunnable)
                } else {
                    player.play()
                    positionHandler.removeCallbacks(positionRunnable)
                    positionHandler.post(positionRunnable)
                }
                result.success(null)
            }

            "play" -> {
                player.play()
                positionHandler.removeCallbacks(positionRunnable)
                positionHandler.post(positionRunnable)
                result.success(null)
            }

            "pause" -> {
                player.pause()
                positionHandler.removeCallbacks(positionRunnable)
                result.success(null)
            }

            "seekTo" -> {
                val positionMs = call.argument<Number>("position")?.toLong()
                    ?: return reportErrorToOther(from, result, "INVALID_POSITION", "Position is null")

                val duration = player.duration
                val seekPos  = if (duration > 0) positionMs.coerceIn(0, duration) else positionMs.coerceAtLeast(0)
                player.seekTo(seekPos)

                val finalDuration = if (duration != C.TIME_UNSET) duration else 0L
                invokeOnBothChannels("onPositionChanged", mapOf(
                    "position"         to seekPos,
                    "bufferedPosition" to player.bufferedPosition.coerceAtLeast(seekPos),
                    "duration"         to finalDuration
                ))

                if (player.isPlaying) {
                    positionHandler.removeCallbacks(positionRunnable)
                    positionHandler.post(positionRunnable)
                }
                result.success(null)
            }

            "stop" -> { finish(); result.success(null) }

            "sleepTimerExec" -> {
                methodChannel.invokeMethod("sleepTimerExec", null)
                finish()
                result.success(null)
            }

            "selectTrack" -> {
                val trackType  = call.argument<Int>("trackType")  ?: return reportErrorToOther(from, result, "INVALID_TYPE", "Missing or invalid trackType")
                val groupIndex = call.argument<Int>("groupIndex") ?: return reportErrorToOther(from, result, "INVALID_INDEX", "Group index is null")
                val trackIndex = call.argument<Int>("trackIndex") ?: return reportErrorToOther(from, result, "INVALID_INDEX", "Track index is null")

                val error = trackManager.selectTrack(trackType, groupIndex, trackIndex)
                if (error != null) reportErrorToOther(from, result, "SELECTION_ERROR", error)
                else result.success(null)
            }

            "selectExternalVideoTrack" -> {
                val url = call.argument<String?>("url")
                if (currentResolutionsMap != null) handleQualitySelection(url, result, from)
                else reportErrorToOther(from, result, "NO_RESOLUTIONS", "Resolution tracks are not available for selection")
            }

            "getThumbnail" -> {
                if (playerSettings?.get("screenshotsEnable") as? Boolean != true) {
                    result.error("SCREENSHOTS_DISABLED", "Screenshot functionality is disabled", null)
                    return
                }
                val uri = call.argument<String>("uri") ?: return result.error("INVALID_ARGUMENT", "URI is null", null)
                val timeInSeconds = call.argument<Number>("timeInSeconds")?.toDouble()

                lifecycleScope.launch(Dispatchers.Main) {
                    val bytes = MediaUtils.getThumbnail(this@PlayerActivity, uri, timeInSeconds)
                    if (bytes != null) {
                        result.success(bytes)
                        invokeOnOtherChannel("onScreenshotTaken", mapOf("bytes" to bytes, "playlistIndex" to playlistManager.playlistIndex), from)
                    } else {
                        result.error("EXTRACTION_ERROR", "Failed to extract thumbnail", null)
                    }
                }
            }

            "getMetadata" -> {
                val meta = metadataParser.getCurrentMetadata(player)
                invokeOnOtherChannel("onMetadataChanged", meta, from)
                result.success(meta)
            }

            "getCurrentTracks" -> {
                val tracks = getCurrentTracksFromDelegate()
                invokeOnOtherChannel("setCurrentTracks", tracks, from)
                result.success(tracks)
            }

            "setResizeMode" -> {
                val modeName = call.argument<String>("mode")
                val resizeMode = when (modeName) {
                    "FIT"          -> AspectRatioFrameLayout.RESIZE_MODE_FIT
                    "FILL"         -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                    "ZOOM"         -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    "FIXED_WIDTH"  -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
                    "FIXED_HEIGHT" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
                    else           -> null
                }
                if (resizeMode != null) {
                    playerView.resizeMode = resizeMode
                    val res = mapOf("zoom" to modeName)
                    invokeOnOtherChannel("setCurrentResizeMode", res, from)
                    result.success(res)
                } else {
                    reportErrorToOther(from, result, "INVALID_MODE", "Invalid resize mode: $modeName")
                }
            }

            "setScale" -> {
                val scaleX = call.argument<Double>("scaleX")?.toFloat() ?: 1.0f
                val scaleY = call.argument<Double>("scaleY")?.toFloat() ?: 1.0f
                applyZoom(scaleX, scaleY) { success ->
                    if (success) {
                        val res = mapOf("zoom" to "SCALE")
                        invokeOnOtherChannel("setCurrentResizeMode", res, from)
                        result.success(res)
                    } else {
                        reportErrorToOther(from, result, "VIEW_NOT_INITIALIZED", "videoSurfaceView is null")
                    }
                }
            }

            "setSpeed" -> {
                val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                runOnUiThread { player.setPlaybackSpeed(speed) }
                val res = mapOf("speed" to speed)
                invokeOnOtherChannel("setCurrentSpeed", res, from)
                result.success(res)
            }

            "setRepeatMode" -> {
                val modeName = call.argument<String>("mode") ?: "REPEAT_MODE_OFF"
                @Player.RepeatMode val mode = when (modeName) {
                    "REPEAT_MODE_ONE" -> Player.REPEAT_MODE_ONE
                    "REPEAT_MODE_ALL" -> Player.REPEAT_MODE_ALL
                    else              -> Player.REPEAT_MODE_OFF
                }
                runOnUiThread {
                    playlistManager.setRepeatMode(mode)
                    player.repeatMode = if (mode == Player.REPEAT_MODE_ONE) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
                }
                invokeOnOtherChannel("setRepeatMode", mapOf("status" to "success", "mode" to modeName), from)
                result.success(mapOf("status" to "success", "mode" to modeName))
            }

            "setShuffleMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread { playlistManager.setShuffleMode(enabled) }
                invokeOnOtherChannel("setShuffleMode", mapOf("status" to "success", "shuffleEnabled" to enabled), from)
                result.success(mapOf("status" to "success", "shuffleEnabled" to enabled))
            }

            "setSubtitleStyle" -> {
                val applied = subtitleStyleManager.applySubtitleStyle(call.arguments as? Map<String, Any>)
                invokeOnOtherChannel("updateSubtitleStyle", applied, from)
                result.success(applied)
            }

            "saveClockSettings" -> {
                invokeOnOtherChannel("saveClockSettings", mapOf("clock_settings" to call.argument<String?>("clock_settings")), from)
                result.success(null)
            }

            "savePlayerSettings" -> {
                try {
                    playerSettings = call.arguments as? Map<String, Any>
                    runOnUiThread { applyTrackSelectionSettings(playerSettings) }
                    invokeOnOtherChannel("savePlayerSettings", playerSettings, from)
                    result.success(true)
                } catch (e: Exception) {
                    reportErrorToOther(from, result, "NATIVE_ERROR", "Failed to apply settings", e.message)
                }
            }

            "onLoadMore" -> { methodChannel.invokeMethod("onLoadMore", null); result.success(null) }

            "playNext"     -> { runOnUiThread { playlistManager.playNext() };     result.success(null) }
            "playPrevious" -> { runOnUiThread { playlistManager.playPrevious() }; result.success(null) }

            "playSelectedIndex" -> {
                val newIndex = call.argument<Int>("index")
                if (newIndex != null && playlistManager.playSelectedIndex(newIndex)) {
                    if (player.isPlaying) { player.pause(); positionHandler.removeCallbacks(positionRunnable) }
                    result.success(null)
                } else {
                    reportErrorToOther(from, result, "INVALID_INDEX", "Invalid playlist index: $newIndex")
                }
            }

            /**
             * Handles the "updatePlaylist" method call from Flutter.
             *
             * This method is invoked when the main Flutter application adds new items
             * to the playlist. It updates the internal playlistLength and notifies both
             * the main app and the UI overlay about the updated playlist.
             */
            "updatePlaylist" -> {
                playlistManager.playlistLength = call.argument<Int>("playlist_length") ?: playlistManager.playlistLength
                invokeOnOtherChannel("onPlaylistUpdated", mapOf(
                    "playlist"       to call.argument<String>("playlist"),
                    "playlist_index" to playlistManager.playlistIndex
                ), from)
                result.success(null)
            }

            /**
             * Handles the "onItemRemoved" method call from Flutter.
             *
             * This method is invoked when an item is removed from the playlist. It adjusts
             * playlistLength and playlistIndex accordingly. If the currently playing item
             * is removed, it attempts to play the next available item or closes the player
             * if the playlist is empty.
             */
            "onItemRemoved" -> {
                val removedIndex = call.argument<Int>("index") ?: -1
                val newLength    = call.argument<Int>("playlist_length") ?: (playlistManager.playlistLength - 1)
                if (removedIndex != -1) {
                    val newIdx = playlistManager.handleItemRemoved(removedIndex, newLength)
                    invokeOnOtherChannel("onItemRemoved", mapOf(
                        "playlist"       to call.argument<String>("playlist"),
                        "playlist_index" to newIdx
                    ), from)
                }
                result.success(null)
            }

            "setExternalSubtitles" -> {
                val newSubtitles = call.argument<List<Map<String, Any>>>("subtitleTracks")
                    ?: return reportErrorToOther(from, result, "INVALID_SUBTITLES", "Subtitles list is null")

                val existing     = currentSubtitleTracks ?: emptyList()
                val existingUrls = existing.mapNotNull { it["url"] as? String }.toSet()
                val unique       = newSubtitles.filter { (it["url"] as? String)?.let { u -> u !in existingUrls } == true }

                if (unique.isNotEmpty()) {
                    currentSubtitleTracks = existing + unique
                    rebuildMediaSourceAndResume()
                }
                result.success(null)
            }

            "setExternalAudio" -> {
                val newAudioTracks = call.argument<List<Map<String, Any>>>("audioTracks")
                    ?: return reportErrorToOther(from, result, "INVALID_AUDIO", "Audio tracks list is null")

                currentAudioTracks = (currentAudioTracks ?: emptyList()) + newAudioTracks
                rebuildMediaSourceAndResume()
                result.success(null)
            }

            "onReceiveInfoText" -> {
                invokeOnOtherChannel("onCustomInfoUpdate", mapOf("text" to call.argument<String>("text")), from)
                result.success(null)
            }

            "findSubtitles" -> {
                invokeOnOtherChannel("onFindSubtitlesRequested", mapOf("mediaId" to call.argument<String>("mediaId")), from)
                result.success(null)
            }

            "onSubtitleSearchStateChanged" -> {
                invokeOnOtherChannel("onSubtitleSearchStateChanged", call.arguments as? Map<String, Any>, from)
                result.success(null)
            }

            "getRefreshRateInfo" -> result.success(frameRateManager.getRefreshRateInfo())

            "setManualFrameRate" -> {
                if (isAfrEnabled) return reportErrorToOther(from, result, "AFR_ENABLED", "Cannot set manual rate when AFR is enabled")
                val rate = call.argument<Double>("rate")?.toFloat()
                    ?: return reportErrorToOther(from, result, "INVALID_RATE", "Rate is null")
                frameRateManager.setManualRefreshRate(rate)
                result.success(null)
            }

            "getVolume" -> result.success(volumeManager.getCurrentVolumeState())

            "setVolume" -> {
                val volume = call.argument<Double>("volume")
                    ?: return reportErrorToOther(from, result, "INVALID_VOLUME", "Volume is null")
                volumeManager.setVolume(volume)
                result.success(null)
            }

            "setMute" -> {
                val mute = call.argument<Boolean>("mute")
                    ?: return reportErrorToOther(from, result, "INVALID_MUTE", "Mute is null")
                volumeManager.setMute(mute)
                result.success(null)
            }

            "toggleMute" -> {
                try {
                    result.success(mapOf("isMute" to volumeManager.toggleMute()))
                } catch (e: UnsupportedOperationException) {
                    reportErrorToOther(from, result, "UNSUPPORTED_API", e.message ?: "")
                }
            }

            else -> {
                reportErrorToOther(from, result, "NOT_IMPLEMENTED", "Method ${call.method} not implemented in PlayerActivity channel.")
                result.notImplemented()
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Player listener
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Creates and returns a listener for player events.
     *
     * Reacts to state changes, errors, track changes, and other ExoPlayer events,
     * notifying the Flutter side accordingly.
     */
    private fun createPlayerListener(): Player.Listener = object : Player.Listener {

        private fun updateWakeLock() {
            val hasVideo = player.currentTracks.groups.any { it.type == C.TRACK_TYPE_VIDEO && it.isSelected }
            if (player.isPlaying && hasVideo) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) = updateWakeLock()

        override fun onPlaybackStateChanged(playbackState: Int) {
            val state = notifyStateChanged(player)

            if (playbackState == Player.STATE_ENDED) playlistManager.handleTrackEnded()

            if ((state == "playing" || state == "buffering") && playbackState != Player.STATE_ENDED) {
                positionHandler.removeCallbacks(positionRunnable)
                positionHandler.post(positionRunnable)
            } else {
                positionHandler.removeCallbacks(positionRunnable)
            }
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (playWhenReady) dismissScreensaver()
            notifyStateChanged(player)
            if (playWhenReady && (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING)) {
                positionHandler.removeCallbacks(positionRunnable)
                positionHandler.post(positionRunnable)
            } else {
                positionHandler.removeCallbacks(positionRunnable)
            }
        }

        override fun onTimelineChanged(timeline: Timeline, reason: Int) {
            invokeOnBothChannels("onMetadataChanged", metadataParser.getCurrentMetadata(player))
        }

        override fun onMetadata(metadata: Metadata) {
            val update = metadataParser.parseStreamingMetadata(metadata)
            if (update.isNotEmpty()) invokeOnBothChannels("onStreamingMetadataUpdated", update)
        }

        override fun onTracksChanged(tracks: Tracks) {
            sendCurrentTracksToDart()

            val currentSubtitle = tracks.groups
                .firstOrNull { it.type == C.TRACK_TYPE_TEXT && it.isSelected }
                ?.let { group ->
                    val selectedIndex = (0 until group.length).firstOrNull { group.isTrackSelected(it) }
                    if (selectedIndex != null) group.getTrackFormat(selectedIndex) else null
                }

            val currentSubtitleId = currentSubtitle?.id

            if (currentSubtitleId != lastActiveSubtitleId) {
                if (currentSubtitle != null) {
                    val externalUrls = currentSubtitleTracks?.mapNotNull { it["url"] as? String }?.toSet() ?: emptySet()
                    val isExternal = externalUrls.any { url -> currentSubtitle.id?.contains(url) == true }
                    if (isExternal) methodChannel.invokeMethod("onExternalSubtitleSelected", null)
                }
            }
            lastActiveSubtitleId = currentSubtitleId

            if (isAfrEnabled) frameRateManager.onPossibleFrameRateChange()
        }

        override fun onRenderedFirstFrame() {
            updateWakeLock()
            sendCurrentTracksToDart()
            if (isAfrEnabled) frameRateManager.onPossibleFrameRateChange()
        }

        override fun onPlayerError(error: PlaybackException) {
            val stuckError = error.cause as? StuckPlayerException
            if (stuckError != null) {
                if (stuckRetryCount > 1) {
                    invokeOnBothChannels("onError", mapOf("code" to error.errorCodeName, "message" to error.localizedMessage))
                    stuckRetryCount = 0
                    positionHandler.removeCallbacks(positionRunnable)
                    return
                }
                stuckRetryCount++
                Log.d(aTag, "Stuck retry attempt $stuckRetryCount for stuckType=${stuckError.stuckType}")
                try {
                    val transferState = PlayerTransferState.fromPlayer(player)
                    transferState.setToPlayer(player)
                    player.prepare()
                    if (transferState.playWhenReady) player.play()
                    Handler(Looper.getMainLooper()).postDelayed({
                        if (player.isPlaying) { stuckRetryCount = 0; Log.d(aTag, "Stuck recovered after retry") }
                    }, 3000)
                } catch (e: Exception) {
                    Log.e(aTag, "Failed to recover from stuck: ${e.message}")
                    stuckRetryCount = 0
                    player.seekToDefaultPosition(); player.prepare(); player.play()
                }
                return
            }

            if (isRecoverableHlsError(error)) {
                try {
                    val transferState = PlayerTransferState.fromPlayer(player)
                    transferState.setToPlayer(player)
                    player.prepare()
                    if (transferState.playWhenReady) player.play()
                } catch (e: Exception) {
                    Log.e("PlayerError", "Failed to restore state: ${e.message}")
                    player.seekToDefaultPosition(); player.prepare(); player.play()
                }
                return
            }

            invokeOnBothChannels("onError", mapOf("code" to error.errorCodeName, "message" to error.localizedMessage))
            positionHandler.removeCallbacks(positionRunnable)
        }

        private fun sendCurrentTracksToDart() {
            invokeOnBothChannels("setCurrentTracks", getCurrentTracksFromDelegate())
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Helper methods
    // ══════════════════════════════════════════════════════════════════════════

    private fun getCurrentTracksFromDelegate() = trackManager.getCurrentTracks(
        currentSubtitleTracks, currentAudioTracks, currentAudioTrackLabels,
        currentResolutionsMap, currentVideoUrl
    )

    private fun isRecoverableHlsError(e: PlaybackException): Boolean {
        var cause: Throwable? = e
        while (cause != null) {
            if (cause is androidx.media3.exoplayer.source.BehindLiveWindowException ||
                cause is androidx.media3.exoplayer.hls.playlist.HlsPlaylistTracker.PlaylistResetException
            ) return true
            cause = cause.cause
        }
        return false
    }

    private fun markWatchTime(playlistIndex: Int) {
        if (!this::player.isInitialized) { Log.e(aTag, "markWatchTime: Player not initialized"); return }
        if (player.isCurrentMediaItemLive) { Log.d(aTag, "markWatchTime: Skipping for live stream"); return }

        val currentPosition = player.currentPosition
        val duration        = player.duration.takeIf { it != C.TIME_UNSET } ?: 0L

        Handler(Looper.getMainLooper()).post {
            invokeOnBothChannels("onWatchTimeMarked", mapOf(
                "position_ms"    to currentPosition,
                "duration_ms"    to duration,
                "playlist_index" to playlistIndex
            ))
        }
    }

    private fun applyZoom(scaleX: Float, scaleY: Float, onComplete: (Boolean) -> Unit) {
        val videoSurfaceView = playerView.videoSurfaceView
        if (videoSurfaceView == null) { onComplete(false); return }

        val clampedX = scaleX.coerceIn(0.1f, 3.0f)
        val clampedY = scaleY.coerceIn(0.1f, 3.0f)
        runOnUiThread {
            videoSurfaceView.pivotX = videoSurfaceView.width / 2f
            videoSurfaceView.pivotY = videoSurfaceView.height / 2f
            videoSurfaceView.animate()
                .scaleX(clampedX).scaleY(clampedY)
                .setDuration(300)
                .withEndAction { onComplete(true) }
                .start()
        }
    }

    private fun resetPlayerViewAppearance() {
        player.setPlaybackSpeed(1.0f)
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        playerView.videoSurfaceView?.let { it.scaleX = 1.0f; it.scaleY = 1.0f }
    }

    private fun applyTrackSelectionSettings(settings: Map<String, Any>?) {
        val newAfrState = settings?.get("isAfrEnabled") as? Boolean ?: false
        if (isAfrEnabled && !newAfrState) frameRateManager.release()
        isAfrEnabled = newAfrState

        val s = settings ?: emptyMap()
        currentVideoQualityIndex   = (s["videoQuality"] as? Number)?.toInt() ?: currentVideoQualityIndex
        currentVideoWidth          = (s["width"] as? Number)?.toInt() ?: currentVideoWidth
        currentVideoHeight         = (s["height"] as? Number)?.toInt() ?: currentVideoHeight
        currentForceHighestBitrate = s["forceHighestBitrate"] as? Boolean ?: currentForceHighestBitrate

        val b = trackSelector.parameters.buildUpon()

        when (currentVideoQualityIndex) {
            0 -> b.clearVideoSizeConstraints().setForceLowestBitrate(false).setForceHighestSupportedBitrate(currentForceHighestBitrate)
            4 -> b.clearVideoSizeConstraints().setForceHighestSupportedBitrate(false).setForceLowestBitrate(true)
            else -> if (currentVideoWidth > 0 && currentVideoHeight > 0) {
                b.setMaxVideoSize(currentVideoWidth, currentVideoHeight).setForceLowestBitrate(false).setForceHighestSupportedBitrate(currentForceHighestBitrate)
            } else {
                b.clearVideoSizeConstraints().setForceLowestBitrate(false).setForceHighestSupportedBitrate(currentForceHighestBitrate)
            }
        }

        (s["preferredAudioLanguages"] as? List<*>)?.let { langs ->
            b.setPreferredAudioLanguages(*langs.mapNotNull { it as? String }.toTypedArray())
        }
        (s["preferredTextLanguages"] as? List<*>)?.let { langs ->
            b.setPreferredTextLanguages(*langs.mapNotNull { it as? String }.toTypedArray())
        }

        val subtitlesEnabled = s["forcedAutoEnable"] as? Boolean ?: true
        if (subtitlesEnabled) {
            // Use declarative parameter — works immediately even before media is loaded,
            // without relying on currentMappedTrackInfo renderer indices (which are null at onCreate).
            b.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
            b.setPreferredTextRoleFlags(C.ROLE_FLAG_MAIN or C.ROLE_FLAG_SUBTITLE)
        } else {
            b.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
        }

        trackSelector.parameters = b.build()
    }

    private fun selectUrlByQuality(resolutionsMap: Map<String, String>, defaultUrl: String): String {
        if (resolutionsMap.isEmpty()) return defaultUrl
        return when (currentVideoQualityIndex) {
            0 -> resolutionsMap.entries.sortedByDescending { metadataParser.parseQuality(it.value, it.key) }.firstOrNull()?.key ?: defaultUrl
            4 -> resolutionsMap.entries.sortedBy { metadataParser.parseQuality(it.value, it.key) }.firstOrNull()?.key ?: defaultUrl
            else -> if (currentVideoHeight > 0) {
                val sorted = resolutionsMap.entries.map { metadataParser.parseQuality(it.value, it.key) to it.key }.sortedBy { it.first }
                sorted.firstOrNull { it.first >= currentVideoHeight }?.second ?: sorted.lastOrNull()?.second ?: defaultUrl
            } else defaultUrl
        }
    }

    private fun handleQualitySelection(url: String?, result: MethodChannel.Result, from: MethodChannel) {
        if (currentResolutionsMap.isNullOrEmpty()) {
            reportErrorToOther(from, result, "NO_RESOLUTIONS", "Resolution tracks are not available for selection")
            return
        }
        val availableUrls = currentResolutionsMap!!.keys.toList()
        val selectedUrl   = when {
            url == null             -> availableUrls.firstOrNull()
            availableUrls.contains(url) -> url
            else -> return reportErrorToOther(from, result, "INVALID_URL", "Provided URL is not among available resolution tracks")
        } ?: return reportErrorToOther(from, result, "NO_VALID_URL", "No valid URL found for selection", null)

        try {
            loadAndPlayMedia(videoUrl = selectedUrl, transferState = PlayerTransferState.fromPlayer(player))
            result.success(null)
        } catch (e: Exception) {
            reportErrorToOther(from, result, "SOURCE_SWITCH_ERROR", "Failed to switch source: ${e.message}")
        }
    }

    private fun notifyStateChanged(player: Player): String {
        val state = when (player.playbackState) {
            Player.STATE_IDLE      -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY     -> if (player.playWhenReady) "playing" else "paused"
            Player.STATE_ENDED     -> "ended"
            else                   -> "unknown"
        }
        val repeatModeString = when (playlistManager.currentRepeatMode) {
            Player.REPEAT_MODE_ONE -> "REPEAT_MODE_ONE"
            Player.REPEAT_MODE_ALL -> "REPEAT_MODE_ALL"
            else                   -> "REPEAT_MODE_OFF"
        }
        invokeOnBothChannels("onStateChanged", mapOf(
            "state"          to state,
            "isLive"         to player.isCurrentMediaItemLive,
            "isSeekable"     to player.isCurrentMediaItemSeekable,
            "playlist_index" to playlistManager.playlistIndex,
            "speed"          to player.playbackParameters.speed,
            "repeatMode"     to repeatModeString,
            "shuffleEnabled" to playlistManager.isShuffleModeEnabled
        ))
        return state
    }

    private val positionRunnable = object : Runnable {
        override fun run() {
            if (!isFinishing && !isDestroyed && this@PlayerActivity::player.isInitialized &&
                player.playbackState != Player.STATE_IDLE
            ) {
                val durationMs = player.duration
                invokeOnBothChannels("onPositionChanged", mapOf(
                    "position"         to player.currentPosition,
                    "bufferedPosition" to player.bufferedPosition,
                    "duration"         to if (durationMs != C.TIME_UNSET) durationMs else 0L
                ))
                positionHandler.postDelayed(this, 500)
            } else {
                // Player is idle or activity is finishing — stop updates silently, no error.
                Log.d(aTag, "PositionRunnable: Stopping updates (activity finishing or player not ready).")
            }
        }
    }

    private fun dismissScreensaver() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "MyApp:PlayerWakeLock"
        )
        wakeLock?.acquire(3000)
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun invokeOnBothChannels(method: String, arguments: Any?) {
        try { methodChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e(aTag, "invokeOnBothChannels: error on methodChannel: ${e.message}") }
        try { methodUIChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e(aTag, "invokeOnBothChannels: error on methodUIChannel: ${e.message}") }
    }

    private fun invokeOnOtherChannel(method: String, arguments: Any?, from: MethodChannel) {
        try { if (from != methodChannel) methodChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e(aTag, "invokeOnOtherChannel error calling $method: ${e.message}") }
        try { if (from != methodUIChannel) methodUIChannel.invokeMethod(method, arguments) } catch (e: Exception) { Log.e(aTag, "invokeOnOtherChannel error calling $method: ${e.message}") }
    }

    private fun reportErrorToOther(from: MethodChannel, result: MethodChannel.Result, code: String, message: String, details: Any? = null) {
        invokeOnOtherChannel("onError", mapOf("code" to code, "message" to message), from = from)
        result.error(code, message, details)
    }
}

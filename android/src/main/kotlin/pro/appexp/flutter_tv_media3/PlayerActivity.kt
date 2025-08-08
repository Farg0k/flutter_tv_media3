package pro.appexp.flutter_tv_media3

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.net.toUri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.rtmp.RtmpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.source.SingleSampleMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.CaptionStyleCompat
import androidx.media3.ui.PlayerView
import androidx.media3.ui.SubtitleView
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
import androidx.media3.extractor.metadata.emsg.EventMessage
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.extractor.metadata.id3.ApicFrame
import androidx.media3.extractor.metadata.id3.CommentFrame
import androidx.media3.extractor.metadata.id3.PrivFrame
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import androidx.media3.extractor.metadata.id3.UrlLinkFrame
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.net.Uri
import com.google.common.collect.ImmutableList

/**
 * The main Activity responsible for video playback and displaying the UI.
 *
 * This Activity performs the following key tasks:
 * - **ExoPlayer Initialization:** Creates and configures an ExoPlayer instance,
 *   including the track selector, media source factories, and load control.
 * - **FlutterEngine Management:** Retrieves two `FlutterEngine` instances from the cache:
 *   1. `flutterEngine` for the UI overlay, which is displayed in a FlutterFragment.
 *   2. `flutterAppEngine` for communication with the main Flutter application.
 * - **MethodChannel Setup:** Establishes two channels for bidirectional communication:
 *   one with the UI overlay (`methodUIChannel`) and one with the main app (`methodChannel`).
 * - **Lifecycle Handling:** Manages the creation, pausing, and destruction of the
 *   player and the FlutterEngine.
 * - **Playback Control:** Handles commands received via the MethodChannel (play, pause,
 *   seek, track selection, etc.).
 * - **AFR (Auto Frame Rate):** Uses the [Utils] class to implement auto frame
 *   rate switching logic.
 */
@UnstableApi
class PlayerActivity : AppCompatActivity() {

    private lateinit var player: ExoPlayer
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var playerView: PlayerView
    private lateinit var flutterEngine: FlutterEngine
    private lateinit var flutterAppEngine: FlutterEngine
    private lateinit var methodChannel: MethodChannel
    private lateinit var methodUIChannel: MethodChannel
    private lateinit var playerListener: Player.Listener
    private lateinit var frameRateManager: FrameRateManager

    private lateinit var dataSourceFactory: DefaultDataSource.Factory
    private lateinit var mediaSourceFactory: DefaultMediaSourceFactory
    private lateinit var extractorsFactory: ExtractorsFactory
    private lateinit var httpDataSourceFactory: DefaultHttpDataSource.Factory

    private var startPosition: Long = 0
    private var hasSeekedToStartPosition = false


    private var currentResolutionsMap: Map<String, String>? = null
    private var currentHeaders: Map<String, String>? = null
    private var currentUserAgent: String? = null
    private var currentSubtitleTracks: List<Map<String, Any>>? = null
    private var currentAudioTracks: List<Map<String, Any>>? = null

    private var playlistIndex: Int = -1
    private var playlistLength: Int = 0

    private val positionHandler = Handler(Looper.getMainLooper())
    private val aTag = "Media3Activity"
    private lateinit var flutterEngineId: String;
    private lateinit var flutterAppEngineId: String;
    private val activityChannelName = "app_player_plugin_activity"
    private val activityChannelUIName = "ui_player_plugin_activity"
    private val defaultUserAgent =
        "FTVMedia3/1.0 (Android ${android.os.Build.VERSION.RELEASE}) ExoPlayerLib/${androidx.media3.common.MediaLibraryInfo.VERSION}"

    @Player.RepeatMode
    private var currentRepeatMode: Int = Player.REPEAT_MODE_OFF
    private var isShuffleModeEnabled: Boolean = false
    private var shuffledIndices: List<Int> = emptyList()
    private var currentShuffledIndex: Int = -1

    private var currentVideoQualityIndex: Int = 0
    private var currentVideoWidth: Int = 0
    private var currentVideoHeight: Int = 0
    private var currentMediaRequestToken: Any? = null
    private var isAfrEnabled: Boolean = false

    /**
     * Called when the Activity is first created.
     *
     * Performs all major initializations:
     * - Retrieves `FlutterEngine` instances from the cache.
     * - Creates and configures `ExoPlayer` and `PlayerView`.
     * - Adds a `FlutterFragment` to display the UI overlay.
     * - Sets up `MethodChannel` for communication.
     * - Requests information for the first media item to be played.
     * - Applies initial subtitle and player settings.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngineId = intent.getStringExtra("flutter_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterEngine ID not found!")
            finish()
            return
        }

        flutterEngine = FlutterEngineCache.getInstance().get(flutterEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterEngine with ID '$flutterEngineId' not found in cache!")
            finish()
            return
        }

        flutterAppEngineId = intent.getStringExtra("app_engine_id") ?: run {
            Log.e(aTag, "FATAL: FlutterAPPEngine ID not found!")
            finish()
            return
        }
        flutterAppEngine = FlutterEngineCache.getInstance().get(flutterAppEngineId) ?: run {
            Log.e(aTag, "FATAL: FlutterEngine with ID '$flutterAppEngineId' not found in cache!")
            finish()
            return
        }

        playerView = PlayerView(this).apply {
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        }

        httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setUserAgent(defaultUserAgent)
        dataSourceFactory = DefaultDataSource.Factory(this, httpDataSourceFactory)

        extractorsFactory = DefaultExtractorsFactory()
            .setConstantBitrateSeekingEnabled(true)

        trackSelector = DefaultTrackSelector(this)
        val parameters = trackSelector.buildUponParameters()
            .setPreferredAudioMimeTypes(
                MimeTypes.AUDIO_TRUEHD,
                MimeTypes.AUDIO_DTS_HD,
                MimeTypes.AUDIO_E_AC3,
                MimeTypes.AUDIO_DTS,
                MimeTypes.AUDIO_AC3,
                MimeTypes.AUDIO_OPUS,
                MimeTypes.AUDIO_AAC,
                MimeTypes.AUDIO_MPEG
            )
            .setAllowMultipleAdaptiveSelections(true)
            .build()
        trackSelector.parameters = parameters

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(5000, 60000, 2500, 5000)
            .setTargetBufferBytes(50 * 1024 * 1024)
            .build()

        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setEnableDecoderFallback(true)

        mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory, extractorsFactory)

        player = ExoPlayer.Builder(this)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setSeekParameters(SeekParameters.EXACT)
            .setRenderersFactory(renderersFactory)
            .build()

        frameRateManager = FrameRateManager(this, player, playerView)

        playerView.player = player
        setContentView(R.layout.activity_player)
        findViewById<FrameLayout>(R.id.media3_player_container).addView(playerView)

        try {
            if (!flutterEngine.dartExecutor.isExecutingDart) {
                Log.e(aTag, "FlutterEngine is not executing Dart code!")
                finish()
                return
            }

            val flutterFragment = FlutterFragment.withCachedEngine(flutterEngineId)
                .renderMode(io.flutter.embedding.android.RenderMode.texture)
                .transparencyMode(io.flutter.embedding.android.TransparencyMode.transparent)
                .build<FlutterFragment>()

            supportFragmentManager.beginTransaction()
                .replace(R.id.media3_flutter_container, flutterFragment)
                .commitNowAllowingStateLoss()

        } catch (e: Exception) {
            Log.e(aTag, "Error adding FlutterFragment: ${e.message}", e)
            finish()
            return
        }

        methodChannel =
            MethodChannel(flutterAppEngine.dartExecutor.binaryMessenger, activityChannelName)
        methodChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result, from = methodChannel)
        }

        methodUIChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, activityChannelUIName)
        methodUIChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result, from = methodUIChannel)
        }

        playlistIndex = intent.getIntExtra("playlist_index", -1)
        playlistLength = intent.getIntExtra("playlist_length", 0)

        if (playlistIndex >= 0 && playlistLength > 0) {
            requestMediaInfo(playlistIndex)
        } else {
            invokeOnBothChannels(
                "onError", mapOf(
                    "code" to "INVALID_PLAYLIST",
                    "message" to "Invalid playlist index or length"
                )
            )
            finish()
        }

        playerListener = createPlayerListener()
        player.addListener(playerListener)

        val subtitleStyle: Map<String, Any>? =
            intent.getBundleExtra("subtitle_style")?.let { subtitleBundle ->
                listOfNotNull(
                    subtitleBundle.getString("foregroundColor")?.let { "foregroundColor" to it },
                    subtitleBundle.getString("backgroundColor")?.let { "backgroundColor" to it },
                    subtitleBundle.getInt("edgeType", -1).takeIf { it != -1 }
                        ?.let { "edgeType" to it },
                    subtitleBundle.getString("edgeColor")?.let { "edgeColor" to it },
                    subtitleBundle.getDouble("textSizeFraction", 0.0).takeIf { it != 0.0 }
                        ?.let { "textSizeFraction" to it },
                    subtitleBundle.getBoolean("applyEmbeddedStyles", false).takeIf { it }
                        ?.let { "applyEmbeddedStyles" to it },
                    subtitleBundle.getString("windowColor")?.let { "windowColor" to it }
                ).toMap()
            }

        applySubtitleStyle(subtitleStyle)

        val playerSettings: Map<String, Any>? =
            intent.getBundleExtra("player_settings")?.let { bundle ->
                listOfNotNull(
                    bundle.getInt("videoQuality", -1).takeIf { it != -1 }
                        ?.let { "videoQuality" to it },
                    bundle.getInt("width", -1).takeIf { it != -1 }?.let { "width" to it },
                    bundle.getInt("height", -1).takeIf { it != -1 }?.let { "height" to it },
                    bundle.getStringArrayList("preferredAudioLanguages")
                        ?.let { "preferredAudioLanguages" to it },
                    bundle.getStringArrayList("preferredTextLanguages")
                        ?.let { "preferredTextLanguages" to it },
                    "forcedAutoEnable" to bundle.getBoolean("forcedAutoEnable", true),
                    "isAfrEnabled" to bundle.getBoolean("isAfrEnabled", false),
                    bundle.getString("deviceLocale")?.let { "deviceLocale" to it }
                ).toMap()
            }

        applyTrackSelectionSettings(playerSettings)

        val playlist = intent.getStringExtra("playlist")
        val clockSettings: String? = intent.getStringExtra("clock_settings")
        val localeStrings = intent.getStringExtra("locale_strings")
        val subtitleSearch = intent.getStringExtra("subtitle_search")

        invokeOnBothChannels(
            "onActivityReady", mapOf(
                "playlist" to playlist,
                "playlist_index" to playlistIndex,
                "subtitle_style" to subtitleStyle,
                "clock_settings" to clockSettings,
                "player_settings" to playerSettings,
                "locale_strings" to localeStrings,
                "subtitle_search" to subtitleSearch,
            )
        )
    }

    /** Intercepts the system back button press and notifies Flutter. */
    override fun onBackPressed() {
        invokeOnBothChannels("onBack", null)
    }

    /**
     * Called when the Activity becomes inactive.
     *
     * Pauses the player and saves the current watch time. It also stops
     * the periodic position updates.
     */
    override fun onPause() {
        super.onPause()
        if (this::player.isInitialized) {
            val hasVideo = player.currentTracks.groups.any { group ->
                group.type == C.TRACK_TYPE_VIDEO && group.isSelected
            }
            if (player.isPlaying && hasVideo) {
                markWatchTime(playlistIndex)
                player.pause()
            }
        }
        positionHandler.removeCallbacks(positionRunnable)
    }

    /**
     * Called when the Activity becomes active again.
     *
     * Resumes periodic position updates if the player is ready.
     */
    override fun onResume() {
        super.onResume()
        if (this::player.isInitialized && player.playWhenReady) {
            if (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING) {
                positionHandler.post(positionRunnable)
            }
        }
    }

    /**
     * Called before the Activity is destroyed.
     *
     * Releases all resources: stops the AFR thread, releases the player,
     * destroys the FlutterEngine, and clears channel handlers.
     */
    override fun onDestroy() {
        super.onDestroy()
        methodChannel.invokeMethod("onActivityDestroyed", null)
        positionHandler.removeCallbacks(positionRunnable)
        methodChannel.setMethodCallHandler(null)
        methodUIChannel.setMethodCallHandler(null)

        if (this::playerView.isInitialized) {
            if (isAfrEnabled) {
                frameRateManager.release()
            }
            playerView.player = null
        }

        if (this::player.isInitialized) {
            if (this::playerListener.isInitialized) {
                player.removeListener(playerListener)
            }
            player.release()
        }

        if (flutterEngine != null) {
            flutterEngine.lifecycleChannel.appIsDetached()
            flutterEngine.platformViewsController.detachFromView()
            FlutterEngineCache.getInstance().remove(flutterEngineId)
            flutterEngine.destroy()
        }
    }

    /**
     * Loads and starts playing media from a given URL.
     *
     * Creates a `MediaSource`, prepares the player, and initiates the AFR logic.
     * @param videoUrl The URL of the media resource.
     * @param startPosition The initial playback position in milliseconds.
     */
    private fun loadAndPlayMedia(
        videoUrl: String,
        startPosition: Long = 0L,
    ) {
        try {
            if (currentUserAgent != null) {
                httpDataSourceFactory.setUserAgent(currentUserAgent)
            }
            httpDataSourceFactory.setDefaultRequestProperties(currentHeaders ?: emptyMap())
            hasSeekedToStartPosition = false
            val finalSource = createCombinedMediaSource(videoUrl)
            try {
                player.setMediaSource(finalSource, startPosition)
                player.prepare()
                player.play()
            } catch (e: Exception) {
                invokeOnBothChannels(
                    "onError", mapOf(
                        "code" to "PREPARATION_FAILED",
                        "message" to "Failed to create media source: ${e.message}"
                    )
                )
            }
        } catch (e: Exception) {
            invokeOnBothChannels(
                "onError",
                mapOf("code" to "LOAD_FAILED", "message" to "Failed to load media: ${e.message}")
            )
        }
    }

    /**
     * Requests media item information from the main Flutter app.
     *
     * Invokes the `getMediaInfo` method via the `methodChannel` and, on success,
     * receives the URL, position, and other data, then calls [loadAndPlayMedia].
     * @param index The index of the item in the playlist.
     */
    private fun requestMediaInfo(index: Int) {
        val requestToken = Any()
        currentMediaRequestToken = requestToken

        try {
            methodUIChannel.invokeMethod(
                "loadMediaInfo", mapOf("playlist_index" to index)
            )

            methodChannel.invokeMethod(
                "getMediaInfo",
                mapOf("index" to index),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (currentMediaRequestToken != requestToken) {
                            Log.w(aTag, "Ignored outdated media info success response.")
                            return
                        }

                        if (result is Map<*, *>) {
                            val url = result["url"] as? String
                            var positionInSeconds = (result["startPosition"] as? Number)?.toLong() ?: 0L
                            val durationInSeconds = (result["duration"] as? Number)?.toLong() ?: 0L
                            currentHeaders = result["headers"] as? Map<String, String>
                            currentUserAgent = result["userAgent"] as? String
                            currentResolutionsMap = result["resolutions"] as? Map<String, String>
                            currentSubtitleTracks = result["subtitles"] as? List<Map<String, Any>>
                            currentAudioTracks = result["audioTracks"] as? List<Map<String, Any>>

                            if (durationInSeconds > 0 && positionInSeconds > 0) {
                                val remainingTime = durationInSeconds - positionInSeconds
                                if (remainingTime < 15) {
                                    positionInSeconds = 0L
                                }
                            }

                            if (url != null) {
                                resetPlayerViewAppearance()
                                val finalUrl = if (currentResolutionsMap?.isNotEmpty() == true) {
                                    selectUrlByQuality(currentResolutionsMap!!, url)
                                } else {
                                    url
                                }
                                loadAndPlayMedia(
                                    videoUrl = finalUrl,
                                    startPosition = positionInSeconds * 1000
                                )
                                invokeOnBothChannels(
                                    "loadedMediaInfo", mapOf("playlist_index" to index)
                                )
                            } else {
                                invokeOnBothChannels(
                                    "onError",
                                    mapOf(
                                        "code" to "INVALID_URL",
                                        "message" to "Received null URL for playlist index $index"
                                    )
                                )
                                finish()
                            }
                        } else {
                            invokeOnBothChannels(
                                "onError",
                                mapOf(
                                    "code" to "INVALID_FORMAT",
                                    "message" to "Invalid media info format"
                                )
                            )
                            finish()
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        if (currentMediaRequestToken != requestToken) {
                            Log.w(aTag, "Ignored outdated media info error response.")
                            return
                        }
                        invokeOnBothChannels(
                            "onError",
                            mapOf(
                                "code" to errorCode,
                                "message" to "Error getting media info: $errorMessage"
                            )
                        )
                    }

                    override fun notImplemented() {
                        if (currentMediaRequestToken != requestToken) {
                            Log.w(aTag, "Ignored outdated media info notImplemented response.")
                            return
                        }
                        invokeOnBothChannels(
                            "onError",
                            mapOf(
                                "code" to "NOT_IMPLEMENTED",
                                "message" to "getMediaInfo not implemented"
                            )
                        )
                        finish()
                    }
                }
            )
        } catch (e: Exception) {
            if (currentMediaRequestToken != requestToken) {
                Log.w(aTag, "Ignored outdated media info exception: ${e.message}")
                return
            }
            invokeOnBothChannels(
                "onError",
                mapOf(
                    "code" to "CHANNEL_ERROR",
                    "message" to "Failed to invoke getMediaInfo: ${e.message}"
                )
            )
            finish()
        }
    }

    /**
     * The central handler for method calls coming from Flutter.
     *
     * Distinguishes commands from the UI overlay and the main app and delegates
     * their execution to the appropriate player methods.
     * @param call The method call object.
     * @param result The result to be returned to Flutter.
     * @param from The channel from which the call originated.
     */
    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        from: MethodChannel
    ) {
        if (!this::player.isInitialized) {
            reportErrorToOther(from, result, "PLAYER_NOT_READY", "Player not initialized.")
            return
        }

        //Log.d(aTag, "Channel call: ${call.method} | Args: ${call.arguments}")

        when (call.method) {

            "loadMediaInfoState" -> {
                val state = call.argument<String>("state")
                val progress = call.argument<Number>("progress")
                invokeOnBothChannels(
                    "loadMediaInfoState", mapOf(
                        "state" to state,
                        "progress" to progress
                    )
                )
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
                if (positionMs != null) {
                    val duration = player.duration
                    val seekPos = if (duration > 0) positionMs.coerceIn(
                        0,
                        duration
                    ) else positionMs.coerceAtLeast(0)

                    player.seekTo(seekPos)

                    val durationMs = player.duration
                    val finalDurationMs = if (durationMs != C.TIME_UNSET) durationMs else 0L
                    invokeOnBothChannels(
                        "onPositionChanged", mapOf(
                            "position" to seekPos,
                            "bufferedPosition" to player.bufferedPosition.coerceAtLeast(seekPos),
                            "duration" to finalDurationMs,
                        )
                    )

                    if (player.isPlaying) {
                        positionHandler.removeCallbacks(positionRunnable)
                        positionHandler.post(positionRunnable)
                    }
                    result.success(null)
                } else {
                    reportErrorToOther(from, result, "INVALID_POSITION", "Position is null")
                }
            }

            "stop" -> {
                finish()
                result.success(null)
            }

            "sleepTimerExec" -> {
                methodChannel.invokeMethod("sleepTimerExec", null)
                finish()
                result.success(null)
            }

            "selectTrack" -> {
                val trackIndex = call.argument<Int>("trackIndex")
                val groupIndex = call.argument<Int>("groupIndex")
                val trackType = call.argument<Int>("trackType") ?: -1
                if (trackType == -1) {
                    reportErrorToOther(from, result, "INVALID_TYPE", "Missing or invalid trackType")
                    return
                }
                if (groupIndex == null) {
                    reportErrorToOther(from, result, "INVALID_INDEX", "Group index is null")
                    return
                }
                if (trackIndex == null) {
                    reportErrorToOther(from, result, "INVALID_INDEX", "Track index is null")
                    return
                }
                selectTrack(trackType, groupIndex, trackIndex, result, from)
            }

            "selectExternalVideoTrack" -> {
                val url = call.argument<String?>("url")
                if (currentResolutionsMap != null) {
                    handleQualitySelection(url, result, from)
                } else {
                    reportErrorToOther(from, result, "INVALID_INDEX", "Quality index is null")
                }
            }

            "getMetadata" -> {
                val currentMetadata = getCurrentMetadata()
                invokeOnOtherChannel("onMetadataChanged", currentMetadata, from = from)
                result.success(currentMetadata)
            }

            "getCurrentTracks" -> {
                val currentTracks = getCurrentTracks()
                invokeOnOtherChannel("setCurrentTracks", currentTracks, from = from)
                result.success(currentTracks)
            }

            "setResizeMode" -> {
                val mode = call.argument<String>("mode")
                val resizeMode = when (mode) {
                    "FIT" -> AspectRatioFrameLayout.RESIZE_MODE_FIT
                    "FILL" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                    "ZOOM" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    "FIXED_WIDTH" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
                    "FIXED_HEIGHT" -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
                    else -> null
                }
                if (resizeMode != null) {
                    playerView.resizeMode = resizeMode
                    val resultMap = mapOf("zoom" to mode)
                    invokeOnOtherChannel("setCurrentResizeMode", resultMap, from = from)
                    result.success(resultMap)
                } else {
                    reportErrorToOther(from, result, "INVALID_MODE", "Invalid resize mode: $mode")
                }
            }

            "setScale" -> {
                val scaleX = call.argument<Double>("scaleX")?.toFloat() ?: 1.0f
                val scaleY = call.argument<Double>("scaleY")?.toFloat() ?: 1.0f
                applyZoom(scaleX, scaleY) { success ->
                    if (success) {
                        val resultMap = mapOf("zoom" to "SCALE")
                        invokeOnOtherChannel("setCurrentResizeMode", resultMap, from = from)
                        result.success(resultMap)
                    } else {
                        reportErrorToOther(
                            from,
                            result,
                            "VIEW_NOT_INITIALIZED",
                            "videoSurfaceView is null"
                        )
                    }
                }
            }

            "setSpeed" -> {
                try {
                    val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                    runOnUiThread {
                        player?.setPlaybackSpeed(speed)
                    }
                    val resultMap = mapOf("speed" to speed)
                    invokeOnOtherChannel("setCurrentSpeed", resultMap, from = from)
                    result.success(resultMap)
                } catch (e: Exception) {
                    reportErrorToOther(
                        from,
                        result,
                        "SET_SPEED_ERROR",
                        "Failed to set speed: ${e.message}"
                    )
                }
            }

            "setRepeatMode" -> {
                val modeName = call.argument<String>("mode") ?: "REPEAT_MODE_OFF"

                @Player.RepeatMode
                val repeatMode = when (modeName) {
                    "REPEAT_MODE_ONE" -> Player.REPEAT_MODE_ONE
                    "REPEAT_MODE_ALL" -> Player.REPEAT_MODE_ALL
                    else -> Player.REPEAT_MODE_OFF
                }
                runOnUiThread {
                    setRepeatModeInternal(repeatMode)
                }
                invokeOnOtherChannel(
                    "setRepeatMode",
                    mapOf("status" to "success", "mode" to modeName), from = from
                )
                result.success(mapOf("status" to "success", "mode" to modeName))
            }

            "setShuffleMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    setShuffleMode(enabled)
                }
                invokeOnOtherChannel(
                    "setShuffleMode",
                    mapOf("status" to "success", "shuffleEnabled" to enabled), from = from
                )
                result.success(mapOf("status" to "success", "shuffleEnabled" to enabled))
            }

            "setSubtitleStyle" -> {
                val styleSettings = call.arguments as? Map<String, Any>
                val finalAppliedStyle = applySubtitleStyle(styleSettings)
                invokeOnOtherChannel("updateSubtitleStyle", finalAppliedStyle, from = from)
                result.success(finalAppliedStyle)
            }

            "saveClockSettings" -> {
                val clockSettings = call.argument<String?>("clock_settings")
                invokeOnOtherChannel(
                    "saveClockSettings", mapOf(
                        "clock_settings" to clockSettings
                    ), from = from
                )
                result.success(null)
            }

            "savePlayerSettings" -> {
                try {
                    val playerSettings = call.arguments as? Map<String, Any>
                    runOnUiThread {
                        applyTrackSelectionSettings(playerSettings)
                    }
                    invokeOnOtherChannel("savePlayerSettings", playerSettings, from = from)
                    result.success(true)
                } catch (e: Exception) {
                    reportErrorToOther(
                        from,
                        result,
                        "NATIVE_ERROR",
                        "Failed to apply settings",
                        e.message
                    )
                }
            }

            "playNext" -> {
                runOnUiThread { playNext() }
                result.success(null)
            }

            "playPrevious" -> {
                runOnUiThread { playPrevious() }
                result.success(null)
            }

            "playSelectedIndex" -> {
                val newIndex = call.argument<Int>("index")
                if (newIndex != null && newIndex >= 0 && newIndex < playlistLength) {
                    markWatchTime(playlistIndex)
                    playlistIndex = newIndex

                    if (isShuffleModeEnabled) {
                        currentShuffledIndex = shuffledIndices.indexOf(newIndex)
                        if (currentShuffledIndex == -1) {
                            generateShuffledList()
                            currentShuffledIndex = 0
                        }
                    }

                    if (player.isPlaying) {
                        player.pause()
                        positionHandler.removeCallbacks(positionRunnable)
                    }
                    requestMediaInfo(newIndex)
                    result.success(null)
                } else {
                    reportErrorToOther(
                        from,
                        result,
                        "INVALID_INDEX",
                        "Invalid playlist index: $newIndex"
                    )
                }
            }

            "setExternalSubtitles" -> {
                val newSubtitles = call.argument<List<Map<String, Any>>>("subtitleTracks")
                if (newSubtitles != null) {
                    currentSubtitleTracks = (currentSubtitleTracks ?: emptyList()) + newSubtitles
                    rebuildMediaSourceAndResume()
                    result.success(null)
                } else {
                    reportErrorToOther(
                        from,
                        result, "INVALID_SUBTITLES", "Subtitles list is null"
                    )
                }
            }

            "setExternalAudio" -> {
                val newAudioTracks = call.argument<List<Map<String, Any>>>("audioTracks")
                if (newAudioTracks != null) {
                    currentAudioTracks = (currentAudioTracks ?: emptyList()) + newAudioTracks
                    rebuildMediaSourceAndResume()
                    result.success(null)
                } else {
                    reportErrorToOther(
                        from,
                        result, "INVALID_AUDIO", "Audio tracks list is null"
                    )
                }
            }
            "onReceiveInfoText" -> {
                val text = call.argument<String>("text")
                invokeOnOtherChannel(
                    "onCustomInfoUpdate",
                    mapOf("text" to text),
                    from = from
                )
                result.success(null)
            }
            "findSubtitles" -> {
                val mediaId = call.argument<String>("mediaId")
                invokeOnOtherChannel(
                    "onFindSubtitlesRequested",
                    mapOf("mediaId" to mediaId),
                    from = from
                )
                result.success(null)
            }
            "onSubtitleSearchStateChanged" -> {
                val state = call.arguments as? Map<String, Any>
                invokeOnOtherChannel("onSubtitleSearchStateChanged", state, from = from)
                result.success(null)
            }
            "getRefreshRateInfo" -> {
                result.success(frameRateManager.getRefreshRateInfo())
            }
            "setManualFrameRate" -> {
                if (!isAfrEnabled) {
                    val rate = call.argument<Double>("rate")?.toFloat()
                    if (rate != null) {
                        frameRateManager.setManualRefreshRate(rate)
                        result.success(null)
                    } else {
                        reportErrorToOther(from, result, "INVALID_RATE", "Rate is null")
                    }
                } else {
                    reportErrorToOther(from, result, "AFR_ENABLED", "Cannot set manual rate when AFR is enabled")
                }
            }
            else -> {
                reportErrorToOther(
                    from,
                    result,
                    "INVALID_AUDIO",
                    "Method ${call.method} not implemented in PlayerActivity channel."
                )
                result.notImplemented()
            }
        }
    }

    /**
     * Creates and returns a listener for player events.
     *
     * This listener reacts to state changes, errors, track changes, and other
     * ExoPlayer events, notifying the Flutter side accordingly.
     */
    private fun createPlayerListener(): Player.Listener {
        return object : Player.Listener {

            private fun updateWakeLock() {
                val hasVideo = player.currentTracks.groups.any { group ->
                    group.type == C.TRACK_TYPE_VIDEO && group.isSelected
                }
                if (player.isPlaying && hasVideo) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                updateWakeLock()
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                val state = notifyStateChanged(player)
                if (playbackState == Player.STATE_READY && !hasSeekedToStartPosition && startPosition > 0) {
                    val durationMs = player.duration
                    if (durationMs > 0 && startPosition < durationMs) {
                        player.seekTo(startPosition)
                        hasSeekedToStartPosition = true
                        val finalDurationMs = if (durationMs != C.TIME_UNSET) durationMs else 0L
                        invokeOnBothChannels(
                            "onPositionChanged", mapOf(
                                "position" to startPosition,
                                "bufferedPosition" to player.bufferedPosition,
                                "duration" to finalDurationMs,
                            )
                        )

                    } else {
                        hasSeekedToStartPosition = true
                    }
                }

                if (playbackState == Player.STATE_ENDED) {
                    markWatchTime(playlistIndex)
                    positionHandler.removeCallbacks(positionRunnable)
                    if (isShuffleModeEnabled) {
                        handleNextTrackInShuffleMode()
                    } else {
                        handleNextTrackInSequentialMode()
                    }
                }

                if ((state == "playing" || state == "buffering") && playbackState != Player.STATE_ENDED) {
                    positionHandler.removeCallbacks(positionRunnable)
                    positionHandler.post(positionRunnable)
                } else {
                    positionHandler.removeCallbacks(positionRunnable)
                }
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                notifyStateChanged(player)
                if (playWhenReady && (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING)) {
                    positionHandler.removeCallbacks(positionRunnable)
                    positionHandler.post(positionRunnable)
                } else {
                    positionHandler.removeCallbacks(positionRunnable)
                }
            }

            override fun onTimelineChanged(timeline: Timeline, reason: Int) {
                val metadata = getCurrentMetadata()
                try {
                    invokeOnBothChannels("onMetadataChanged", metadata)
                } catch (e: Exception) {
                    invokeOnBothChannels(
                        "onError", mapOf(
                            "code" to "ON_TIME_LINE_CHANGED",
                            "message" to "Error invoking onStreamingMetadataUpdated: ${e.message}"
                        )
                    )

                }
            }

            override fun onMetadata(metadata: Metadata) {
                val streamingUpdate = parseStreamingMetadata(metadata)
                if (streamingUpdate.isNotEmpty()) {
                    try {
                        invokeOnBothChannels("onStreamingMetadataUpdated", streamingUpdate)
                    } catch (e: Exception) {
                        invokeOnBothChannels(
                            "onError", mapOf(
                                "code" to "ON_METADETA",
                                "message" to "Error invoking onStreamingMetadataUpdated: ${e.message}"
                            )
                        )
                    }
                }
            }

            private fun sendCurrentTracksToDart() {
                invokeOnBothChannels("setCurrentTracks", getCurrentTracks())
            }

            override fun onTracksChanged(tracks: Tracks) {
                sendCurrentTracksToDart()
                if (isAfrEnabled) {
                    frameRateManager.onPossibleFrameRateChange()
                }
            }

            override fun onRenderedFirstFrame() {
                updateWakeLock()
                sendCurrentTracksToDart()
                if (isAfrEnabled) {
                    frameRateManager.onPossibleFrameRateChange()
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                if (isRecoverableHlsError(error)) {
                    player.seekToDefaultPosition()
                    player.prepare()
                    player.play()
                } else {
                    invokeOnBothChannels(
                        "onError", mapOf(
                            "code" to error.errorCodeName,
                            "message" to error.localizedMessage
                        )
                    )
                    positionHandler.removeCallbacks(positionRunnable)
                }
            }
        }
    }

    private fun isRecoverableHlsError(e: PlaybackException): Boolean {
        var cause: Throwable? = e
        while (cause != null) {
            if (cause is androidx.media3.exoplayer.source.BehindLiveWindowException ||
                cause is androidx.media3.exoplayer.hls.playlist.HlsPlaylistTracker.PlaylistResetException) {
                return true
            }
            cause = cause.cause
        }
        return false
    }

    private fun debugTracksShort(currentTracks: Tracks) {

        Log.d("PlayerActivity", "=== TRACKS SUMMARY ===")

        val videoTracks = currentTracks.groups.filter { it.type == C.TRACK_TYPE_VIDEO }
        val audioTracks = currentTracks.groups.filter { it.type == C.TRACK_TYPE_AUDIO }
        val textTracks = currentTracks.groups.filter { it.type == C.TRACK_TYPE_TEXT }

        Log.d("PlayerActivity", "Video tracks: ${videoTracks.size}")
        videoTracks.forEach { group ->
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val selected = if (group.isTrackSelected(i)) "[SELECTED]" else ""
                Log.d("PlayerActivity", "  Video: ${format.width}x${format.height} ${format.sampleMimeType} $selected")
            }
        }

        Log.d("PlayerActivity", "Audio tracks: ${audioTracks.size}")
        audioTracks.forEach { group ->
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val selected = if (group.isTrackSelected(i)) "[SELECTED]" else ""
                Log.d("PlayerActivity", "  Audio: ${format.id} ${format.language} ${format.label} ${format.sampleMimeType} $selected")
            }
        }

        Log.d("PlayerActivity", "Subtitle tracks: ${textTracks.size}")
        textTracks.forEach { group ->
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val selected = if (group.isTrackSelected(i)) "[SELECTED]" else ""
                Log.d("PlayerActivity", "  Subtitle: ${format.language} ${format.label} ${format.sampleMimeType} $selected")
            }
        }

        Log.d("PlayerActivity", "===================")
    }

    private fun getCurrentTracks(): List<Map<String, Any?>> {
        val tracksList = mutableListOf<Map<String, Any?>>()
        if (!this::player.isInitialized) return tracksList

        val currentTracks = player.currentTracks
        val activeVideoFormat = player.videoFormat
        debugTracksShort(currentTracks)
        var externalAudioTrackIndex = 0
        for (group in currentTracks.groups) {
            val trackType = group.type
            if (trackType != C.TRACK_TYPE_VIDEO &&
                trackType != C.TRACK_TYPE_AUDIO &&
                trackType != C.TRACK_TYPE_TEXT
            ) {
                continue
            }
            val trackGroup = group.mediaTrackGroup

            for (i in 0 until trackGroup.length) {
                if (!group.isTrackSupported(i)) {
                    Log.w(aTag, "Track $i in group type $trackType is not supported.")
                    continue
                }

                val format = trackGroup.getFormat(i)
                val isSelected = when (trackType) {
                    C.TRACK_TYPE_VIDEO -> {
                        //activeVideoFormat?.let { active -> active.id == format.id } ?: false
                        if (group.isSelected && group.isTrackSelected(i)) {
                            true
                        } else {
                            activeVideoFormat?.let { active -> active.id == format.id } ?: false
                        }
                    }

                    else -> {
                        group.isSelected && group.isTrackSelected(i)
                    }
                }

                val trackInfo = mutableMapOf<String, Any?>(
                    "index" to i,
                    "groupIndex" to currentTracks.groups.indexOf(group),
                    "id" to format.id,
                    "trackType" to trackType,
                    "isSelected" to isSelected,
                    "isExternal" to false
                )

                when (trackType) {
                    C.TRACK_TYPE_VIDEO -> {
                        trackInfo.putAll(
                            mapOf(
                                "label" to format.label,
                                "width" to format.width.takeIf { it != Format.NO_VALUE },
                                "height" to format.height.takeIf { it != Format.NO_VALUE },
                                "bitrate" to format.bitrate.takeIf { it != Format.NO_VALUE },
                                "frameRate" to format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() },
                                "sampleMimeType" to format.sampleMimeType,
                                "codecs" to format.codecs,
                                "selectionFlags" to format.selectionFlags,
                                "roleFlags" to format.roleFlags,
                                "pixelWidthHeightRatio" to format.pixelWidthHeightRatio.takeIf { it != Format.NO_VALUE.toFloat() },
                                "containerMimeType" to format.containerMimeType,
                                "averageBitrate" to format.averageBitrate.takeIf { it != Format.NO_VALUE },
                                "peakBitrate" to format.peakBitrate.takeIf { it != Format.NO_VALUE },
                                "stereoMode" to format.stereoMode,
                                "colorInfo" to format.colorInfo?.let { colorInfo ->
                                    mapOf(
                                        "colorSpace" to colorInfo.colorSpace,
                                        "colorRange" to colorInfo.colorRange,
                                        "colorTransfer" to colorInfo.colorTransfer
                                    )
                                }
                            )
                        )
                    }

                    C.TRACK_TYPE_AUDIO -> {
                        trackInfo.putAll(
                            mapOf(
                                "label" to format.label,
                                "language" to format.language,
                                "codec" to format.codecs,
                                "mimeType" to format.sampleMimeType,
                                "bitrate" to format.bitrate.takeIf { it != Format.NO_VALUE },
                                "averageBitrate" to format.averageBitrate.takeIf { it != Format.NO_VALUE },
                                "peakBitrate" to format.peakBitrate.takeIf { it != Format.NO_VALUE },
                                "sampleRate" to format.sampleRate,
                                "channelCount" to format.channelCount,
                                "selectionFlags" to format.selectionFlags,
                                "roleFlags" to format.roleFlags
                            )
                        )
                        val formatId = format.id
                        val isPossiblyExternal = (
                                (format.label == null && format.language == null) &&
                                        (formatId != null && formatId.matches(Regex("\\d+:")))
                                )

                        if (isPossiblyExternal && currentAudioTracks != null) {
                            val index = externalAudioTrackIndex
                            externalAudioTrackIndex++
                            val externalTrack = currentAudioTracks?.getOrNull(index)

                            if (externalTrack != null) {
                                (externalTrack["label"] as? String)?.let { trackInfo["label"] = it }
                                (externalTrack["language"] as? String)?.let { trackInfo["language"] = it }
                                trackInfo["isExternal"] = true
                            }
                        }
                    }

                    C.TRACK_TYPE_TEXT -> {
                        trackInfo.putAll(
                            mapOf(
                                "label" to format.label,
                                "language" to (format.language ?: "unknown"),
                                "selectionFlags" to format.selectionFlags,
                                "roleFlags" to format.roleFlags,
                                "codecs" to format.codecs,
                                "containerMimeType" to format.containerMimeType,
                                "sampleMimeType" to format.sampleMimeType
                            )
                        )
                    }
                }

                tracksList.add(trackInfo)
            }
        }
        if (currentResolutionsMap != null) {
            val currentUri = player.currentMediaItem?.localConfiguration?.uri?.toString()
            currentResolutionsMap?.let { map ->
                var externalIndex = 1000
                for ((label, url) in map) {
                    if (url != currentUri) {
                        val externalTrack = mapOf(
                            "index" to externalIndex++,
                            "groupIndex" to -1,
                            "id" to url,
                            "trackType" to C.TRACK_TYPE_VIDEO,
                            "label" to label,
                            "url" to url,
                            "isSelected" to false,
                            "isExternal" to true
                        )
                        tracksList.add(externalTrack)
                    } else {
                        val selectedTrack = tracksList.find { it["isSelected"] == true }
                        if (selectedTrack != null) {
                            tracksList.remove(selectedTrack)
                            val newTrack = selectedTrack.toMutableMap().apply {
                                this["label"] = label
                            }
                            tracksList.add(newTrack)
                        }
                    }
                }
            }
        }
        return tracksList
    }

    private fun selectTrack(
        trackType: @C.TrackType Int,
        groupIndex: Int,
        trackIndex: Int,
        result: MethodChannel.Result,
        from: MethodChannel
    ) {
        try {
            val parametersBuilder = trackSelector.parameters.buildUpon()

            if (trackIndex == -1) {
                when (trackType) {
                    C.TRACK_TYPE_VIDEO -> {
                        parametersBuilder
                            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                            .setRendererDisabled(C.TRACK_TYPE_VIDEO, false)
                            .setForceHighestSupportedBitrate(false)
                            .setMaxVideoBitrate(Int.MAX_VALUE)
                        Log.d(aTag, "Video track set to AUTO.")
                    }

                    C.TRACK_TYPE_AUDIO -> {
                        parametersBuilder
                            .clearSelectionOverrides(trackType)
                            .setRendererDisabled(trackType, true)
                    }

                    C.TRACK_TYPE_TEXT -> {
                        (0 until (trackSelector.currentMappedTrackInfo?.rendererCount
                            ?: 0)).filter { position ->
                            player.getRendererType(position) == C.TRACK_TYPE_TEXT
                        }.map { position ->
                            parametersBuilder
                                .setRendererDisabled(position, true)
                                .clearSelectionOverrides(position)
                        }
                    }

                    else -> {
                        reportErrorToOther(
                            from, result,
                            "UNSUPPORTED_TRACK_TYPE",
                            "Unsupported track type for AUTO (-1)."
                        )
                        return
                    }
                }
            } else {
                val groups = player.currentTracks.groups
                if (groupIndex < 0 || groupIndex >= groups.size) {
                    reportErrorToOther(
                        from,
                        result,
                        "INVALID_GROUP",
                        "Invalid group index: $groupIndex"
                    )
                    return
                }
                val group = groups[groupIndex]
                if (group.type != trackType) {
                    reportErrorToOther(
                        from, result,
                        "WRONG_TYPE",
                        "Group type does not match expected type: $trackType"
                    )
                    return
                }
                val trackGroup = group.mediaTrackGroup
                if (trackIndex < 0 || trackIndex >= trackGroup.length || !group.isTrackSupported(
                        trackIndex
                    )
                ) {
                    reportErrorToOther(
                        from, result,
                        "INVALID_INDEX",
                        "Invalid track index ($trackIndex) or track not supported."
                    )
                    return
                }
                val override = TrackSelectionOverride(trackGroup, listOf(trackIndex))

                if (trackType == C.TRACK_TYPE_TEXT) {
                    parametersBuilder.addOverride(override)
                    val mappedTrackInfo = trackSelector.currentMappedTrackInfo
                    if (mappedTrackInfo != null) {
                        for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
                            if (mappedTrackInfo.getRendererType(rendererIndex) == C.TRACK_TYPE_TEXT) {
                                parametersBuilder.setRendererDisabled(rendererIndex, false)
                            }
                        }
                    }
                } else {
                    parametersBuilder
                        .setOverrideForType(override)
                        .setRendererDisabled(trackType, false)
                }
            }

            trackSelector.parameters = parametersBuilder.build()
            result.success(null)
        } catch (e: Exception) {
            reportErrorToOther(
                from,
                result,
                "SELECTION_ERROR",
                "Failed to apply track selection: ${e.message}"
            )
        }
    }

    private fun handleQualitySelection(
        url: String?,
        result: MethodChannel.Result,
        from: MethodChannel
    ) {
        if (currentResolutionsMap.isNullOrEmpty()) {
            reportErrorToOther(
                from,
                result,
                "NO_RESOLUTIONS",
                "Resolution tracks are not available for selection"
            )
            return
        }
        val availableUrls = currentResolutionsMap!!.values.toList()
        val selectedUrl = when {
            url == null -> availableUrls.firstOrNull()
            availableUrls.contains(url) -> url
            else -> {
                reportErrorToOther(
                    from,
                    result,
                    "INVALID_URL",
                    "Provided URL is not among available resolution tracks"
                )
                return
            }
        }

        if (selectedUrl == null) {
            reportErrorToOther(
                from,
                result, "NO_VALID_URL", "No valid URL found for selection", null
            )
            return
        }

        val currentPosition = player.currentPosition
        val wasPlaying = player.isPlaying
        try {
            loadAndPlayMedia(videoUrl = selectedUrl, startPosition = currentPosition)
            if (!wasPlaying) {
                player.pause()
            }
            result.success(null)
        } catch (e: Exception) {
            reportErrorToOther(
                from,
                result, "SOURCE_SWITCH_ERROR", "Failed to switch MP4 source: ${e.message}"
            )
        }
    }

    private fun getCurrentMetadata(): Map<String, Any?> {
        val metadataMap = mutableMapOf<String, Any?>()
        if (!this::player.isInitialized || player.currentMediaItem == null) {
            return metadataMap
        }

        player.currentMediaItem?.let { mediaItem ->
            val metadata = mediaItem.mediaMetadata
            metadataMap["title"] = metadata.title?.toString()
            metadataMap["artist"] = metadata.artist?.toString()
            metadataMap["albumTitle"] = metadata.albumTitle?.toString()
            metadataMap["albumArtist"] = metadata.albumArtist?.toString()
            metadataMap["genre"] = metadata.genre?.toString()
            metadataMap["year"] = metadata.recordingYear
            metadataMap["trackNumber"] = metadata.trackNumber
            metadataMap["artworkUri"] = metadata.artworkUri?.toString()
            metadataMap["artworkData"] = metadata.artworkData
        }
        return metadataMap
    }

    private fun parseStreamingMetadata(metadata: Metadata): Map<String, Any?> {
        val streamingDataMap = mutableMapOf<String, Any?>()

        for (i in 0 until metadata.length()) {
            when (val entry = metadata[i]) {
                is IcyInfo -> {
                    entry.title?.let { streamingDataMap["icyTitle"] = it }
                    entry.url?.let { streamingDataMap["icyUrl"] = it }
                }

                is TextInformationFrame -> {
                    streamingDataMap["id3_${entry.id}"] = entry.value
                }
            }
        }
        return streamingDataMap
    }

    private fun markWatchTime(playlistIndex: Int) {
        if (!this::player.isInitialized) {
            Log.e(aTag, "markWatchTime: Player not initialized")
            return
        }
        val isLive = player.isCurrentMediaItemLive

        if (isLive) {
            Log.d(aTag, "markWatchTime: Skipping for live stream")
            return
        }
        val currentPosition = player.currentPosition
        val duration = player.duration.takeIf { it != C.TIME_UNSET } ?: 0L

        Log.d(
            aTag,
            "Watch position marked: position=$currentPosition, duration=$duration, playlistIndex=$playlistIndex"
        )

        Handler(Looper.getMainLooper()).post {
            invokeOnBothChannels(
                "onWatchTimeMarked",
                mapOf(
                    "position_ms" to currentPosition,
                    "duration_ms" to duration,
                    "playlist_index" to playlistIndex
                )
            )
        }
    }

    private fun applyZoom(scaleX: Float, scaleY: Float, onComplete: (Boolean) -> Unit) {
        val videoSurfaceView = playerView.videoSurfaceView
        if (videoSurfaceView == null) {
            onComplete(false)
            return
        }

        val clampedScaleX = scaleX.coerceIn(0.1f, 3.0f)
        val clampedScaleY = scaleY.coerceIn(0.1f, 3.0f)
        runOnUiThread {
            videoSurfaceView.pivotX = videoSurfaceView.width / 2f
            videoSurfaceView.pivotY = videoSurfaceView.height / 2f
            videoSurfaceView.animate()
                .scaleX(clampedScaleX)
                .scaleY(clampedScaleY)
                .setDuration(300)
                .withEndAction {
                    onComplete(true)
                }
                .start()
        }
    }

    private fun resetPlayerViewAppearance() {
        player?.setPlaybackSpeed(1.0f)
        playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        val videoSurfaceView = playerView.videoSurfaceView
        if (videoSurfaceView != null) {
            videoSurfaceView.scaleX = 1.0f
            videoSurfaceView.scaleY = 1.0f
        }
    }

    private fun setRepeatModeInternal(@Player.RepeatMode newMode: Int) {
        currentRepeatMode = newMode
        player?.repeatMode = if (newMode == Player.REPEAT_MODE_ONE) {
            Player.REPEAT_MODE_ONE
        } else {
            Player.REPEAT_MODE_OFF
        }
    }

    private fun setShuffleMode(enabled: Boolean) {
        isShuffleModeEnabled = enabled

        if (enabled) {
            generateShuffledList()
            currentShuffledIndex = 0
        } else {
            currentShuffledIndex = -1
            shuffledIndices = emptyList()
        }
    }

    private val positionRunnable = object : Runnable {
        override fun run() {
            if (!isFinishing && !isDestroyed && this@PlayerActivity::player.isInitialized && player.playbackState != Player.STATE_IDLE) {
                val positionMs = player.currentPosition
                val bufferedPositionMs = player.bufferedPosition
                val durationMs = player.duration
                val finalDurationMs = if (durationMs != C.TIME_UNSET) durationMs else 0L

                invokeOnBothChannels(
                    "onPositionChanged", mapOf(
                        "position" to positionMs,
                        "bufferedPosition" to bufferedPositionMs,
                        "duration" to finalDurationMs,
                    )
                )
                positionHandler.postDelayed(this, 500)
            } else {
                invokeOnBothChannels(
                    "onError", mapOf(
                        "code" to "PREPARATION_FAILED",
                        "message" to "PositionRunnable: Stopping updates (activity finishing or player not ready)."
                    )
                )
            }
        }
    }

    private fun generateShuffledList() {
        val otherIndices = (0 until playlistLength).toMutableList().apply {
            remove(playlistIndex)
        }
        otherIndices.shuffle()
        shuffledIndices = listOf(playlistIndex) + otherIndices
    }

    private fun handleNextTrackInShuffleMode() {
        currentShuffledIndex++
        if (currentShuffledIndex < shuffledIndices.size) {
            playlistIndex = shuffledIndices[currentShuffledIndex]
            requestMediaInfo(playlistIndex)
        } else {
            if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                generateShuffledList()
                currentShuffledIndex = 0
                playlistIndex = shuffledIndices[currentShuffledIndex]
                requestMediaInfo(playlistIndex)
            } else {
                finish()
            }
        }
    }

    private fun handleNextTrackInSequentialMode() {
        when (currentRepeatMode) {
            Player.REPEAT_MODE_ONE -> {}
            Player.REPEAT_MODE_ALL -> {
                playlistIndex = (playlistIndex + 1) % playlistLength
                requestMediaInfo(playlistIndex)
            }

            else -> {
                if (playlistIndex + 1 < playlistLength) {
                    playlistIndex++
                    requestMediaInfo(playlistIndex)
                } else {
                    finish()
                }
            }
        }
    }

    private fun playNext() {
        markWatchTime(playlistIndex)
        if (player.isPlaying) {
            player.pause()
        }
        if (isShuffleModeEnabled) {
            if (currentShuffledIndex + 1 < shuffledIndices.size) {
                currentShuffledIndex++
                playlistIndex = shuffledIndices[currentShuffledIndex]
                requestMediaInfo(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    generateShuffledList()
                    currentShuffledIndex = 0
                    playlistIndex = shuffledIndices[currentShuffledIndex]
                    requestMediaInfo(playlistIndex)
                } else {
                    Log.d("PlayerLogic", "Next: End of shuffled playlist, no repeat.")
                }
            }
        } else {
            if (playlistIndex + 1 < playlistLength) {
                playlistIndex++
                requestMediaInfo(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    playlistIndex = 0
                    requestMediaInfo(playlistIndex)
                } else {
                    Log.d("PlayerLogic", "Next: End of sequential playlist, no repeat.")
                }
            }
        }
    }

    private fun playPrevious() {
        markWatchTime(playlistIndex)
        if (player.isPlaying) {
            player.pause()
        }
        if (isShuffleModeEnabled) {
            if (currentShuffledIndex - 1 >= 0) {
                currentShuffledIndex--
                playlistIndex = shuffledIndices[currentShuffledIndex]
                requestMediaInfo(playlistIndex)
            } else {
                Log.d("PlayerLogic", "Previous: Beginning of shuffled playlist.")
            }
        } else {
            if (playlistIndex - 1 >= 0) {
                playlistIndex--
                requestMediaInfo(playlistIndex)
            } else {
                if (currentRepeatMode == Player.REPEAT_MODE_ALL) {
                    playlistIndex = playlistLength - 1
                    requestMediaInfo(playlistIndex)
                } else {
                    Log.d("PlayerLogic", "Previous: Beginning of sequential playlist.")
                }
            }
        }
    }

    private fun applySubtitleStyle(newStyleSettings: Map<String, Any>?): Map<String, Any> {

        val defaultSubtitleStyle = mapOf<String, Any>(
            "applyEmbeddedStyles" to true,
            "foregroundColor" to "#FFFFFFFF",
            "backgroundColor" to "#00000000",
            "windowColor" to "#00000000",
            "edgeType" to CaptionStyleCompat.EDGE_TYPE_DROP_SHADOW,
            "edgeColor" to "#FF000000",
            "textSizeFraction" to 1.0
        )

        val finalStyle = defaultSubtitleStyle + (newStyleSettings ?: emptyMap())
        val subtitleView = playerView.subtitleView ?: return defaultSubtitleStyle

        runOnUiThread {
            subtitleView.apply {
                setApplyEmbeddedStyles(finalStyle["applyEmbeddedStyles"] as Boolean)
                val sizeMultiplier = (finalStyle["textSizeFraction"] as Double).toFloat()
                setFractionalTextSize(SubtitleView.DEFAULT_TEXT_SIZE_FRACTION * sizeMultiplier)
                val style = CaptionStyleCompat(
                    Color.parseColor(finalStyle["foregroundColor"] as String),
                    Color.parseColor(finalStyle["windowColor"] as String),
                    Color.parseColor(finalStyle["backgroundColor"] as String),
                    finalStyle["edgeType"] as Int,
                    Color.parseColor(finalStyle["edgeColor"] as String),
                    Typeface.DEFAULT
                )
                setStyle(style)
            }
            val bottomPaddingValue = finalStyle["bottomPadding"] as? Number
            val leftPaddingValue = finalStyle["leftPadding"] as? Number
            val rightPaddingValue = finalStyle["rightPadding"] as? Number
            val topPaddingValue = finalStyle["topPadding"] as? Number

            subtitleView.setPadding(
                leftPaddingValue?.toInt() ?: 0,
                topPaddingValue?.toInt() ?: 0,
                rightPaddingValue?.toInt() ?: 0,
                bottomPaddingValue?.toInt() ?: 0
            )

        }

        return finalStyle
    }

    private fun applyTrackSelectionSettings(settings: Map<String, Any>?) {
        val newAfrState = settings?.get("isAfrEnabled") as? Boolean ?: false
        if (isAfrEnabled && !newAfrState) {
            frameRateManager.release()
        }
        isAfrEnabled = newAfrState

        val parametersBuilder = trackSelector.parameters.buildUpon()
        val effectiveSettings = settings ?: emptyMap()

        currentVideoQualityIndex =
            (effectiveSettings["videoQuality"] as? Number)?.toInt() ?: currentVideoQualityIndex
        currentVideoWidth = (effectiveSettings["width"] as? Number)?.toInt() ?: currentVideoWidth
        currentVideoHeight = (effectiveSettings["height"] as? Number)?.toInt() ?: currentVideoHeight

        when (currentVideoQualityIndex) {
            0 -> {
                parametersBuilder
                    .clearVideoSizeConstraints()
                    .setForceLowestBitrate(false)
                    .setForceHighestSupportedBitrate(true)
            }

            4 -> {
                parametersBuilder
                    .clearVideoSizeConstraints()
                    .setForceHighestSupportedBitrate(false)
                    .setForceLowestBitrate(true)
            }

            else -> {
                if (currentVideoWidth > 0 && currentVideoHeight > 0) {
                    parametersBuilder
                        .setMaxVideoSize(currentVideoWidth, currentVideoHeight)
                        .setForceLowestBitrate(false)
                        .setForceHighestSupportedBitrate(true)
                } else {
                    parametersBuilder
                        .clearVideoSizeConstraints()
                        .setForceLowestBitrate(false)
                        .setForceHighestSupportedBitrate(true)
                }
            }
        }

        (effectiveSettings["preferredAudioLanguages"] as? List<*>)?.let { languages ->
            parametersBuilder.setPreferredAudioLanguages(*languages.mapNotNull { it as? String }
                .toTypedArray())
        }
        (effectiveSettings["preferredTextLanguages"] as? List<*>)?.let { languages ->
            parametersBuilder.setPreferredTextLanguages(*languages.mapNotNull { it as? String }
                .toTypedArray())
        }

        val subtitlesEnabled = effectiveSettings["forcedAutoEnable"] as? Boolean ?: true

        if (subtitlesEnabled) {
            (0 until (trackSelector.currentMappedTrackInfo?.rendererCount
                ?: 0)).filter { position ->
                player.getRendererType(position) == C.TRACK_TYPE_TEXT
            }.map { position ->
                parametersBuilder
                    .setRendererDisabled(position, false)
                    .clearSelectionOverrides(position)
            }
            parametersBuilder
                .setPreferredTextRoleFlags(C.ROLE_FLAG_MAIN or C.ROLE_FLAG_SUBTITLE)
        } else {
            (0 until (trackSelector.currentMappedTrackInfo?.rendererCount
                ?: 0)).filter { position ->
                player.getRendererType(position) == C.TRACK_TYPE_TEXT
            }.map { position ->
                parametersBuilder
                    .setRendererDisabled(position, true)
                    .clearSelectionOverrides(position)
            }
        }

        trackSelector.parameters = parametersBuilder.build()
    }

    private fun selectUrlByQuality(
        resolutionsMap: Map<String, String>,
        defaultUrl: String
    ): String {
        if (resolutionsMap.isEmpty()) {
            return defaultUrl
        }

        when (currentVideoQualityIndex) {
            0 -> {
                val sortedResolutions =
                    resolutionsMap.entries.sortedByDescending { parseQuality(it.key, it.value) }
                return sortedResolutions.firstOrNull()?.value ?: defaultUrl
            }

            4 -> {
                val sortedResolutions =
                    resolutionsMap.entries.sortedBy { parseQuality(it.key, it.value) }
                return sortedResolutions.firstOrNull()?.value ?: defaultUrl
            }

            else -> {
                if (currentVideoHeight > 0) {
                    val sortedResolutions = resolutionsMap.entries
                        .map { entry ->
                            parseQuality(entry.key, entry.value) to entry.value
                        }
                        .sortedBy { it.first }
                    val bestMatch = sortedResolutions.firstOrNull { it.first >= currentVideoHeight }
                    return bestMatch?.second ?: sortedResolutions.lastOrNull()?.second ?: defaultUrl
                }
            }
        }
        return defaultUrl
    }

    private fun parseQuality(vararg sources: String): Int {
        val kRegex = "(\\d)[Kk]".toRegex()
        val pRegex = "(\\d{3,4})p?".toRegex()

        for (source in sources) {
            val lowerSource = source.lowercase().replace(" ", "")
            if (lowerSource.contains("fullhd") || lowerSource.contains("fhd")) return 1080
            if (lowerSource.contains("uhd")) return 2160
            if (lowerSource.matches(Regex(".*\\bhd\\b.*")) || lowerSource.contains("hd")) return 720
            if (lowerSource.contains("sd")) return 480
            kRegex.find(lowerSource)?.let { match ->
                val kValue = match.groupValues[1].toIntOrNull()
                return when (kValue) {
                    8 -> 4320
                    4 -> 2160
                    2 -> 1440
                    else -> 0
                }
            }
            pRegex.find(lowerSource)?.let { match ->
                val potentialQuality = match.groupValues[1].toIntOrNull() ?: 0
                if (potentialQuality in listOf(240, 360, 480, 720, 1080, 1440, 2160, 4320)) {
                    return potentialQuality
                }
            }
        }
        return 0
    }

    private fun notifyStateChanged(player: Player): String {
        val state = getPlayerStateString()
        val isLive = player.isCurrentMediaItemLive
        val isSeekable = player.isCurrentMediaItemSeekable
        val speed: Float = player.playbackParameters.speed
        val currentModeString = when (currentRepeatMode) {
            Player.REPEAT_MODE_ONE -> "REPEAT_MODE_ONE"
            Player.REPEAT_MODE_ALL -> "REPEAT_MODE_ALL"
            else -> "REPEAT_MODE_OFF"
        }
        invokeOnBothChannels(
            "onStateChanged", mapOf(
                "state" to state,
                "isLive" to isLive,
                "isSeekable" to isSeekable,
                "playlist_index" to playlistIndex,
                "speed" to speed,
                "repeatMode" to currentModeString,
                "shuffleEnabled" to isShuffleModeEnabled
            )
        )
        return state
    }

    private fun getPlayerStateString(): String {
        if (!this::player.isInitialized) return "idle"
        return when (player.playbackState) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> if (player.playWhenReady) "playing" else "paused"
            Player.STATE_ENDED -> "ended"
            else -> "unknown"
        }
    }

    private fun invokeOnBothChannels(method: String, arguments: Any?) {
        try {
            methodChannel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            Log.e(aTag, "invokeOnBothChannels: error on methodChannel: ${e.message}")
        }
        try {
            methodUIChannel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            Log.e(aTag, "invokeOnBothChannels: error on methodUIChannel: ${e.message}")
        }
    }

    private fun invokeOnOtherChannel(method: String, arguments: Any?, from: MethodChannel) {
        try {
            if (from != methodChannel) methodChannel.invokeMethod(method, arguments)
            if (from != methodUIChannel) methodUIChannel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            Log.e(aTag, "invokeOnOtherChannel: error calling $method: ${e.message}")
        }
    }

    private fun reportErrorToOther(
        from: MethodChannel,
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any? = null
    ) {
        invokeOnOtherChannel(
            "onError",
            mapOf("code" to code, "message" to message),
            from = from
        )
        result.error(code, message, details)
    }

    private fun rebuildMediaSourceAndResume() {
        val currentMediaItem = player.currentMediaItem ?: return
        val videoUrl = currentMediaItem.localConfiguration?.uri?.toString() ?: return
        val currentPosition = player.currentPosition
        val wasPlaying = player.isPlaying
        val finalSource = createCombinedMediaSource(videoUrl)
        try {
            player.setMediaSource(finalSource, currentPosition)
            player.prepare()
            if (wasPlaying) {
                player.play()
            }
        } catch (e: Exception) {
            invokeOnBothChannels(
                "onError", mapOf(
                    "code" to "PREPARATION_FAILED",
                    "message" to "Failed to create media source: ${e.message}"
                )
            )
        }
    }

    private fun getMimeTypeFromUrl(url: String, isSubtitle: Boolean): String {
        val cleanUrl = url.substringBefore("?")
        val extension = cleanUrl.substringAfterLast(".", "").lowercase()
        val mimeType = when (extension) {
            // Субтитри
            "srt" -> MimeTypes.APPLICATION_SUBRIP // .srt → application/x-subrip
            "vtt" -> MimeTypes.TEXT_VTT // .vtt → text/vtt
            "webvtt" -> MimeTypes.TEXT_VTT // .webvtt → text/vtt
            "ttml" -> MimeTypes.APPLICATION_TTML // .ttml → application/ttml+xml
            "xml" -> MimeTypes.APPLICATION_TTML // .xml → application/ttml+xml
            "dfxp" -> MimeTypes.APPLICATION_TTML // .dfxp → application/ttml+xml
            "scc" -> MimeTypes.APPLICATION_CEA608 // .scc → application/cea-608
            "cap" -> MimeTypes.APPLICATION_CEA708 // .cap → application/cea-708
            "dvb" -> MimeTypes.APPLICATION_DVBSUBS // .dvb → application/dvbsubs
            "3gpp" -> MimeTypes.APPLICATION_TX3G // .3gpp → application/x-quicktime-tx3g
            "3gp" -> MimeTypes.APPLICATION_TX3G // .3gp → application/x-quicktime-tx3g
            "m4vtt" -> MimeTypes.APPLICATION_MP4VTT // .m4vtt → application/x-mp4-vtt
            // Audio
            "mp3" -> MimeTypes.AUDIO_MPEG // .mp3 → audio/mpeg
            "aac" -> MimeTypes.AUDIO_AAC // .aac → audio/mp4a-latm
            "m4a" -> MimeTypes.AUDIO_MP4 // .m4a → audio/mp4
            "ogg" -> MimeTypes.AUDIO_OGG // .ogg → audio/ogg
            "oga" -> MimeTypes.AUDIO_OGG // .oga → audio/ogg
            "wav" -> MimeTypes.AUDIO_WAV // .wav → audio/wav
            "flac" -> MimeTypes.AUDIO_FLAC // .flac → audio/flac
            "amr" -> MimeTypes.AUDIO_AMR_NB // .amr → audio/amr
            "awb" -> MimeTypes.AUDIO_AMR_WB // .awb → audio/amr-wb
            "pcm" -> MimeTypes.AUDIO_RAW // .pcm → audio/raw
            "ac3" -> MimeTypes.AUDIO_AC3 // .ac3 → audio/ac3
            "eac3" -> MimeTypes.AUDIO_E_AC3 // .eac3 → audio/eac3
            "ac4" -> MimeTypes.AUDIO_AC4 // .ac4 → audio/ac4
            "dts" -> MimeTypes.AUDIO_DTS // .dts → audio/vnd.dts
            "dtshd" -> MimeTypes.AUDIO_DTS_HD // .dtshd → audio/vnd.dts.hd
            "dtslbr" -> MimeTypes.AUDIO_DTS_EXPRESS // .dtslbr → audio/vnd.dts.hd;profile=lbr
            "opus" -> MimeTypes.AUDIO_OPUS // .opus → audio/opus
            "vorbis" -> MimeTypes.AUDIO_VORBIS // .vorbis → audio/vorbis
            "mp1" -> MimeTypes.AUDIO_MPEG_L1 // .mp1 → audio/mpeg-L1
            "mp2" -> MimeTypes.AUDIO_MPEG_L2 // .mp2 → audio/mpeg-L2
            "truehd" -> MimeTypes.AUDIO_TRUEHD // .truehd → audio/true-hd
            else -> {
                Log.w("PlayerActivity", "Unknown extension for $url, using default MIME type")
                if (isSubtitle) MimeTypes.APPLICATION_SUBRIP else MimeTypes.AUDIO_AAC 
            }
        }
        return mimeType
    }

    @UnstableApi
    private fun createCombinedMediaSource(videoUrl: String): MediaSource {
        val videoUri = Uri.parse(videoUrl)

        val subtitleConfigs = currentSubtitleTracks?.mapNotNull { track ->
            val url = track["url"] as? String ?: return@mapNotNull null
            val language = track["language"] as? String
            val label = track["label"] as? String
            val mimeType = (track["mimeType"] as? String)?.takeIf { it.isNotBlank() }
                ?: getMimeTypeFromUrl(url, isSubtitle = true)

            MediaItem.SubtitleConfiguration.Builder(Uri.parse(url))
                .setMimeType(mimeType)
                .setLanguage(language)
                .setLabel(label)
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
        } ?: emptyList()

        val mediaItemWithSubtitles = MediaItem.Builder()
            .setUri(videoUri)
            .setSubtitleConfigurations(subtitleConfigs)
            .build()

        val videoWithSubtitlesSource = mediaSourceFactory.createMediaSource(mediaItemWithSubtitles)

        val audioSources = currentAudioTracks?.mapNotNull { track ->
            val url = track["url"] as? String ?: return@mapNotNull null
            val mimeType = (track["mimeType"] as? String)?.takeIf { it.isNotBlank() }
                ?: getMimeTypeFromUrl(url, isSubtitle = false)

                         val audioItem = MediaItem.Builder()
                             .setUri(Uri.parse(url))
                             .setMimeType(mimeType)
                             .build()

            mediaSourceFactory.createMediaSource(audioItem)
        } ?: emptyList()

        return if (audioSources.isNotEmpty()) {
            val allSources = mutableListOf(videoWithSubtitlesSource)
            allSources.addAll(audioSources)
            MergingMediaSource(*allSources.toTypedArray())
        } else {
            videoWithSubtitlesSource
        }
    }
}
package pro.appexp.flutter_tv_media3
import android.os.Bundle
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import androidx.media3.common.util.UnstableApi
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The main plugin class that handles communication between the main Flutter app
 * and the native Android side.
 *
 * This class is responsible for:
 * 1.  Receiving method calls from the main Flutter app, primarily to `openPlayer`.
 * 2.  Creating and caching a new FlutterEngine for the player's UI overlay.
 * 3.  Preparing and launching the `PlayerActivity` with all the necessary data
 *     (playlist, settings, etc.).
 * 4.  Managing the lifecycle of the native activity to which it is attached.
 */
@UnstableApi
class FlutterTvMedia3Plugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var appChannel : MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private val aTag = "Media3TvPlugin"
  private val flutterEngineId = "media3_player_engine_cache_id"
  private val appEngineId = "app_engine_cache_id"
  private val activityChannelUIName = "ui_player_plugin_activity"
  private lateinit var overlayStatusChannel: MethodChannel

  /**
   * Called when the plugin is attached to the FlutterEngine.
   *
   * Initializes the `appChannel` for communication with the main Flutter app and
   * caches the main app's FlutterEngine.
   * @param flutterPluginBinding The binding for the plugin.
   */
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    appChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_player_plugin")
    appChannel.setMethodCallHandler(this)
    val engine = flutterPluginBinding.flutterEngine
    FlutterEngineCache.getInstance().put(appEngineId, engine)
  }

  /**
   * Creates a new FlutterEngine for the UI overlay or retrieves it from the cache.
   *
   * The engine is configured to run the `overlayEntryPoint` from the plugin's
   * Dart code, which initializes the player's UI.
   *
   * @return The cached or newly created [FlutterEngine], or `null` if creation fails.
   */
  private fun getOrCreateCachedEngine(): FlutterEngine? {
    var cachedEngine = FlutterEngineCache.getInstance().get(flutterEngineId)

    if (cachedEngine == null) {
      try {
        cachedEngine = FlutterEngine(context.applicationContext, null, false)

        val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()

        val entrypointFunctionName = "overlayEntryPoint"
        val entrypointLibraryUri = "package:flutter_tv_media3/src/overlay/overlay_main.dart"
        val dartEntrypoint = DartExecutor.DartEntrypoint(
          appBundlePath,
          entrypointLibraryUri,
          entrypointFunctionName
        )

        try {
          cachedEngine.dartExecutor.executeDartEntrypoint(dartEntrypoint)
          cachedEngine.navigationChannel.setInitialRoute("/")
        } catch (e: Exception) {
          cachedEngine.destroy()
          return null
        }

        FlutterEngineCache.getInstance().put(flutterEngineId, cachedEngine)
      } catch (e: Exception) {
        return null
      }
    }
    return cachedEngine
  }

  /**
   * Handles incoming method calls from the Flutter application.
   *
   * Currently, it only handles the `openPlayer` method, which launches the
   * `PlayerActivity` with the provided playlist and settings parameters.
   *
   * @param call The [MethodCall] object containing the method name and arguments.
   * @param result The [Result] object used to send a response back to Flutter.
   */
  @OptIn(UnstableApi::class)
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {

    if (call.method == "openPlayer") {
      val engine = getOrCreateCachedEngine()
      if (engine == null) {
        result.error("ENGINE_ERROR", "Failed to initialize FlutterEngine for overlay.", null)
        return
      }

      val currentActivity = activity
      if (currentActivity == null) {
        result.error("ACTIVITY_UNAVAILABLE", "Cannot start PlayerActivity, activity is null.", null)
        return
      }

      val playlistIndex = call.argument<Int>("playlist_index")
      val playlistLength = call.argument<Int>("playlist_length")
      val playlist = call.argument<String>("playlist")
      val subtitleStyle = call.argument<Map<String, Any?>?>("subtitle_style")
      val clockSettings = call.argument<String?>("clock_settings")
      val playerSettings = call.argument<Map<String, Any?>?>("player_settings")
      val localeStrings = call.argument<String>("locale_strings")
      val subtitleSearch = call.argument<String>("subtitle_search")

      val intent = Intent(currentActivity, PlayerActivity::class.java).apply {

        putExtra("playlist_index", playlistIndex)
        putExtra("playlist_length", playlistLength)
        putExtra("playlist", playlist)
        putExtra("flutter_engine_id", flutterEngineId)
        putExtra("app_engine_id", appEngineId)
        putExtra("clock_settings", clockSettings)
        putExtra("locale_strings", localeStrings)
        putExtra("subtitle_search", subtitleSearch)

        subtitleStyle?.let {
          val subtitleBundle = Bundle().apply {
            putString("foregroundColor", it["foregroundColor"] as? String)
            putString("backgroundColor", it["backgroundColor"] as? String)
            putInt("edgeType", (it["edgeType"] as? Number)?.toInt() ?: -1)
            putString("edgeColor", it["edgeColor"] as? String)
            putDouble("textSizeFraction", (it["textSizeFraction"] as? Number)?.toDouble() ?: 0.0)
            putBoolean("applyEmbeddedStyles", (it["applyEmbeddedStyles"] as? Boolean) ?: false)
            putString("windowColor", it["windowColor"] as? String)
            putInt("bottomPadding", (it["bottomPadding"] as? Number)?.toInt() ?: 0)
            putInt("leftPadding", (it["leftPadding"] as? Number)?.toInt() ?: 0)
            putInt("rightPadding", (it["rightPadding"] as? Number)?.toInt() ?: 0)
            putInt("topPadding", (it["topPadding"] as? Number)?.toInt() ?: 0)
          }
          putExtra("subtitle_style", subtitleBundle)
        }
        playerSettings?.let {
          val playerSettingsBundle = Bundle().apply {
            putInt("videoQuality", (playerSettings["videoQuality"] as? Number)?.toInt() ?: 0)
            (playerSettings["width"] as? Number)?.toInt()?.let { putInt("width", it) }
            (playerSettings["height"] as? Number)?.toInt()?.let { putInt("height", it) }
            (playerSettings["preferredAudioLanguages"] as? List<*>)?.let {
              putStringArrayList("preferredAudioLanguages", ArrayList(it.mapNotNull { lang -> lang as? String }))
            }
            (playerSettings["preferredTextLanguages"] as? List<*>)?.let {
              putStringArrayList("preferredTextLanguages", ArrayList(it.mapNotNull { lang -> lang as? String }))
            }
            putBoolean("forcedAutoEnable", playerSettings["forcedAutoEnable"] as? Boolean ?: true)
            putString("deviceLocale", playerSettings["deviceLocale"] as? String)
            putBoolean("isAfrEnabled", playerSettings["isAfrEnabled"] as? Boolean ?: true)
          }
          putExtra("player_settings", playerSettingsBundle)
        }
      }

      overlayStatusChannel = MethodChannel(engine.dartExecutor.binaryMessenger, activityChannelUIName)

      overlayStatusChannel.setMethodCallHandler { call, result ->
        if (call.method == "onOverlayEntryPointCalled") {

          currentActivity.startActivity(intent)
          result.success(null)

        } else {
          result.notImplemented()
        }
      }

      result.success(null)
    } else {
      result.notImplemented()
    }
  }

  /** Called when the plugin is attached to an Activity. */
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  /** Called before the Activity is destroyed due to a configuration change. */
  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  /** Called after the Activity has been restored following a configuration change. */
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  /** Called when the plugin is detached from the Activity. */
  override fun onDetachedFromActivity() {
    activity = null
  }

  /**
   * Called when the plugin is detached from the FlutterEngine.
   *
   * Cleans up the `appChannel` handler to prevent memory leaks.
   */
  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    appChannel.setMethodCallHandler(null)
  }
}

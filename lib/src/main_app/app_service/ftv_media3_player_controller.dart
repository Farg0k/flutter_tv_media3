import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../flutter_tv_media3.dart';
import '../../entity/find_subtitles_state.dart';
import '../../entity/refresh_rate_info.dart';
import '../../localization/overlay_localizations.dart';

/// A callback to save the current subtitle style settings.
typedef SaveSubtitleStyle = Future<void> Function({required SubtitleStyle subtitleStyle});

/// A callback to save the current clock settings.
typedef SaveClockSettings = Future<void> Function({required ClockSettings clockSettings});

/// A callback to save the current player settings.
typedef SavePlayerSettings = Future<void> Function({required PlayerSettings playerSettings});

/// Defines the signature for the function that searches for external subtitles.
///
/// It receives the [id] of the current media item and should return a list
/// of found subtitles or null if the search fails.
typedef SearchExternalSubtitle = Future<List<MediaItemSubtitle>?> Function({required String id});
typedef LabelSearchExternalSubtitle = Future<String> Function();

/// Manages the communication and state for the Media3 player from the main app.
///
/// This class is a singleton that acts as a bridge between the main Flutter application
/// and the native Android Media3 player, which runs with its own UI in a separate Flutter Engine.
///
/// The primary responsibilities of this controller are:
/// - **Launching the player:** Initiating the player activity with a specific playlist and settings.
/// - **Saving settings:** Persisting user preferences like subtitle styles, player settings, and clock settings that are configured within the player UI.
/// - **Triggering watch time saves:** Invoking callbacks provided by individual media items to save their playback progress.
///
/// All the primary user interactions (like pressing play/pause on the remote) are handled by the UI
/// running in the separate Flutter Engine.
///
/// The playback control methods exposed by this controller (e.g., [playPause], [play], [pause], [seekTo])
/// are intended for **external control scenarios**, such as:
/// - Remote control from another part of the main application.
/// - IP-based control from other devices on the network.
/// - Programmatic control based on application logic outside the player UI.
///
/// It exposes streams for different parts of the player's state:
/// - [playerStateStream]: For the overall state of the player ([PlayerState]).
/// - [playbackStateStream]: For playback-specific state like position and duration ([PlaybackState]).
/// - [mediaMetadataStream]: For the metadata of the currently playing media ([MediaMetadata]).
class FtvMedia3PlayerController {
  /// The method channel used for communication from the native plugin to Flutter.
  static const MethodChannel _pluginChannel = MethodChannel('app_player_plugin');

  /// The method channel used for communication from Flutter to the native player Activity.
  static const MethodChannel _activityChannel = MethodChannel('app_player_plugin_activity');

  VoidCallback? _sleepTimerExec;
  SaveSubtitleStyle? _saveSubtitleStyle;
  SaveClockSettings? _saveClockSettings;
  SavePlayerSettings? _savePlayerSettings;
  SearchExternalSubtitle? _searchExternalSubtitle;
  LabelSearchExternalSubtitle? _labelSearchExternalSubtitle;
  String? _findSubtitlesLabel;
  String? _findSubtitlesStateInfoLabel;
  SubtitleStyle? _subtitleStyle;
  ClockSettings? _clockSettings;
  PlayerSettings? _playerSettings;
  bool _isSearchingSubtitles = false;

  /// The current overall state of the player.
  PlayerState _playerState = PlayerState();

  /// Gets the current overall state of the player.
  PlayerState get playerState => _playerState;

  /// The current playback-specific state (position, duration, etc.).
  PlaybackState _playbackState = PlaybackState();

  /// Gets the current playback-specific state.
  PlaybackState get playbackState => _playbackState;

  /// The metadata for the currently playing media item.
  MediaMetadata _currentMetadata = MediaMetadata();

  /// Gets the metadata for the currently playing media item.
  MediaMetadata get currentMetadata => _currentMetadata;

  /// Stream controller for the overall player state.
  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();

  /// A stream of [PlayerState] updates. Listen to this to get notified of
  /// changes in the player's state (e.g., playlist changes, errors, track updates).
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  /// Stream controller for the playback state.
  final StreamController<PlaybackState> _playbackStateController = StreamController<PlaybackState>.broadcast();

  /// A stream of [PlaybackState] updates. Listen to this to get notified of
  /// changes in playback position, buffering, and duration.
  Stream<PlaybackState> get playbackStateStream => _playbackStateController.stream;

  /// Stream controller for the media metadata.
  final StreamController<MediaMetadata> _mediaMetadataController = StreamController<MediaMetadata>.broadcast();

  /// A stream of [MediaMetadata] updates. Listen to this to get notified when
  /// the metadata of the current media item changes.
  Stream<MediaMetadata> get mediaMetadataStream => _mediaMetadataController.stream;

  /// A map of localized strings passed from the main application.
  Map<String, String> _localeStrings = {};

  /// Sets the localized strings to be used by the player UI.
  set localeStrings(Map<String, String> value) {
    _localeStrings = value;
  }

  /// The singleton instance of the controller.
  static final FtvMedia3PlayerController _instance = FtvMedia3PlayerController._internal();

  /// Factory constructor to return the singleton instance.
  factory FtvMedia3PlayerController() => _instance;

  /// Internal constructor to initialize the method call handlers.
  FtvMedia3PlayerController._internal() {
    _setMethodCallHandler(_handleMethodCall);
    _setPluginMethodCallHandler(_handleMethodCall);
  }

  void setConfig({
    Map<String, String>? localeStrings,
    SubtitleStyle? subtitleStyle,
    PlayerSettings? playerSettings,
    ClockSettings? clockSettings,
    SaveSubtitleStyle? saveSubtitleStyle,
    SaveClockSettings? saveClockSettings,
    SavePlayerSettings? savePlayerSettings,
    VoidCallback? sleepTimerExec,
    SearchExternalSubtitle? searchExternalSubtitle,
    String? findSubtitlesLabel,
    String? findSubtitlesStateInfoLabel,
    LabelSearchExternalSubtitle? labelSearchExternalSubtitle,
  }) {
    if (localeStrings != null) this.localeStrings = localeStrings;
    if (subtitleStyle != null) _subtitleStyle = subtitleStyle;
    if (playerSettings != null) _playerSettings = playerSettings;
    if (clockSettings != null) _clockSettings = clockSettings;
    if (saveSubtitleStyle != null) _saveSubtitleStyle = saveSubtitleStyle;
    if (saveClockSettings != null) _saveClockSettings = saveClockSettings;
    if (savePlayerSettings != null) _savePlayerSettings = savePlayerSettings;
    if (sleepTimerExec != null) _sleepTimerExec = sleepTimerExec;
    if (searchExternalSubtitle != null) _searchExternalSubtitle = searchExternalSubtitle;
    if (findSubtitlesLabel != null) _findSubtitlesLabel = findSubtitlesLabel;
    if (findSubtitlesStateInfoLabel != null) _findSubtitlesStateInfoLabel = findSubtitlesStateInfoLabel;
    if (labelSearchExternalSubtitle != null) _labelSearchExternalSubtitle = labelSearchExternalSubtitle;
  }

  /// Cleans up resources, closing stream controllers and removing method call handlers.
  void close() {
    _stateController.close();
    _playbackStateController.close();
    _mediaMetadataController.close();
    _activityChannel.setMethodCallHandler(null);
    _pluginChannel.setMethodCallHandler(null);
  }

  /// Handles incoming method calls from the native side.
  ///
  /// This method acts as a router, dispatching actions based on the method name
  /// received from the native player. It updates the player state accordingly.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    PlayerState newState = _playerState;
    switch (call.method) {
      case 'getMediaInfo':
        final index = call.arguments['index'] as int?;
        final requestId = MediaRequestManager.newRequest();

        try {
          if (index == null || index < 0 || index >= playerState.playlist.length) {
            throw PlatformException(code: 'INVALID_INDEX', message: 'Invalid playlist index: $index', details: null);
          }

          PlaylistMediaItem item = playerState.playlist[index];

          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(state: 'Cancelled', progress: null, requestId: requestId);
            return null;
          }

          _sendLoadProgressToUI(state: 'Start load link', progress: null, requestId: requestId);

          if (item.getDirectLink != null) {
            try {
              item = await item.getDirectLink!(item: item, onProgress: _sendLoadProgressToUI, requestId: requestId);

              if (!MediaRequestManager.isCurrentRequest(requestId)) {
                _sendLoadProgressToUI(state: 'Cancelled', progress: null, requestId: requestId);
                return null;
              }
            } catch (e) {
              if (MediaRequestManager.isCurrentRequest(requestId)) {
                _sendLoadProgressToUI(state: 'Error: ${e.toString()}', progress: null, requestId: requestId);
                _updateState(_playerState.copyWith(activityReady: true));
              }
              throw PlatformException(code: 'DIRECT_LINK_ERROR', message: e.toString());
            }
          }
          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(state: 'Cancelled', progress: null, requestId: requestId);
            return null;
          }

          _sendLoadProgressToUI(state: 'Link loaded', progress: null, requestId: requestId);
          _updateState(_playerState.copyWith(activityReady: true, playIndex: index));
          return item.toMap();
        } catch (e) {
          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(state: 'Cancelled', progress: null, requestId: requestId);
            return null;
          }
          rethrow;
        }

      case 'onFindSubtitlesRequested':
        if (_isSearchingSubtitles) {
          break; // Ignore if a search is already in progress
        }
        _isSearchingSubtitles = true;

        // Create a base state that preserves the button's visibility and label
        final baseFindState = FindSubtitlesState(
          isVisible: _searchExternalSubtitle != null,
          label: _findSubtitlesLabel,
          stateInfoLabel: _findSubtitlesStateInfoLabel,
        );

        try {
          final mediaId = call.arguments['mediaId'] as String?;
          if (_searchExternalSubtitle == null) {
            break;
          }
          if (mediaId == null) {
            _updateFindSubtitlesState(
              baseFindState.copyWith(status: SubtitleSearchStatus.error, errorMessage: 'Error: mediaId is null.'),
            );
            break;
          }

          try {
            final List<MediaItemSubtitle>? foundSubtitles = await _searchExternalSubtitle!(id: mediaId);
            _findSubtitlesStateInfoLabel =
                _labelSearchExternalSubtitle != null
                    ? await _labelSearchExternalSubtitle!()
                    : _findSubtitlesStateInfoLabel;
            if (foundSubtitles != null && foundSubtitles.isNotEmpty) {
              await setExternalSubtitles(subtitleTracks: foundSubtitles);
              // The UI will show its own success notification when the track list updates.
              // We just reset the state to idle.
              _updateFindSubtitlesState(
                baseFindState.copyWith(status: SubtitleSearchStatus.idle, stateInfoLabel: _findSubtitlesStateInfoLabel),
              );
            } else {
              _updateFindSubtitlesState(
                baseFindState.copyWith(
                  status: SubtitleSearchStatus.error,
                  errorMessage: 'No subtitles found.',
                  stateInfoLabel: _findSubtitlesStateInfoLabel,
                ),
              );
            }
          } catch (e) {
            _updateFindSubtitlesState(
              baseFindState.copyWith(
                status: SubtitleSearchStatus.error,
                errorMessage: 'Error searching subtitles: ${e.toString()}',
              ),
            );
          }
        } finally {
          _isSearchingSubtitles = false;
        }
        break;

      case 'onExternalSubtitleSelected':
        if (_findSubtitlesStateInfoLabel != null) {
          await updateFindSubtitlesStateInfoLabel();
        }
        break;

      case 'onWatchTimeMarked':
        final index = call.arguments['playlist_index'] as int?;
        final int durationMs = call.arguments['duration_ms'] as int? ?? 0;
        final int positionMs = call.arguments['position_ms'] as int? ?? 0;

        if (index != null && index >= 0 && index < _playerState.playlist.length) {
          PlaylistMediaItem item = _playerState.playlist[index];
          if (item.saveWatchTime != null) {
            final durationSec = (durationMs / 1000).round().toInt();
            int positionSec = (positionMs / 1000).round().toInt();
            if (durationSec == 0) return;
            if (positionSec > durationSec) positionSec = durationSec;
            await item.saveWatchTime!(id: item.id, duration: durationSec, position: positionSec, playIndex: index);
          }
        }
        break;
      case 'sleepTimerExec':
        if (_sleepTimerExec != null) _sleepTimerExec!();
        break;
      case 'onError':
        newState = newState.copyWith(
          lastError: call.arguments['message'] as String? ?? 'An unknown playback error occurred.',
          errorCode: call.arguments['code'] as String?,
        );
        break;
      case 'updateSubtitleStyle':
        final styleSettingsMap = call.arguments as Map<dynamic, dynamic>?;
        if (styleSettingsMap != null) {
          final styleSettings = SubtitleStyle.fromMap(styleSettingsMap);
          if (_saveSubtitleStyle != null) _saveSubtitleStyle!(subtitleStyle: styleSettings);
        }
        break;
      case 'saveClockSettings':
        final clockSettingsStr = call.arguments['clock_settings'] as String?;
        if (_saveClockSettings != null) {
          final clockSettingsMap =
              clockSettingsStr != null ? jsonDecode(clockSettingsStr) as Map<String, dynamic> : null;
          final clockSettings = clockSettingsMap != null ? ClockSettings.fromMap(clockSettingsMap) : ClockSettings();
          _saveClockSettings!(clockSettings: clockSettings);
        }
        break;
      case 'savePlayerSettings':
        final playerSettingsMap = call.arguments as Map<dynamic, dynamic>?;
        if (_savePlayerSettings != null) {
          final playerSettings =
              playerSettingsMap != null ? PlayerSettings.fromMap(playerSettingsMap) : PlayerSettings();
          _savePlayerSettings!(playerSettings: playerSettings);
        }
        break;
      case 'onPositionChanged':
        final data = Map<String, dynamic>.from(call.arguments);
        final newPositionMs = (data['position'] as num?)?.toInt();
        final newBufferedMs = (data['bufferedPosition'] as num?)?.toInt();
        final durationMs = (data['duration'] as num?)?.toInt();

        final newPlaybackState = _playbackState.copyWith(
          position: newPositionMs != null ? (newPositionMs / 1000).toInt() : null,
          bufferedPosition: newBufferedMs != null ? (newBufferedMs / 1000).toInt() : null,
          duration: durationMs != null ? (durationMs / 1000).toInt() : null,
        );
        _updatePlaybackState(newPlaybackState);
        return;

      case 'onActivityReady':
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final Map<dynamic, dynamic>? subtitleStyleMap = call.arguments['subtitle_style'];
        final subtitleStyle = subtitleStyleMap != null ? SubtitleStyle.fromMap(subtitleStyleMap) : null;
        final clockSettingsStr = call.arguments['clock_settings'] as String?;
        final clockSettings = clockSettingsStr != null ? ClockSettings.fromMap(jsonDecode(clockSettingsStr)) : null;
        final Map<dynamic, dynamic>? playerSettingsMap = call.arguments['player_settings'];
        PlayerSettings playerSettings =
            playerSettingsMap != null ? PlayerSettings.fromMap(playerSettingsMap) : PlayerSettings();

        final Map<dynamic, dynamic>? volumeStateMap = call.arguments['volume_state'];
        VolumeState? volumeState;
        if (volumeStateMap != null) {
          final current = volumeStateMap['current'] as int?;
          final max = volumeStateMap['max'] as int?;
          final isMute = volumeStateMap['isMute'] as bool?;
          if (current != null && max != null && isMute != null) {
            volumeState = VolumeState(current: current, max: max, isMute: isMute);
          }
        }

        newState = newState.copyWith(
          activityReady: true,
          playIndex: playIndex,
          subtitleStyle: subtitleStyle,
          clockSettings: clockSettings,
          playerSettings: playerSettings,
          volumeState: volumeState,
        );
        break;
      case 'onActivityDestroyed':
        newState = PlayerState(activityDestroyed: true);
        break;
      case 'onBack':
        break;
      case 'loadMediaInfo':
        final playIndex = call.arguments['playlist_index'] as int?;
        newState = PlayerState().copyWith(
          //RESET STATE FOR NEW INDEX
          playIndex: playIndex,
          playlist: newState.playlist,
          clockSettings: newState.clockSettings,
          playerSettings: newState.playerSettings,
        );
        _updatePlaybackState(PlaybackState());
        break;
      case "loadMediaInfoState":
        final state = call.arguments['state'] as String?;
        final progress = call.arguments['progress'] as double?;
        if (state != null) {
          newState = newState.copyWith(loadingStatus: state, loadingProgress: progress);
        }
        break;
      case 'setCurrentTracks':
        final List<dynamic> rawTracks = call.arguments;
        try {
          final List<MediaTrack> tracksList =
              rawTracks
                  .cast<Map<dynamic, dynamic>>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .map(MediaTrack.fromMap)
                  .toList();
          List<VideoTrack> videoTracks = tracksList.whereType<VideoTrack>().toList();
          List<AudioTrack> audioTracks = tracksList.whereType<AudioTrack>().toList();
          List<SubtitleTrack> subtitleTracks = tracksList.whereType<SubtitleTrack>().toList();
          newState = newState.copyWith(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
          );
        } catch (e) {
          newState = newState.copyWith(lastError: e.toString(), errorCode: 'SET_CURRENT_TRACKS_ERROR');
        }
        break;
      case "setCurrentResizeMode":
        final String? zoomValue = call.arguments['zoom'] as String?;
        if (zoomValue == null) {
          newState = newState.copyWith(lastError: 'zoomValue is null in response', errorCode: 'ZOOM_RESPONSE_ERROR');
        } else {
          newState = newState.copyWith(zoom: PlayerZoom.fromString(zoomValue));
        }
        break;
      case "setCurrentSpeed":
        final speedValue = call.arguments['speed'] as double?;
        if (speedValue == null) {
          newState = newState.copyWith(lastError: 'Null speed value in response', errorCode: 'SPEED_RESPONSE_ERROR');
        } else {
          newState = newState.copyWith(speed: speedValue);
        }
        break;
      case "setRepeatMode":
        final repeat = call.arguments['mode'] as String?;
        if (repeat == null) {
          newState = newState.copyWith(lastError: 'Null speed value in response', errorCode: 'SET_REPEAT_MODE');
          return;
        }
        newState = newState.copyWith(repeatMode: RepeatMode.fromString(repeat));
        break;
      case 'onMetadataChanged':
        final rawData = call.arguments as Map<Object?, Object?>?;
        _currentMetadata = MediaMetadata.fromMap(rawData);
        _mediaMetadataController.add(_currentMetadata);
        break;
      case 'onStreamingMetadataUpdated':
        final rawStreamingData = call.arguments as Map<Object?, Object?>?;
        final newStreamingMetadata = StreamingMetadata.fromMap(rawStreamingData);
        _currentMetadata = _currentMetadata.copyWith(streamingMetadata: newStreamingMetadata);
        _mediaMetadataController.add(_currentMetadata);
        break;
      case 'onStateChanged':
        final stateValue = call.arguments['state'] as String?;
        final isLive = call.arguments['isLive'] as bool? ?? false;
        final isSeekable = call.arguments['isSeekable'] as bool? ?? false;
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final speed = (call.arguments['speed'] as num?)?.toDouble();
        final repeatMode = call.arguments['repeatMode'] as String?;
        final shuffleEnabled = call.arguments['shuffleEnabled'] as bool? ?? false;
        newState = newState.copyWith(
          stateValue: StateValue.fromString(stateValue),
          isLive: isLive,
          isSeekable: isSeekable,
          playIndex: playIndex,
          speed: speed,
          repeatMode: RepeatMode.fromString(repeatMode),
          isShuffleModeEnabled: shuffleEnabled,
        );
        break;
      case 'onVolumeChanged':
        final current = call.arguments['current'] as int?;
        final max = call.arguments['max'] as int?;
        final isMute = call.arguments['isMute'] as bool?;
        final volume = (call.arguments['volume'] as num?)?.toDouble();
        if (current != null && max != null && isMute != null && volume != null) {
          newState = newState.copyWith(
            volumeState: VolumeState(current: current, max: max, isMute: isMute, volume: volume),
          );
        }
        break;
      default:
        final err = "UNKNOWN_NATIVE_METHOD: ${call.method} with args: ${call.arguments}";
        _updateState(_playerState.copyWith(lastError: err));
    }
    _updateState(newState);
  }

  /// Sends the progress of loading media information to the UI.
  Future<void> _sendLoadProgressToUI({required String state, double? progress, required int requestId}) async {
    if (requestId == MediaRequestManager.currentRequestId) {
      await _invokeMethodGuarded<void>(_activityChannel, 'loadMediaInfoState', {"state": state, "progress": progress});
    }
  }

  /// Opens the player screen with a given playlist.
  ///
  /// This method pushes the [Media3PlayerScreen] onto the navigation stack
  /// and prepares the player state with the provided playlist.
  Future<void> openPlayer({
    required BuildContext context,
    required List<PlaylistMediaItem> playlist,
    int initialIndex = 0,
    Widget? playerLabel,
  }) async {
    OverlayLocalizations.load(_localeStrings);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Media3PlayerScreen(
              playerLabel: playerLabel,
              playlist: playlist,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  /// Triggers the native Android player activity to open.
  ///
  /// This method serializes the playlist and settings and sends them to the
  /// native side via the method channel to launch the player activity.
  Future<void> openNativePlayer({required List<PlaylistMediaItem> playlist, int initialIndex = 0}) async {
    _playerState = PlayerState();
    if (playlist.isEmpty) {
      _updateState(_playerState.copyWith(lastError: "Cannot open empty playlist."));
      return;
    }
    if (initialIndex < 0 || initialIndex >= playlist.length) {
      _updateState(
        _playerState.copyWith(
          lastError: "Invalid initial index ($initialIndex) for playlist of size ${playlist.length}.",
        ),
      );
      return;
    }
    _updateState(_playerState.copyWith(playlist: playlist, playIndex: initialIndex));

    final playlistMap = playlist.map((e) => e.toMap()).toList();
    final playlistStr = jsonEncode(playlistMap);
    final clockSettingsStr = _clockSettings != null ? jsonEncode(_clockSettings?.toMap()) : null;

    final subtitleSearch =
        FindSubtitlesState(
          isVisible: _searchExternalSubtitle != null,
          label: _findSubtitlesLabel,
          stateInfoLabel: _findSubtitlesStateInfoLabel,
        ).toMap();

    try {
      await _invokeMethodGuarded<void>(_pluginChannel, 'openPlayer', {
        "playlist_index": initialIndex,
        "playlist_length": playlist.length,
        "playlist": playlistStr,
        "subtitle_style": _subtitleStyle?.toMap(),
        "clock_settings": clockSettingsStr,
        "player_settings": _playerSettings?.toMap(),
        "locale_strings": jsonEncode(_localeStrings),
        "subtitle_search": jsonEncode(subtitleSearch),
      });
      _updateState(_playerState.copyWith(playlist: playlist));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: "UNKNOWN_ERROR: $e"));
    }
  }

  /// Updates the overall player state and notifies listeners if it has changed.
  void _updateState(PlayerState newState) {
    if (_playerState != newState) {
      _playerState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_playerState);
      }
    }
  }

  /// Updates the playback-specific state and notifies listeners.
  void _updatePlaybackState(PlaybackState newPlaybackState) {
    _playbackState = newPlaybackState;
    _playbackStateController.add(newPlaybackState);
  }

  /// Sets the method call handler for the activity channel.
  void _setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    _activityChannel.setMethodCallHandler(handler);
  }

  /// Sets the method call handler for the plugin channel.
  void _setPluginMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    _pluginChannel.setMethodCallHandler(handler);
  }

  /// A guarded wrapper for invoking method channel methods to handle exceptions.
  Future<T> _invokeMethodGuarded<T>(MethodChannel channel, String method, [dynamic arguments]) async {
    try {
      final T? result = await channel.invokeMethod<T>(method, arguments);
      return result as T;
    } on PlatformException catch (e, s) {
      throw AppPlayerException('Platform error calling $method: ${e.message}', e, s);
    } catch (e, s) {
      throw AppPlayerException('Error calling $method: $e', e, s);
    }
  }

  /// Toggles the player between play and pause states.
  Future<void> playPause() async => await _invokeMethodGuarded<void>(_activityChannel, 'playPause');

  /// Starts or resumes playback.
  Future<void> play() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'play');
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'pause');
  }

  /// Seeks to a specific position in the current media item.
  ///
  /// [positionSeconds] The position to seek to, in seconds.
  Future<void> seekTo({required int positionSeconds}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'seekTo', {"position": positionSeconds * 1000});
  }

  /// Sets the playback speed.
  Future<void> setSpeed({required double speed}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(_activityChannel, 'setSpeed', {'speed': speed});

      final speedValue = result['speed'] as double?;
      if (speedValue == null) {
        _updateState(
          _playerState.copyWith(lastError: 'Null speed value in response', errorCode: 'SPEED_RESPONSE_ERROR'),
        );
        return;
      }

      _updateState(_playerState.copyWith(speed: speedValue));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message ?? 'Unknown platform error', errorCode: e.code));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: 'Failed to set speed: $e', errorCode: 'SPEED_CHANNEL_ERROR'));
    }
  }

  /// Sets the repeat mode for the player (off, one, all).
  Future<void> setRepeatMode({required RepeatMode repeatMode}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(_activityChannel, 'setRepeatMode', {
        'mode': repeatMode.nativeValue,
      });

      final repeat = result['mode'] as String?;
      if (repeat == null) {
        _updateState(_playerState.copyWith(lastError: 'Null speed value in response', errorCode: 'SET_REPEAT_MODE'));
        return;
      }
      _updateState(_playerState.copyWith(repeatMode: RepeatMode.fromString(repeat)));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message ?? 'Unknown platform error', errorCode: e.code));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: 'Failed to set speed: $e', errorCode: 'SET_REPEAT_MODE'));
    }
  }

  /// Enables or disables shuffle mode.
  Future<void> setShuffleMode(bool enabled) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(_activityChannel, 'setShuffleMode', {
        'enabled': enabled,
      });
      final shuffleEnabled = result['shuffleEnabled'] as bool?;
      if (shuffleEnabled == null) {
        _updateState(_playerState.copyWith(lastError: 'Null speed value in response', errorCode: 'SET_SHUFFLE_MODE'));
        return;
      }
      _updateState(_playerState.copyWith(isShuffleModeEnabled: shuffleEnabled));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message ?? 'Unknown platform error', errorCode: e.code));
    }
  }

  /// Stops playback and releases player resources.
  Future<void> stop() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'stop');
  }

  /// Sets the video zoom/resize mode.
  Future<void> setZoom({required PlayerZoom zoom}) async {
    if (playerState.zoom == PlayerZoom.scale) {
      await _invokeMethodGuarded<void>(_activityChannel, 'setScale');
    }
    await _executeZoomCommand('setResizeMode', {"mode": zoom.nativeValue});
  }

  /// Sets a custom scale for the video.
  Future<void> setScale({required double scaleX, required double scaleY}) async {
    if (playerState.zoom != PlayerZoom.scale) {
      await _invokeMethodGuarded<void>(_activityChannel, 'setResizeMode', {"mode": 'FILL'});
    }
    await _executeZoomCommand('setScale', {"scaleX": scaleX, "scaleY": scaleY});
  }

  /// Saves and applies new clock settings.
  Future<void> setClockSettings({ClockSettings? clockSettings}) async {
    final clockSettingsMap = clockSettings?.toMap();
    final clockSettingsStr = clockSettingsMap != null ? jsonEncode(clockSettingsMap) : null;
    try {
      await _invokeMethodGuarded<Map<dynamic, dynamic>>(_activityChannel, 'saveClockSettings', {
        "clock_settings": clockSettingsStr,
      });
      _updateState(_playerState.copyWith(clockSettings: clockSettings));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: e.toString(), errorCode: 'UPDATE_CLOCK_SETTINGS_ERROR'));
    }
  }

  /// Applies a new subtitle style.
  Future<void> updateSubtitleStyle({SubtitleStyle? subtitleStyle}) async {
    final subtitleStyleMap = subtitleStyle?.toMap();
    try {
      final dynamic result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(
        _activityChannel,
        'setSubtitleStyle',
        subtitleStyleMap,
      );

      if (result is! Map) {
        _playerState.copyWith(lastError: 'Unknown or null result type', errorCode: 'UPDATE_SUBTITLE_STYLE_ERROR');
        return;
      }
      final Map map = result;
      final subtitleStyle = SubtitleStyle.fromMap(map);
      _updateState(_playerState.copyWith(subtitleStyle: subtitleStyle));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message, errorCode: e.code));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: e.toString(), errorCode: 'UPDATE_SUBTITLE_STYLE_ERROR'));
    }
  }

  /// Saves and applies new player settings.
  Future<void> setPlayerSettings({PlayerSettings? playerSettings}) async {
    final playerSettingsMap = playerSettings?.toMap();
    try {
      await _invokeMethodGuarded<void>(_activityChannel, 'savePlayerSettings', playerSettingsMap);
      _updateState(_playerState.copyWith(playerSettings: playerSettings));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message, errorCode: e.code));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: e.toString(), errorCode: 'UPDATE_PLAYER_SETTINGS_ERROR'));
    }
  }

  /// Helper to execute a zoom-related command and handle the result.
  Future<void> _executeZoomCommand(String method, Map<String, dynamic> args) async {
    try {
      final dynamic result = await _invokeMethodGuarded<dynamic>(_activityChannel, method, args);
      _updateState(_handleZoomResult(result));
    } on PlatformException catch (e) {
      _updateState(_playerState.copyWith(lastError: e.message, errorCode: e.code));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: e.toString(), errorCode: 'ZOOM_CHANNEL_ERROR'));
    }
  }

  /// Helper to process the result from a zoom command.
  PlayerState _handleZoomResult(dynamic result) {
    if (result is! Map) {
      return _playerState.copyWith(lastError: 'Unknown or null result type', errorCode: 'ZOOM_RESPONSE_ERROR');
    }

    final Map<Object?, Object?> resultMap = result;
    final String? zoomValue = resultMap['zoom'] as String?;

    if (zoomValue == null) {
      return _playerState.copyWith(lastError: 'zoomValue is null in response', errorCode: 'ZOOM_RESPONSE_ERROR');
    }
    return _playerState.copyWith(zoom: PlayerZoom.fromString(zoomValue));
  }

  /// Fetches the currently available tracks (video, audio, subtitle) from the player.
  Future<List<MediaTrack>> getCurrentTracks() async {
    final result = await _invokeMethodGuarded<dynamic>(_activityChannel, 'getCurrentTracks');
    final tracks = List<Map<String, dynamic>>.from(result);
    return tracks.map((track) => MediaTrack.fromMap(track)).toList();
  }

  /// Selects the specified audio track.
  Future<void> selectAudioTrack({AudioTrack? track}) async => await _selectTrack(track);

  /// Selects the specified subtitle track.
  Future<void> selectSubtitleTrack({SubtitleTrack? track}) async => await _selectTrack(track);

  /// Selects the specified video track.
  Future<void> selectVideoTrack({VideoTrack? track}) async {
    if (track?.isExternal == true) {
      final url = track?.url;
      if (url != null) {
        await _invokeMethodGuarded<void>(_activityChannel, 'selectExternalVideoTrack', {'url': url});
      } else {
        throw ArgumentError('External video track must have a valid URL.');
      }
      return;
    }
    await _selectTrack(track);
  }

  /// Helper to select a track of any type.
  Future<void> _selectTrack(MediaTrack? track) async {
    final trackIndex = track?.index;
    final groupIndex = track?.groupIndex;
    final trackType = track?.trackType;
    if (trackIndex == null || groupIndex == null || trackType == null) {
      throw ArgumentError('You must provide a track index or a track with index.');
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'selectTrack', {
      "trackType": trackType,
      'trackIndex': trackIndex,
      'groupIndex': groupIndex,
    });
  }

  /// Fetches the latest metadata from the player.
  Future<void> getMetaData() async {
    final result = await _invokeMethodGuarded<dynamic>(_activityChannel, 'getMetadata');
    final Map<Object?, Object?> resultMap = result;
    _currentMetadata = MediaMetadata.fromMap(resultMap);
    _mediaMetadataController.add(_currentMetadata);
  }

  /// Resets the last error state.
  void resetError() => _updateState(_playerState.copyWith(resetError: true));

  /// Skips to the next item in the playlist.
  Future<void> playNext() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playNext');
  }

  /// Skips to the previous item in the playlist.
  Future<void> playPrevious() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playPrevious');
  }

  /// Plays the item at the specified index in the playlist.
  Future<void> playSelectedIndex({required int index}) async {
    if (_playerState.playlist.length > index && index >= 0) {
      await _invokeMethodGuarded<void>(_activityChannel, 'playSelectedIndex', {"index": index});
    } else {
      final newState = _playerState.copyWith(
        stateValue: StateValue.error,
        lastError: 'Invalid index: $index',
        errorCode: 'OverlayPlayerController',
      );
      _updateState(newState);
    }
  }

  /// Sets external subtitle tracks for the current media item.
  Future<void> setExternalSubtitles({required List<MediaItemSubtitle> subtitleTracks}) async {
    if (subtitleTracks.isNotEmpty) {
      final subtitleTracksMap = subtitleTracks.map((e) => e.toMap()).toList();
      await _invokeMethodGuarded<void>(_activityChannel, 'setExternalSubtitles', {"subtitleTracks": subtitleTracksMap});
    }
  }

  /// Sets external audio tracks for the current media item.
  Future<void> setExternalAudio({required List<MediaItemAudioTrack> audioTracks}) async {
    if (audioTracks.isNotEmpty) {
      final subtitleTracksMap = audioTracks.map((e) => e.toMap()).toList();
      await _invokeMethodGuarded<void>(_activityChannel, 'setExternalAudio', {"audioTracks": subtitleTracksMap});
    }
  }

  /// Sends a custom string to be displayed in the overlay.
  ///
  /// This string will be shown in the TimeLinePanel.
  Future<void> sendCustomInfoToOverlay(String text) async {
    if (_playerState.activityReady != true) return;
    await _invokeMethodGuarded<void>(_activityChannel, 'onReceiveInfoText', {'text': text});
  }

  /// Sends the current state of the subtitle search to the UI overlay.
  Future<void> _updateFindSubtitlesState(FindSubtitlesState state) async {
    if (_playerState.activityReady != true) return;
    await _invokeMethodGuarded<void>(_activityChannel, 'onSubtitleSearchStateChanged', state.toMap());
  }

  /// Updates the info label for the subtitle search state and notifies the UI.
  Future<void> updateFindSubtitlesStateInfoLabel() async {
    _findSubtitlesStateInfoLabel =
        _labelSearchExternalSubtitle != null ? await _labelSearchExternalSubtitle!() : _findSubtitlesStateInfoLabel;
    final updatedState = FindSubtitlesState(
      isVisible: _searchExternalSubtitle != null,
      label: _findSubtitlesLabel,
      stateInfoLabel: _findSubtitlesStateInfoLabel,
      status: SubtitleSearchStatus.idle,
    );
    await _updateFindSubtitlesState(updatedState);
  }

  /// Retrieves the supported and active refresh rates from the display.
  ///
  /// Returns a map containing a list of supported rates and the currently
  /// active rate.
  Future<RefreshRateInfo> getRefreshRateInfo() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(_activityChannel, 'getRefreshRateInfo');
    final map = result.map((key, value) => MapEntry(key.toString(), value));
    return RefreshRateInfo.fromMap(map);
  }

  /// Manually sets the display's refresh rate.
  ///
  /// This method will fail if Auto Frame Rate (AFR) is enabled.
  ///
  /// - [rate]: The desired refresh rate.
  Future<void> setManualFrameRate(double rate) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setManualFrameRate', {'rate': rate});
  }

  /// Fetches the current volume state from the native player.
  Future<VolumeState> getVolume() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(_activityChannel, 'getVolume');
    final current = result['current'] as int?;
    final max = result['max'] as int?;
    final isMute = result['isMute'] as bool?;
    final volume = (result['volume'] as num?)?.toDouble();
    if (current != null && max != null && isMute != null && volume != null) {
      final volumeState = VolumeState(current: current, max: max, isMute: isMute, volume: volume);
      _updateState(_playerState.copyWith(volumeState: volumeState));
      return volumeState;
    }
    throw AppPlayerException('Failed to parse volume data from native.');
  }

  /// Sets the volume on the native player.
  /// [volume] The volume level to set, from 0.0 to 1.0.
  Future<void> setVolume({required double volume}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setVolume', {'volume': volume.clamp(0.0, 1.0)});
  }

  /// Mutes or unmutes the audio on the native player.
  /// [mute] True to mute, false to unmute.
  Future<void> setMute({required bool mute}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setMute', {'mute': mute});
  }

  /// Toggles the mute state on the native player.
  Future<void> toggleMute() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(_activityChannel, 'toggleMute');
    final isMute = result['isMute'] as bool?;
    if (isMute != null) {
      _updateState(_playerState.copyWith(volumeState: _playerState.volumeState.copyWith(isMute: isMute)));
    }
  }
}

/// A custom exception for errors originating from the FtvMedia3PlayerController.
class AppPlayerException implements Exception {
  final String message;
  final dynamic originalException;
  final StackTrace? originalStackTrace;
  AppPlayerException(this.message, [this.originalException, this.originalStackTrace]);

  @override
  String toString() {
    String result = 'AppPlayerException: $message';
    if (originalException != null) {
      result += '\nOriginal Exception: $originalException';
    }
    return result;
  }
}

/// A custom exception for network-related errors in the player.
class AppNetworkException extends AppPlayerException {
  AppNetworkException(super.message);
}

/// Manages request IDs to prevent race conditions when fetching media.
///
/// When a new media item is requested, a new ID is generated. If a response
/// arrives for a previous request, it can be ignored.
class MediaRequestManager {
  static int _lastRequestId = 0;

  /// The ID of the most recent request.
  static int get currentRequestId => _lastRequestId;

  /// Generates a new, unique request ID.
  static int newRequest() => ++_lastRequestId;

  /// Checks if the given [requestId] is the most current one.
  static bool isCurrentRequest(int requestId) => requestId == _lastRequestId;
}

import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:ui';

/// Represents player settings that affect track selection and video quality.
///
/// This class contains parameters that the native player uses to
/// automatically select the best audio and subtitle tracks according to
/// user preferences, and to limit the video quality.
///
/// A `PlayerSettings` object is passed to the player before it is created.
/// The application can save these settings (e.g., in SharedPreferences)
/// to restore the user's choice on subsequent launches. If the settings
/// are not provided, the player uses default values.
class PlayerSettings {
  PlayerSettings({
    this.videoQuality = VideoQuality.max,
    this.preferredAudioLanguages,
    this.preferredTextLanguages,
    this.forcedAutoEnable = true,
    this.deviceLocale,
    this.isAfrEnabled = false,
  });

  /// The desired video quality. The player will try to select a stream
  /// that does not exceed the width and height limits specified here.
  final VideoQuality videoQuality;

  /// A list of preferred languages for audio tracks, ordered by priority.
  /// Uses ISO 639-1 language codes (e.g., "de", "en").
  final List<String>? preferredAudioLanguages;

  /// A list of preferred languages for subtitles, ordered by priority.
  /// Uses ISO 639-1 language codes (e.g., "de", "en").
  final List<String>? preferredTextLanguages;

  /// A flag indicating whether to automatically enable subtitles
  /// if they are marked as "forced".
  final bool forcedAutoEnable;

  /// The device's locale. Used as an additional criterion for selecting
  /// language tracks if the `preferred...Languages` lists are not provided.
  final Locale? deviceLocale;

  /// A flag that enables or disables the Auto Frame Rate (AFR) feature.
  /// When enabled, the player will attempt to match the display's refresh
  /// rate to the video's frame rate for smoother playback.
  /// Defaults to `false`.
  final bool isAfrEnabled;

  Map<String, dynamic> toMap() {
    return {
      'videoQuality': videoQuality.index,
      'width': videoQuality.width,
      'height': videoQuality.height,
      'preferredAudioLanguages': preferredAudioLanguages,
      'preferredTextLanguages': preferredTextLanguages,
      'forcedAutoEnable': forcedAutoEnable,
      'deviceLocale': _localeToString(deviceLocale),
      'isAfrEnabled': isAfrEnabled,
    };
  }

  factory PlayerSettings.fromMap(Map<dynamic, dynamic> map) {
    return PlayerSettings(
      videoQuality: VideoQuality.fromIndex(map['videoQuality'] as int?),
      preferredAudioLanguages:
          (map['preferredAudioLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      preferredTextLanguages:
          (map['preferredTextLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      forcedAutoEnable: map['forcedAutoEnable'] as bool? ?? true,
      deviceLocale: _localeFromString(map['deviceLocale']),
      isAfrEnabled: map['isAfrEnabled'] as bool? ?? false,
    );
  }

  PlayerSettings copyWith({
    VideoQuality? videoQuality,
    List<String>? preferredAudioLanguages,
    List<String>? preferredTextLanguages,
    bool? forcedAutoEnable,
    bool? isAfrEnabled,
  }) {
    return PlayerSettings(
      videoQuality: videoQuality ?? this.videoQuality,
      preferredAudioLanguages:
          preferredAudioLanguages ?? this.preferredAudioLanguages,
      preferredTextLanguages:
          preferredTextLanguages ?? this.preferredTextLanguages,
      forcedAutoEnable: forcedAutoEnable ?? this.forcedAutoEnable,
      isAfrEnabled: isAfrEnabled ?? this.isAfrEnabled,
    );
  }

  @override
  String toString() {
    return '''PlayerSettings{
      videoQuality: $videoQuality, 
      preferredAudioLanguages: $preferredAudioLanguages, 
      preferredTextLanguages: $preferredTextLanguages, 
      forcedAutoEnable: $forcedAutoEnable,
      isAfrEnabled: $isAfrEnabled
    }''';
  }

  String? _localeToString(Locale? locale) {
    if (locale == null) return null;
    return locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
  }

  static Locale? _localeFromString(String? localeString) {
    if (localeString == null || localeString.isEmpty) return null;
    final parts = localeString.split('_');
    return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }
}

/// Defines video quality levels to limit stream selection.
///
/// Each level (except `max` and `min`) has associated
/// width and height values that are used by the player for filtering.
enum VideoQuality {
  /// Maximum available quality (no restrictions).
  max("videoQualityMax", 0, 0),

  /// High quality (up to ~1080p).
  high("videoQualityHigh", 1999, 1100),

  /// Medium quality (up to ~720p).
  medium("videoQualityMedium", 1400, 800),

  /// Low quality (up to ~540p).
  low("videoQualityLow", 900, 550),

  /// Minimum available quality.
  min("videoQualityMin", 0, 0);

  const VideoQuality(this.key, this.width, this.height);

  /// The key for localizing the quality name.
  final String key;

  /// The localized quality name for display in the UI.
  String get title => OverlayLocalizations.get(key);

  /// The maximum width for this quality level.
  final int? width;

  /// The maximum height for this quality level.
  final int? height;

  static VideoQuality fromIndex(int? index) =>
      index != null ? values[index] : values[0];

  static VideoQuality changeValue({
    required int index,
    required int direction,
  }) {
    final length = VideoQuality.values.length;
    final newIndex = (index + direction + length) % length;
    return VideoQuality.values[newIndex];
  }
}

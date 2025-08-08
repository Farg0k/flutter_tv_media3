import 'epg_channel.dart';

/// An asynchronous callback function used to obtain a direct, playable media link.
///
/// This is useful for scenarios where the initial [url] in a [PlaylistMediaItem]
/// is indirect, temporary, or requires server-side generation.
///
/// - [item]: The initial [PlaylistMediaItem] for which to get the direct link.
/// - [onProgress]: An optional callback to notify the UI of the link retrieval progress (e.g., "Loading...", "Error").
/// - [requestId]: A unique identifier for the request to avoid race conditions.
///
/// Returns a [Future] that completes with an updated [PlaylistMediaItem] containing the direct [url].
typedef GetDirectLinkCallback =
    Future<PlaylistMediaItem> Function({
      required PlaylistMediaItem item,
      Function({required String state, double? progress, required int requestId})? onProgress,
      required int requestId,
    });

/// Represents a single playable item in a playlist.
///
/// This class contains all the necessary information for the native player
/// to load and play media content. This includes URLs, metadata
/// (title, description), track information, and custom callbacks.
///
/// Objects of this class are immutable. To create a modified
/// copy, use the [copyWith] method.
class PlaylistMediaItem {
  /// A unique identifier for the media item. Used for saving
  /// playback progress and other unique associations.
  final String id;

  /// The URL of the media resource. This can be a direct link to a file/stream
  /// or an indirect link that will be processed via [getDirectLink].
  final String url;

  /// A text label for this item, which can be used in the UI.
  final String? label;

  /// The main title of the media (e.g., the name of a movie or series).
  final String? title;

  /// A subtitle that can be used as an episode title.
  final String? subTitle;

  /// A full description of the media item.
  final String? description;

  /// The name of the performer or artist (for music tracks).
  final String? artistName;

  /// The name of the track (for music).
  final String? trackName;

  /// The name of the album (for music).
  final String? albumName;

  /// The release year of the album.
  final String? albumYear;

  /// The URL for the cover art image.
  final String? coverImg;

  /// The URL for a placeholder image shown during loading.
  final String? placeholderImg;

  /// The initial playback position in seconds.
  /// Used to resume playback.
  final int? startPosition;

  /// The total duration of the media in seconds.
  final int? duration;

  /// HTTP headers to be used when requesting the [url].
  final Map<String, String>? headers;

  /// A custom User-Agent for HTTP requests.
  final String? userAgent;

  /// A map of available video resolutions.
  /// The key is the name (e.g., "720p"), and the value is the URL to the stream.
  final Map<String, String>? resolutions;

  /// A list of external subtitle tracks.
  final List<MediaItemSubtitle>? subtitles;

  /// A list of external audio tracks.
  final List<MediaItemAudioTrack>? audioTracks;

  /// A callback to get a direct playback link.
  /// If `null`, the [url] is considered direct.
  final GetDirectLinkCallback? getDirectLink;

  /// A flag indicating whether to save the watch time for this item.
  final bool saveWatchTime;

  /// The type of the media item. Used in the UI to display a corresponding icon.
  final MediaItemType mediaItemType;

  /// A list of EPG (Electronic Program Guide) programs associated with this
  /// item if it is a TV channel.
  final List<EpgProgram>? programs;

  PlaylistMediaItem({
    required this.id,
    required this.url,
    this.label,
    this.title,
    this.subTitle,
    this.description,
    this.artistName,
    this.albumName,
    this.trackName,
    this.albumYear,
    this.coverImg,
    this.placeholderImg,
    this.startPosition,
    this.duration,
    this.headers,
    this.userAgent,
    this.resolutions,
    this.subtitles,
    this.audioTracks,
    this.saveWatchTime = true,
    this.getDirectLink,
    this.mediaItemType = MediaItemType.video,
    this.programs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'label': label,
      'title': title,
      'subTitle': subTitle,
      'description': description,
      'artistName': artistName,
      'albumName': albumName,
      'trackName': trackName,
      'albumYear': albumYear,
      'coverImg': coverImg,
      'placeholderImg': placeholderImg,
      'startPosition': startPosition,
      'duration': duration,
      'headers': headers,
      'resolutions': resolutions,
      'userAgent': userAgent,
      'subtitles': subtitles?.map((sub) => sub.toMap()).toList(),
      'audioTracks': audioTracks?.map((audio) => audio.toMap()).toList(),
      'saveWatchTime': saveWatchTime,
      'mediaItemType': mediaItemType.index,
      'programs': programs?.map(((program) => program.toMap())).toList(),
    };
  }

  factory PlaylistMediaItem.fromMap(Map<String, dynamic> json) {
    return PlaylistMediaItem(
      id: json['id'] as String,
      url: json['url'] as String,
      label: json['label'] as String?,
      title: json['title'] as String?,
      subTitle: json['subTitle'] as String?,
      description: json['description'] as String?,
      artistName: json['artistName'] as String?,
      albumName: json['albumName'] as String?,
      trackName: json['trackName'] as String?,
      albumYear: json['albumYear'] as String?,
      coverImg: json['coverImg'] as String?,
      placeholderImg: json['placeholderImg'] as String?,
      resolutions: (json['resolutions'] as Map?)?.cast<String, String>(),
      headers: (json['headers'] as Map?)?.cast<String, String>(),
      startPosition: json['startPosition'] as int?,
      duration: json['duration'] as int?,
      userAgent: json['userAgent'] as String?,
      subtitles:
          (json['subtitles'] as List?)?.map((sub) => MediaItemSubtitle.fromMap(sub as Map<String, dynamic>)).toList(),
      audioTracks:
          (json['audioTracks'] as List?)
              ?.map((audio) => MediaItemAudioTrack.fromMap(audio as Map<String, dynamic>))
              .toList(),
      saveWatchTime: json['saveWatchTime'] as bool? ?? true,
      mediaItemType: MediaItemType.fromIndex(json['mediaItemType'] as int? ?? 0),
      programs:
          (json['programs'] as List?)?.map((program) => EpgProgram.fromMap(program as Map<String, dynamic>)).toList(),
    );
  }

  PlaylistMediaItem copyWith({
    String? id,
    String? url,
    String? label,
    String? title,
    String? subTitle,
    String? description,
    String? artistName,
    String? trackName,
    String? albumName,
    String? albumYear,
    String? coverImg,
    String? placeholderImg,
    int? startPosition,
    int? duration,
    Map<String, String>? headers,
    String? userAgent,
    Map<String, String>? resolutions,
    List<MediaItemSubtitle>? subtitles,
    List<MediaItemAudioTrack>? audioTracks,
    GetDirectLinkCallback? getDirectLink,
    bool? saveWatchTime,
    MediaItemType? mediaItemType,
  }) {
    return PlaylistMediaItem(
      id: id ?? this.id,
      url: url ?? this.url,
      label: label ?? this.label,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      trackName: trackName ?? this.trackName,
      albumYear: albumYear ?? this.albumYear,
      coverImg: coverImg ?? this.coverImg,
      placeholderImg: placeholderImg ?? this.placeholderImg,
      startPosition: startPosition ?? this.startPosition,
      duration: duration ?? this.duration,
      headers: headers ?? this.headers,
      userAgent: userAgent ?? this.userAgent,
      resolutions: resolutions ?? this.resolutions,
      subtitles: subtitles ?? this.subtitles,
      audioTracks: audioTracks ?? this.audioTracks,
      getDirectLink: getDirectLink ?? this.getDirectLink,
      saveWatchTime: saveWatchTime ?? this.saveWatchTime,
      mediaItemType: mediaItemType ?? this.mediaItemType,
    );
  }
}

/// Represents a single external subtitle track.
class MediaItemSubtitle {
  /// The URL to the subtitle file (e.g., .srt, .vtt).
  final String url;

  /// The language code (e.g., "de", "en").
  final String language;

  /// The track name displayed in the UI (e.g., "German (Forced)").
  final String label;

  /// The mime type of the subtitle file.
  final String? mimeType;

  MediaItemSubtitle({required this.url, required this.language, required this.label, this.mimeType});

  Map<String, dynamic> toMap() {
    return {'url': url, 'language': language, 'label': label, 'mimeType': mimeType};
  }

  factory MediaItemSubtitle.fromMap(Map<String, dynamic> json) {
    return MediaItemSubtitle(
      url: json['url'] as String,
      language: json['language'] as String,
      label: json['label'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Represents a single external audio track.
class MediaItemAudioTrack {
  /// The URL to the audio file.
  final String url;

  /// The language code (e.g., "de", "en").
  final String language;

  /// The track name displayed in the UI (e.g., "German 5.1").
  final String label;


  /// The mime type of the audio file.
  final String? mimeType;

  MediaItemAudioTrack(
      {required this.url,
      required this.language,
      required this.label,
      this.mimeType});

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'language': language,
      'label': label,
      'mimeType': mimeType
    };
  }

  factory MediaItemAudioTrack.fromMap(Map<String, dynamic> json) {
    return MediaItemAudioTrack(
      url: json['url'] as String,
      language: json['language'] as String,
      label: json['label'] as String,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Defines the type of the media item to display a corresponding icon in the UI.
enum MediaItemType {
  /// A regular video file or video stream.
  video,
  /// An audio file or audio stream.
  audio,
  /// A live TV channel stream.
  tvStream;

  static MediaItemType fromIndex(int? index) => index != null ? values[index] : values[0];
}
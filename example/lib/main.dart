import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_tv_media3/flutter_tv_media3.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media3 Plugin Example',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// Mock function to simulate searching for external subtitles.
///
/// This function introduces a 2-second delay to mimic a network request.
/// It then randomly returns one of three outcomes:
/// 1. A list of two subtitle tracks (success).
/// 2. An empty list (success, but no subtitles found).
/// 3. Throws an exception (failure).
Future<List<MediaItemSubtitle>?> _mockSearchSubtitles({required String id}) async {
  debugPrint('Searching subtitles for media ID: $id');
  await Future.delayed(const Duration(seconds: 2));

  final random = Random();
  final outcome =  random.nextInt(3); // Generates 0, 1, or 2

  switch (outcome) {
    case 0:
      debugPrint('Mock search: Success - found 2 subtitles.');
      return [
        MediaItemSubtitle(
          url: 'https://raw.githubusercontent.com/mtoczko/hls-test-streams/refs/heads/master/test-vtt/text/1.vtt',
          language: 'en',
          label: 'English (Found)',
        ),
        MediaItemSubtitle(
          url: 'https://raw.githubusercontent.com/mtoczko/hls-test-streams/refs/heads/master/test-vtt/text/1.vtt',
          language: 'uk',
          label: 'Ukrainian (Found)',
        ),
      ];
    case 1:
      debugPrint('Mock search: Success - no subtitles found.');
      return []; // Represents a successful search that found nothing
    case 2:
    default:
      debugPrint('Mock search: Failure - throwing an exception.');
      throw Exception('Failed to connect to the subtitle server.');
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final controller = AppPlayerController();
  int lastPlayedIndex = 0;
  late StreamSubscription<PlayerState> _playerStateSubscription;
  Timer? _infoTimer;

  final List<PlaylistMediaItem> mediaItems = [
    PlaylistMediaItem(
      id: 'bbb_hls_res',
      label: 'Sintel HLS (Sintel with Subtitles)',
      title: 'Sintel',
      subTitle: 'Sintel with Subtitles',
      description: 'The film follows a girl named Sintel who is searching for a baby dragon she calls Scales.',
      url: 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
      startPosition: 60,
      duration: 888,
      headers: {'Referer': 'https://example.com/player'},
      placeholderImg: 'https://media.themoviedb.org/t/p/w1066_and_h600_bestv2/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg',
      coverImg: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/636px-Sintel_poster.jpg',
      subtitles: [
        MediaItemSubtitle(
          url: 'https://raw.githubusercontent.com/mtoczko/hls-test-streams/refs/heads/master/test-vtt/text/1.vtt',
          language: 'en',
          label: 'English (external)',
        ),

      ],
      audioTracks: [
        MediaItemAudioTrack(
          url: 'https://download.samplelib.com/mp3/sample-15s.mp3',
          language: 'en',
          label: 'US (external)',
          mimeType: 'audio/mpeg',
        ),
      ],
    ),
    PlaylistMediaItem(
      id: 'bbb_mp4_res',
      label: 'getDirectLink (success)',
      url: 'myapp://needs_resolving/video1',
      startPosition: 0,
      getDirectLink: ({
        required PlaylistMediaItem item,
        Function({required String state, double? progress, required int requestId})? onProgress,
        required int requestId,
      }) async {
        onProgress?.call(requestId: requestId, state: 'downloading 1', progress: 0.1);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 2', progress: 0.2);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 3', progress: 0.3);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 4', progress: 0.4);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 5', progress: 0.5);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 6', progress: 0.6);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 7', progress: 0.7);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 8', progress: 0.8);
        await Future.delayed(const Duration(seconds: 1));
        onProgress?.call(requestId: requestId, state: 'downloading 9', progress: 0.9);
        await Future.delayed(const Duration(seconds: 1));
        final resolved = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        return item.copyWith(url: resolved);
      },
    ),
    PlaylistMediaItem(
      id: 'bbb_mp4_res_error',
      label: 'getDirectLink (error)',
      url: 'myapp://resolving_error/video2',
      getDirectLink: ({
        required PlaylistMediaItem item,
        Function({required String state, double? progress, required int requestId})? onProgress,
        required int requestId,
      }) async {
        await Future.delayed(const Duration(milliseconds: 300));
        throw Exception("Failed to get direct link from API");
      },
    ),
    PlaylistMediaItem(
      id: 'bbb_mp4_res',
      label: 'MP4 (BBB with Resolutions) MP4 (BBB with Resolutions)',
      url: 'https://www.sample-videos.com/video321/mp4/360/big_buck_bunny_360p_30mb.mp4',
      resolutions: {
        '480p': 'https://www.sample-videos.com/video321/mp4/480/big_buck_bunny_480p_30mb.mp4',
        '720p': 'https://www.sample-videos.com/video321/mp4/720/big_buck_bunny_720p_30mb.mp4',
        '360p': 'https://www.sample-videos.com/video321/mp4/360/big_buck_bunny_360p_30mb.mp4',
        '240': 'https://www.sample-videos.com/video321/mp4/240/big_buck_bunny_240p_30mb.mp4',
      },
      headers: {'User-Agent': 'MyApp/1.0'},
    ),
  ];

  Future<void> saveSubtitleStyle({required SubtitleStyle subtitleStyle}) async {
    debugPrint(subtitleStyle.toString());
  }

  Future<void> saveClockSettings({required ClockSettings clockSettings}) async {
    debugPrint(clockSettings.toString());
  }

  Future<void> saveWatchTime({required String id, required int duration, required int position}) async {
    debugPrint('SAVE WATCH TIME: id=$id, duration=$duration, position=$position');
  }

  Future<void> savePlayerSettings({required PlayerSettings playerSettings}) async {
    debugPrint(playerSettings.toString());
  }

  void sleepTimerExec() {
    debugPrint('SLEEP TIMER EXEC!!!!!!!!!!!!!!!!!!!');
  }

  @override
  void initState() {
    super.initState();
    Locale? deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;

    final localeStrings = {'loading': 'Wird geladen…'};
    final subtitleStyle = SubtitleStyle(foregroundColor: BasicColors.yellow);

    final playerSettings = PlayerSettings(
      videoQuality: VideoQuality.high,
      preferredAudioLanguages: [deviceLocale.languageCode],
      preferredTextLanguages: [deviceLocale.languageCode],
      forcedAutoEnable: true,
      deviceLocale: deviceLocale,
      isAfrEnabled: true,
    );
    final clockSettings = ClockSettings(clockPosition: ClockPosition.random);

    controller.init(
      localeStrings: localeStrings,
      subtitleStyle: subtitleStyle,
      saveSubtitleStyle: saveSubtitleStyle,
      playerSettings: playerSettings,
      clockSettings: clockSettings,
      saveClockSettings: saveClockSettings,
      saveWatchTime: saveWatchTime,
      savePlayerSettings: savePlayerSettings,
      sleepTimerExec: sleepTimerExec,
      searchExternalSubtitle: _mockSearchSubtitles,
      findSubtitlesLabel: 'Find on MockSubtitles.com',
      findSubtitlesStateInfoLabel:'10/10' ,
      labelSearchExternalSubtitle: labelSearchExternalSubtitle
    );

    //This listener is required to update the playlist screen.
    _playerStateSubscription = controller.playerStateStream.listen((PlayerState state) {
      setState(() {
        lastPlayedIndex = state.playIndex;
      });
    });

    _infoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final now = DateTime.now();
      final timeString =
          "${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      controller.sendCustomInfoToOverlay('Last update: $timeString');
    });
  }

  Future<String> labelSearchExternalSubtitle()async{
      return '9/10';
    }

  @override
  void dispose() {
    _infoTimer?.cancel();
    _playerStateSubscription.cancel();
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media3 Plugin Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        key: Key(lastPlayedIndex.toString()), //**need for rebuild after change lastPlayedIndex**
        itemCount: mediaItems.length,
        itemBuilder: (BuildContext context, int index) {
          final mediaItem = mediaItems[index];
          return ListTile(
            autofocus: index == lastPlayedIndex,
            title: Text(mediaItem.label ?? 'No Label'),
            subtitle: Text(mediaItem.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text('${index + 1}'),
            ),
            onTap: () => controller.openPlayer(context: context, playlist: mediaItems, initialIndex: index),
          );
        },
      ),
    );
  }
}

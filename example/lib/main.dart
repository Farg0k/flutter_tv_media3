import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
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
      title: 'Media3 Preview Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const PreviewDemoScreen(),
    );
  }
}

class PreviewItem {
  final String id;
  final String title;
  final String url;
  final String? poster;
  final int? startTime;
  final int? endTime;
  final bool isError;
  final bool needsResolving;

  PreviewItem({
    required this.id,
    required this.title,
    required this.url,
    this.poster,
    this.startTime,
    this.endTime,
    this.isError = false,
    this.needsResolving = false,
  });

  PlaylistMediaItem toPlaylistMediaItem() {
    return PlaylistMediaItem(id: id, title: title, url: url, startPosition: startTime, placeholderImg: poster);
  }
}

class PreviewDemoScreen extends StatefulWidget {
  const PreviewDemoScreen({super.key});

  @override
  State<PreviewDemoScreen> createState() => _PreviewDemoScreenState();
}

class _PreviewDemoScreenState extends State<PreviewDemoScreen> {
  final playerController = FtvMedia3PlayerController();

  final List<PreviewItem> items = [
    PreviewItem(
      id: '1',
      title: 'Big Buck Bunny (Full)',
      url: 'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
      poster: 'https://habrastorage.org/getpro/habr/olpictures/d27/d54/495/d27d54495a66c5047fa9929b937fc786.jpg',
    ),
    PreviewItem(
      id: '2',
      title: 'Clipped Segment (10s - 20s)',
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      poster: 'https://i.ytimg.com/vi/kPdv44HtEoA/maxresdefault.jpg',
      startTime: 10,
      endTime: 20,
    ),
    PreviewItem(
      id: '3',
      title: 'Dynamic Link (Simulated API)',
      url: 'myapp://resolve/video',
      poster: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSUHw5p78QkZu3_Is0vYxxJlRk0A_FwQMtmGA&s',
      needsResolving: true,
    ),
    PreviewItem(
      id: '4',
      title: 'Broken Link (Error Test)',
      url: 'https://invalid-url.com/video.mp4',
      poster: 'https://www.elegantthemes.com/blog/wp-content/uploads/2021/11/broken-links-featured.png',
      isError: true,
    ),
    PreviewItem(
      id: '5',
      title: 'Tears of Steel (Muted Loop)',
      url: 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      poster: 'https://media.themoviedb.org/t/p/w1066_and_h600_bestv2/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg',
    ),
    PreviewItem(
      id: '6',
      title: 'vp9',
      url: 'https://test-videos.co.uk/vids/bigbuckbunny/webm/vp9/1080/Big_Buck_Bunny_1080_10s_1MB.webm',
      poster: 'https://habrastorage.org/getpro/habr/olpictures/d27/d54/495/d27d54495a66c5047fa9929b937fc786.jpg',
    ),
  ];
  /*  final List<PlaylistMediaItem> mediaItems = [
    PlaylistMediaItem(
      id: 'bbb_hls_res',
      label: 'Sintel HLS (Sintel with Subtitles)',
      title: 'Sintel',
      subTitle: 'Sintel with Subtitles',
      description: 'The film follows a girl named Sintel who is searching for a baby dragon she calls Scales.',
      url: 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      startPosition: 60,
      duration: 888,
      headers: {'Referer': 'https://example.com/player'},
      placeholderImg: 'https://media.themoviedb.org/t/p/w1066_and_h600_bestv2/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg',
      coverImg: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/636px-Sintel_poster.jpg',
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint('SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex');
      },
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
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint('SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex');
      },
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
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint('SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex');
      },
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
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint('SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex');
      },
      resolutions: {
        '1080p': 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        '720p': 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        '360p':
        'https://avtshare01.rz.tu-ilmenau.de/avt-vqdb-uhd-1/test_1/segments/bigbuck_bunny_8bit_200kbps_360p_60.0fps_h264.mp4',
      },
      headers: {'User-Agent': 'MyApp/1.0'},
    ),
  ];*/
  int _selectedIndex = 0;
  double _volume = 0.0;
  bool _isRepeat = true;

  Future<String?> _resolveLink() async {
    await Future.delayed(const Duration(seconds: 2));
    return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
  }

  @override
  void initState() {
    super.initState();
    // Initialize controller with some default settings
    playerController.setConfig(
      playerSettings: PlayerSettings(videoQuality: VideoQuality.high, isAfrEnabled: true),
      // Trigger pagination when 2 items are left in the playlist
      paginationThreshold: 6,
      onLoadMore: () async {
        debugPrint('PAGINATION: Loading more items...');

        // Simulate network delay
        await Future.delayed(const Duration(seconds: 2));

        final nextId = items.length + 1;
        final newItems = [
          PreviewItem(
            id: '$nextId',
            title: 'Pagination Item $nextId',
            url: 'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
            poster: 'https://habrastorage.org/getpro/habr/olpictures/d27/d54/495/d27d54495a66c5047fa9929b937fc786.jpg',
          ),
          PreviewItem(
            id: '${nextId + 1}',
            title: 'Pagination Item ${nextId + 1}',
            url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
            poster: 'https://i.ytimg.com/vi/kPdv44HtEoA/maxresdefault.jpg',
          ),
        ];

        // Update local state and notify the player
        setState(() {
          items.addAll(newItems);
        });

        // Synchronize with the native player and overlay UI
        await playerController.addMediaItems(items: newItems.map((e) => e.toPlaylistMediaItem()).toList());

        debugPrint('PAGINATION: Added ${newItems.length} items.');
      },
    );

    // PAGINATION EXAMPLE:
    // This callback will be triggered when the user is close to the end of the playlist
  }

  void _removeItem(int index) async {
    if (items.length <= 1) return;

    setState(() {
      items.removeAt(index);
      if (_selectedIndex >= items.length) {
        _selectedIndex = items.length - 1;
      }
    });

    // Notify the player to adjust its state
    await playerController.removeMediaItem(index: index);
  }

  @override
  void dispose() {
    playerController.close();
    super.dispose();
  }

  void _openFullPlayer(int index) {
    playerController.openPlayer(
      context: context,
      playlist: items.map((e) => e.toPlaylistMediaItem()).toList(),
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = items[_selectedIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Background "Hero" Preview
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Media3PreviewPlayer(
                key: ValueKey('hero_${selectedItem.id}'),
                url: selectedItem.url,
                isActive: true,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                volume: _volume,
                fit: BoxFit.cover,
                isRepeat: _isRepeat,
                startTimeSeconds: selectedItem.startTime,
                endTimeSeconds: selectedItem.endTime,
                getDirectLink: selectedItem.needsResolving ? _resolveLink : null,
                placeholder: Image.network(
                  selectedItem.poster ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
                errorWidget: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load: ${selectedItem.title}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const Text('Check URL or network connection', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // UI Elements
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEDIA3 PREVIEW',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'NATIVE TEXTURE RENDERING',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 10), // Replaced Spacer with fixed gap
                    // Item Title and Description
                    Text(selectedItem.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 600,
                      child: Text(
                        'This preview is rendered directly onto a Flutter Texture using native Media3 ExoPlayer. '
                        'It supports clipping, volume control, and background loading without blocking the UI thread.',
                        style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Controls section
                    Row(
                      children: [
                        _ControlButton(
                          icon: _volume > 0 ? Icons.volume_up : Icons.volume_off,
                          label: 'VOLUME: ${(_volume * 100).toInt()}%',
                          onPressed: () {
                            setState(() {
                              _volume = _volume == 0 ? 1.0 : 0.0;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: _isRepeat ? Icons.repeat : Icons.repeat_one,
                          label: _isRepeat ? 'LOOP: ON' : 'LOOP: OFF',
                          onPressed: () {
                            setState(() {
                              _isRepeat = !_isRepeat;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.play_arrow,
                          label: 'WATCH FULL',
                          isPrimary: true,
                          onPressed: () => _openFullPlayer(_selectedIndex),
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.delete_outline,
                          label: 'REMOVE',
                          onPressed: () => _removeItem(_selectedIndex),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Horizontal List of items
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _PreviewCard(
                            item: items[index],
                            isSelected: _selectedIndex == index,
                            onFocus: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            onTap: () => _openFullPlayer(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final PreviewItem item;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const _PreviewCard({required this.item, required this.isSelected, required this.onFocus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) onFocus();
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isEnter =
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA;
            if (isEnter) {
              onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: hasFocus ? 280 : 240,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hasFocus ? Colors.white : Colors.white24, width: hasFocus ? 4 : 1),
                  boxShadow:
                      hasFocus
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)]
                          : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Mini Preview inside the card
                      Media3PreviewPlayer(
                        url: item.url,
                        isActive: hasFocus, // Only plays if focused
                        width: 280,
                        height: 180,
                        volume: 0,
                        fit: BoxFit.cover,
                        initDelay: const Duration(milliseconds: 400),
                        startTimeSeconds: item.startTime,
                        endTimeSeconds: item.endTime,
                        getDirectLink:
                            item.needsResolving
                                ? () async {
                                  await Future.delayed(const Duration(seconds: 1));
                                  return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
                                }
                                : null,
                        placeholder: Image.network(
                          item.poster ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                        ),
                        //borderRadius: BorderRadius.circular(16),
                      ),
                      // Focus highlight overlay
                      if (!hasFocus) Positioned.fill(child: Container(color: Colors.black26)),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                            ),
                          ),
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                              fontSize: hasFocus ? 16 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ControlButton({required this.icon, required this.label, required this.onPressed, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Colors.blue : Colors.white.withValues(alpha: 0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

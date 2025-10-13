import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import '../../../flutter_tv_media3.dart';
import '../../app_theme/app_theme.dart';

/// A screen widget launched from the main application to display the loading
/// process of the native player.
///
/// This screen acts as a temporary container or placeholder. Its primary role
/// is to show the user a loading indicator while the native player (running in
/// its own Android Activity) initializes in the background.
///
/// Once the native player is ready (signaled by `activityReady` in the
/// [PlayerState] stream), this screen automatically closes, and the user
/// sees the full player interface.
class Media3PlayerScreen extends StatefulWidget {
  const Media3PlayerScreen({
    super.key,
    this.playerLabel,
    required this.playlist,
    this.initialIndex = 0,
  });
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final Widget? playerLabel;
  @override
  State<Media3PlayerScreen> createState() => _Media3PlayerScreenState();
}

class _Media3PlayerScreenState extends State<Media3PlayerScreen> {
  late final FtvMedia3PlayerController _controller;
  bool isClose = false;

  @override
  void initState() {
    super.initState();
    _controller = FtvMedia3PlayerController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _controller.playerStateStream.listen((e) async {
      if (e.activityReady == true && mounted == true && isClose == false) {
        isClose = true;
        Navigator.of(context).maybePop();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));
      try {
        await _controller.openNativePlayer(
          playlist: widget.playlist,
          initialIndex: widget.initialIndex,
        );
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(context, e.toString());
        }
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: 12,
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppTheme.errColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<PlayerState>(
        stream: _controller.playerStateStream,
        builder: (context, snapshot) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child:
                    widget.playerLabel ??
                    Text(
                      'FTVMedia3',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.merge(AppTheme.boldTextStyle),
                    ),
              ),
              Positioned(
                bottom: 50,
                left: 200,
                right: 200,
                child: Column(
                  children: [
                    Text(
                      OverlayLocalizations.get('loading'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.merge(
                        AppTheme.extraLightTextStyle,
                      ),
                    ),
                    LinearProgressIndicator(color: AppTheme.fullFocusColor),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../flutter_tv_media3.dart';
import '../../../app_theme/app_theme.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'widgets/player_error_widget.dart';

class PlaceholderWidget extends StatelessWidget {
  const PlaceholderWidget({super.key, required this.controller});
  final Media3UiController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: StreamBuilder<PlayerState>(
        initialData: controller.playerState,
        stream: controller.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;

          if (playerState == null || playerState.activityReady == false) {
            return const _Content(item: null);
          }
          final PlaylistMediaItem? item =
              playerState.playIndex != -1 && playerState.playlist.isNotEmpty
                  ? playerState.playlist[playerState.playIndex]
                  : null;
          if (item == null) {
            return PlayerErrorWidget(
              lastError: OverlayLocalizations.get('playbackError'),
              errorCode: OverlayLocalizations.get('playlistIndexError'),
              onExit: controller.stop,
            );
          }
          if (item.coverImg != null) {
            precacheImage(NetworkImage(item.coverImg!), context, onError: (exception, stackTrace) {});
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              if (item.placeholderImg != null) _BackgroundImage(imageUrl: item.placeholderImg!),
              Container(color: AppTheme.backgroundColor),
              if (playerState.lastError != null)
                PlayerErrorWidget(
                  lastError: playerState.lastError!,
                  errorCode: playerState.errorCode,
                  onExit: () => controller.stop(),
                  onNext: () => controller.playNext(),
                )
              else
                _Content(item: item),
              if (playerState.lastError == null)
                Positioned(
                  bottom: 50,
                  left: 200,
                  right: 200,
                  child: Focus(
                    autofocus: true,
                    child: Column(
                      children: [
                        Text(
                          OverlayLocalizations.get('loading'),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w300),
                        ),
                        LinearProgressIndicator(value: playerState.loadingProgress),
                      ],
                    ),
                  ),
                ),
              if (snapshot.data?.loadingStatus != null && playerState.lastError == null)
                Positioned(
                  bottom: 25,
                  left: 10,
                  right: 10,
                  child: Text(
                    snapshot.data!.loadingStatus!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final PlaylistMediaItem? item;

  const _Content({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: item != null ? 1.0 : 0.0,
            child: Column(
              children: [
                if (item?.title != null)
                  Text(
                    item!.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w200),
                  ),
                const SizedBox(height: 8),
                if (item?.subTitle != null)
                  Text(
                    item!.subTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                if (item?.label != null)
                  Text(
                    item!.label!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final String imageUrl;

  const _BackgroundImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64));
      },
    );
  }
}

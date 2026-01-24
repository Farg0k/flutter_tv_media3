import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/overlay/bloc/overlay_ui_bloc.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import 'package:flutter_tv_media3/src/utils/string_utils.dart';
import 'package:sprintf/sprintf.dart';
import '../../../localization/overlay_localizations.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/widgets/marquee_title_widget.dart';

class HorizontalPlaylistPanel extends StatefulWidget {
  final Media3UiController controller;
  final Map<ShortcutActivator, VoidCallback> generalBindings;

  const HorizontalPlaylistPanel({super.key, required this.controller, required this.generalBindings});

  @override
  State<HorizontalPlaylistPanel> createState() => _HorizontalPlaylistPanelState();
}

class _HorizontalPlaylistPanelState extends State<HorizontalPlaylistPanel> {
  late ScrollController _scrollController;
  late int _selectedIndex;
  final FocusNode _focusNode = FocusNode();
  static const double _itemWidth = 240.0;
  static const double _itemHeight = 160.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedIndex = context.read<OverlayUiBloc>().state.playIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  @override
  void didUpdateWidget(HorizontalPlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPlayIndex = widget.controller.playerState.playIndex;
    if (newPlayIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newPlayIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToIndex(_selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        widget.controller.playerState.playlist.isEmpty ||
        index < 0 ||
        index >= widget.controller.playerState.playlist.length) {
      return;
    }

    final viewportWidth = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    double targetOffset = (index * (_itemWidth + 16)) - (viewportWidth / 2) + (_itemWidth / 2);
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  void _handleKeyEvent(Function action) {
    setState(() {
      action();
    });
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts(List<PlaylistMediaItem> playlist) {
    final bindings = Map<ShortcutActivator, VoidCallback>.from(widget.generalBindings);

    bindings.addAll({
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          () => _handleKeyEvent(() {
            if (playlist.isNotEmpty) {
              _selectedIndex = (_selectedIndex - 1 + playlist.length) % playlist.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          () => _handleKeyEvent(() {
            if (playlist.isNotEmpty) {
              _selectedIndex = (_selectedIndex + 1) % playlist.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder));
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder));
            }
          }),
      const SingleActivator(LogicalKeyboardKey.space):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder));
            }
          }),
      // Pressing down again should close and play previous as requested
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        final bloc = context.read<OverlayUiBloc>();
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        widget.controller.playPrevious();
      },
      // Arrow up closes the panel
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.none));
      },
    });
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: _itemHeight + 80,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadius,
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Material(
          color: AppTheme.backgroundColor,
          child: StreamBuilder<PlayerState>(
            stream: widget.controller.playerStateStream,
            initialData: widget.controller.playerState,
            builder: (context, snapshot) {
              final playerState = snapshot.data ?? widget.controller.playerState;
              final playlist = playerState.playlist;

              return CallbackShortcuts(
                bindings: _getShortcuts(playlist),
                child: Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Builder(
                          builder: (context) {
                            final currentPlayIndex = playerState.playIndex;
                            final playItem =
                                currentPlayIndex >= 0 && currentPlayIndex < playlist.length
                                    ? playlist[currentPlayIndex]
                                    : null;

                            if (playItem == null) {
                              return Text(
                                OverlayLocalizations.get('playlist'),
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            }

                            return Text(
                              playItem.title ?? playItem.label!,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: playlist.length,
                          itemBuilder: (context, index) {
                            final item = playlist[index];
                            final isSelected = index == _selectedIndex;
                            final isActive = index == playerState.playIndex;

                            return HorizontalPlaylistItem(
                              item: item,
                              index: index,
                              isSelected: isSelected,
                              isActive: isActive,
                              onTap: () {
                                widget.controller.playSelectedIndex(index: index);
                                context.read<OverlayUiBloc>().add(
                                  const SetActivePanel(playerPanel: PlayerPanel.placeholder),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HorizontalPlaylistItem extends StatelessWidget {
  final PlaylistMediaItem item;
  final int index;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const HorizontalPlaylistItem({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: _buildDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    children: [
                      _PlaylistItemThumbnail(item: item, isActive: isActive),
                      if (isActive) const _PlaylistItemActiveIndicator(),
                      Positioned(bottom: 0, left: 0, right: 0, child: _ProgressBar(item: item)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PlaylistItemTitle(item: item, index: index, isSelected: isSelected),
        ],
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isSelected ? AppTheme.fullFocusColor : Colors.white24, width: isSelected ? 3 : 1),
      boxShadow:
          isSelected
              ? [BoxShadow(color: AppTheme.fullFocusColor.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)]
              : null,
    );
  }
}

class _PlaylistItemThumbnail extends StatelessWidget {
  final PlaylistMediaItem item;

  final bool isActive;

  const _PlaylistItemThumbnail({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.white10,

      child: Center(
        child: Icon(_getIconForMediaType(), size: 48, color: isActive ? AppTheme.fullFocusColor : Colors.white38),
      ),
    );

    if (item.placeholderImg == null) return placeholder;

    return Image.network(
      item.placeholderImg!,
      fit: BoxFit.cover,
      width: 240,
      height: 160,

      loadingBuilder:
          (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),

      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  IconData _getIconForMediaType() {
    return switch (item.mediaItemType) {
      MediaItemType.tvStream => Icons.tv,

      MediaItemType.audio => Icons.audiotrack,

      MediaItemType.video => Icons.movie,
    };
  }
}

class _PlaylistItemActiveIndicator extends StatelessWidget {
  const _PlaylistItemActiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppTheme.fullFocusColor, shape: BoxShape.circle),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
      ),
    );
  }
}

class _PlaylistItemTitle extends StatelessWidget {
  final PlaylistMediaItem item;

  final int index;

  final bool isSelected;

  const _PlaylistItemTitle({required this.item, required this.index, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return MarqueeWidget(
      text: item.label ?? item.title ?? sprintf(OverlayLocalizations.get('itemNumber'), [index]),
      focus: isSelected,
      style: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlaylistMediaItem item;

  const _ProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final duration = item.duration;
    final position = item.startPosition;

    if (position == null && duration == null) {
      return const SizedBox.shrink();
    }

    final percent =
        (duration != null && duration > 0 && position != null) ? (position / duration).clamp(0.0, 1.0) : 0.0;

    final isWatched = (duration != null && duration > 0 && position == duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: (duration == 0 && position == 0) || isWatched ? 1 : percent,
          minHeight: 4,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fullFocusColor),
        ),
        if (!isWatched)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${(percent * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                if (duration != 0 || position != 0)
                  Text(
                    '${StringUtils.formatDuration(seconds: position ?? 0)} / ${duration == null ? '--:--:--' : StringUtils.formatDuration(seconds: duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

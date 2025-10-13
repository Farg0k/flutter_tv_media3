import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../../../../app_theme/app_theme.dart';
import 'playlist_item_widget.dart';

class PlaylistWidget extends StatefulWidget {
  final Media3UiController controller;

  const PlaylistWidget({super.key, required this.controller});

  @override
  State<PlaylistWidget> createState() => _PlaylistWidgetState();
}

class _PlaylistWidgetState extends State<PlaylistWidget> {
  late ScrollController _scrollController;
  late int _selectedIndex;
  final FocusNode _focusNode = FocusNode();
  static const double _itemExtent = AppTheme.customListItemExtent;

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
  void didUpdateWidget(PlaylistWidget oldWidget) {
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

    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    double targetOffset =
        (index * _itemExtent) - (viewportHeight / 2) + (_itemExtent / 2);
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _handleKeyEvent(Function action) {
    setState(() {
      action();
    });
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts() {
    final playlist = widget.controller.playerState.playlist;
    return {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _handleKeyEvent(() {
            if (playlist.isNotEmpty) {
              _selectedIndex =
                  (_selectedIndex - 1 + playlist.length) % playlist.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
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
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
        buildWhen:
            (oldState, newState) => oldState.playIndex != newState.playIndex,
        builder: (context, state) {
          return CallbackShortcuts(
            bindings: _getShortcuts(),
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  radius: const Radius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: widget.controller.playerState.playlist.length,
                      itemExtent: _itemExtent,
                      itemBuilder: (BuildContext context, int index) {
                        final item =
                            widget.controller.playerState.playlist[index];
                        final playlistItemWidget = PlaylistItemWidget(
                          controller: widget.controller,
                          item: item,
                          index: index,
                          autofocus: index == _selectedIndex,
                          isActive: index == state.playIndex,
                        );
                        return playlistItemWidget;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

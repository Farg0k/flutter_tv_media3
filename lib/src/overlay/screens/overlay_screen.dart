import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import '../bloc/overlay_ui_bloc.dart';
import '../media_ui_service/media3_ui_controller.dart';
import 'components/audio_screen/audio_screen_widget.dart';
import 'components/clock_panel.dart';
import 'components/epg_screen/epg_screen.dart';
import 'components/horizontal_playlist_panel.dart';
import 'components/info_panel.dart';
import 'components/placeholder_widget.dart';
import 'components/setup_panel.dart';
import 'components/setup_panel/audio_widget/audio_widget.dart';
import 'components/setup_panel/playlist_widget/playlist_widget.dart';
import 'components/setup_panel/settings_screen/settings_screen.dart';
import 'components/setup_panel/settings_screen/sleep_timer_widget.dart';
import 'components/setup_panel/subtitle_widget/subtitle_widget.dart';
import 'components/setup_panel/video_widget/video_widget.dart';
import 'components/simple_panel.dart';
import 'components/touch_controls_overlay.dart';
import 'components/widgets/player_error_widget.dart';
import 'components/widgets/show_side_sheet.dart';
import 'components/widgets/titled_panel_scaffold.dart';
import 'overlay_actions.dart';
import 'overlay_shortcuts.dart';

/// The root widget for the player's UI overlay, running in a separate
/// Flutter Engine.
class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key, required this.controller});
  final Media3UiController controller;
  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  final debouncerThrottler = DebouncerThrottler();
  late final OverlayActionsContainer _actionHandler;

  @override
  void initState() {
    super.initState();
    _actionHandler = OverlayActionsContainer(
      controller: widget.controller,
      bloc: context.read<OverlayUiBloc>(),
      debouncerThrottler: debouncerThrottler,
    );

    widget.controller.onBackPressed = () {
      final bloc = context.read<OverlayUiBloc>();
      final panel = bloc.state.playerPanel;
      final isInitial =
          widget.controller.playerState.stateValue == StateValue.initial;

      if (bloc.state.sideSheetOpen == true) {
        Navigator.of(context).pop();
        return;
      }

      if (panel == PlayerPanel.placeholder || panel == PlayerPanel.none) {
        widget.controller.stop();
        return;
      }

      if (isInitial) {
        if (panel != PlayerPanel.placeholder) {
          bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder));
        } else {
          widget.controller.stop();
        }
        return;
      }
      bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      widget.controller.overlayEntryPointCalled();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();
    return Shortcuts(
      shortcuts: OverlayShortcuts.general,
      child: Actions(
        actions: _actionHandler.getActions(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: () {
              final currentPanel = bloc.state.playerPanel;
              bloc.add(
                SetActivePanel(
                  playerPanel:
                      currentPanel == PlayerPanel.none
                          ? PlayerPanel.touchOverlay
                          : PlayerPanel.none,
                ),
              );
            },
            onDoubleTap: _actionHandler.playPause,
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              if (!bloc.state.isScreenLocked) {
                _handleHorizontalDrag(details: details);
              }
            },
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: BlocConsumer<OverlayUiBloc, OverlayUiState>(
                listener: (BuildContext context, OverlayUiState state) {
                  if (state.playerPanel == PlayerPanel.sleep) {
                    _actionHandler.openPanel(PlayerPanel.none, context);
                    showSideSheet(
                      context: context,
                      bloc: bloc,
                      body: SleepTimerWidget(bloc: bloc, isAuto: true),
                    );
                  }
                  if (state.playerPanel == PlayerPanel.epg) {
                    _actionHandler.openPanel(PlayerPanel.none, context);
                    showSideSheet(
                      context: context,
                      bloc: bloc,
                      body: EpgScreen(
                        bloc: bloc,
                        controller: widget.controller,
                        initialChannelId: widget.controller.playItem.id,
                        onChannelLaunch: (EpgChannel value) {
                          bloc.add(
                            const SetActivePanel(playerPanel: PlayerPanel.none),
                          );
                          widget.controller.playSelectedIndex(
                            index: value.index,
                          );
                          Navigator.of(context).pop();
                        },
                        deviceLocale:
                            widget
                                .controller
                                .playerState
                                .playerSettings
                                .deviceLocale ??
                            const Locale('en', 'US'),
                      ),
                    );
                  }
                },
                buildWhen:
                    (oldState, newState) =>
                        oldState.playerPanel != newState.playerPanel,
                builder: (context, state) {
                  return _buildPanel(context, state);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, OverlayUiState state) {
    final bloc = context.read<OverlayUiBloc>();

    if (state.playerPanel == PlayerPanel.placeholder) {
      return Shortcuts(
        shortcuts: OverlayShortcuts.placeholder,
        child: PlaceholderWidget(controller: widget.controller),
      );
    }

    if (state.playerPanel == PlayerPanel.error &&
        widget.controller.playerState.lastError != null) {
      if (state.sideSheetOpen == true) Navigator.of(context).pop();
      return Shortcuts(
        shortcuts: OverlayShortcuts.placeholder,
        child: PlayerErrorWidget(
          lastError: widget.controller.playerState.lastError!,
          errorCode: widget.controller.playerState.errorCode,
          onOpen: widget.controller.resetError,
          onClose: () => _actionHandler.openPanel(PlayerPanel.none, context),
          onNext: () => widget.controller.playNext(),
          onExit: () => widget.controller.stop(),
        ),
      );
    }

    switch (state.playerPanel) {
      case PlayerPanel.setup:
        bloc.add(const SetTouchMode(isTouch: false));
        return SetupPanel(
          controller: widget.controller,
          selSettingsTab: state.tabIndex,
        );
      case PlayerPanel.touchOverlay:
        bloc.add(const SetTouchMode(isTouch: true));
        return TouchControlsOverlay(
          controller: widget.controller,
          takeScreenshot: () => _actionHandler.takeScreenshot(context),
        );
      case PlayerPanel.settings:
        return Container(
          color: AppTheme.backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SettingsScreen(controller: widget.controller),
          ),
        );
      case PlayerPanel.playlist:
        return TitledPanelScaffold(
          title: OverlayLocalizations.get('playlist'),
          icon: Icons.playlist_play,
          child: PlaylistWidget(controller: widget.controller),
        );
      case PlayerPanel.audio:
        return TitledPanelScaffold(
          title: OverlayLocalizations.get('audio'),
          icon: Icons.audiotrack,
          child: AudioWidget(controller: widget.controller),
        );
      case PlayerPanel.video:
        return TitledPanelScaffold(
          title: OverlayLocalizations.get('video'),
          icon: Icons.video_library,
          child: VideoWidget(controller: widget.controller),
        );
      case PlayerPanel.subtitle:
        return TitledPanelScaffold(
          title: OverlayLocalizations.get('subtitle'),
          icon: Icons.subtitles,
          child: SubtitleWidget(controller: widget.controller),
        );
      case PlayerPanel.horizontalPlaylist:
        return HorizontalPlaylistPanel(controller: widget.controller);
      case PlayerPanel.simple:
        return Shortcuts(
          shortcuts: OverlayShortcuts.simple,
          child: SimplePanel(controller: widget.controller),
        );
      case PlayerPanel.info:
        return InfoPanel(controller: widget.controller);
      default:
        if (_shouldShowAudioUI()) {
          return Focus(
            autofocus: true,
            child: Stack(
              children: [
                AudioPlayerTVScreen(controller: widget.controller),
                ClockPanel(controller: widget.controller),
              ],
            ),
          );
        }
        return _buildDefaultOverlay();
    }
  }

  Widget _buildDefaultOverlay() {
    return Focus(
      autofocus: true,
      child: StreamBuilder<PlayerState>(
        stream: widget.controller.playerStateStream,
        initialData: widget.controller.playerState,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          if (playerState == null) return const SizedBox.shrink();
          return Stack(
            children: [
              ClockPanel(controller: widget.controller),
              _buildMuteIcon(playerState),
              _buildPauseIcon(playerState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMuteIcon(PlayerState playerState) {
    return Visibility(
      visible: playerState.volumeState.isMute == true,
      child: const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: Icon(
            Icons.volume_off,
            color: Colors.white,
            size: 48,
            shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseIcon(PlayerState playerState) {
    return Visibility(
      visible:
          playerState.stateValue == StateValue.paused &&
          playerState.videoTracks.isNotEmpty,
      child: const Center(
        child: Icon(
          Icons.pause,
          color: Colors.white,
          size: 140,
          shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
        ),
      ),
    );
  }

  bool _shouldShowAudioUI() {
    final playerState = widget.controller.playerState;
    final playIndex = playerState.playIndex;
    final playlist = playerState.playlist;

    if (playIndex < 0 || playIndex >= playlist.length) return false;

    final currentItem = playlist[playIndex];
    final mimeType = currentItem.mediaItemType.name.toLowerCase();
    if (mimeType.startsWith('audio') == true) return true;

    final isPlayerStable =
        playerState.stateValue != StateValue.buffering &&
        playerState.stateValue != StateValue.initial &&
        playerState.loadingStatus == null &&
        playerState.lastError == null;

    return playerState.videoTracks.isEmpty && isPlayerStable;
  }

  Future<void> _handleHorizontalDrag({
    required DragUpdateDetails details,
  }) async {
    if (widget.controller.playerState.isLive == true) return;
    final seekOffset = details.delta.dx.round();
    await _actionHandler.arrowRewind(seekOffset);
  }
}

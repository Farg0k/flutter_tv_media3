import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';

class TouchControlsOverlay extends StatefulWidget {
  const TouchControlsOverlay({super.key, required this.controller});

  final Media3UiController controller;

  @override
  State<TouchControlsOverlay> createState() => _TouchControlsOverlayState();
}

class _TouchControlsOverlayState extends State<TouchControlsOverlay> {
  Timer? _hideTimer;
  double _opacity = 0;
  @override
  void initState() {
    super.initState();
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _opacity = 1;
      });
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && context.read<OverlayUiBloc>().state.playerPanel == PlayerPanel.touchOverlay) {
        setState(() {
          _opacity = 0;
        });
        ;
      }
    });
  }

  Future<void> _seek(int seconds) async {
    final newPosition = widget.controller.playbackState.position + seconds;
    final duration = widget.controller.playbackState.duration;
    if (newPosition >= 0 && newPosition <= duration) {
      await widget.controller.seekTo(positionSeconds: newPosition);
    }
    _startHideTimer();
  }

  void _goToVideoPercentage(double percentage) {
    if (widget.controller.playerState.isLive == true) return;
    final duration = widget.controller.playbackState.duration;
    final newPosition = (duration * percentage).toInt();
    widget.controller.seekTo(positionSeconds: newPosition);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();

    return AnimatedOpacity(
      duration: Duration(milliseconds: 400),
      onEnd: _closePanel,
      opacity: _opacity,
      child: GestureDetector(
        onTap: _startHideTimer,
        onPanDown: (_) => _startHideTimer(),
        child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
          buildWhen: (previous, current) => previous.isScreenLocked != current.isScreenLocked,
          builder: (context, state) {
            final isLocked = state.isScreenLocked;
            if (isLocked) {
              _hideTimer?.cancel();
            } else {
              _startHideTimer();
            }

            return Material(
              type: MaterialType.transparency,
              child: StreamBuilder<PlayerState>(
                stream: widget.controller.playerStateStream,
                builder: (context, playerStateSnapshot) {
                  final playerState = playerStateSnapshot.data ?? widget.controller.playerState;
                  final isPlaying = playerState.stateValue == StateValue.playing;
                  final hasMultipleItems = playerState.playlist.length > 1;

                  return Stack(
                    children: [
                      Visibility(
                        visible: !isLocked,
                        child: Positioned.fill(
                          child: GestureDetector(
                            onTap:
                                () => setState(() {
                                  _opacity = 0;
                                }),
                            child: Container(color: Colors.black.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Visibility(
                              visible: !isLocked,
                              child: IconButton(
                                icon: const Icon(Icons.settings, color: Colors.white, size: 32),
                                onPressed: () {
                                  _startHideTimer();
                                  bloc.add(const SetActivePanel(playerPanel: PlayerPanel.setup));
                                },
                              ),
                            ),
                            Visibility(
                              visible: !isLocked,
                              child: IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.white, size: 32),
                                onPressed: () {
                                  _startHideTimer();
                                  bloc.add(const SetActivePanel(playerPanel: PlayerPanel.info));
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(isLocked ? Icons.lock : Icons.lock_open, color: Colors.white, size: 32),
                              onPressed: () => bloc.add(const ToggleScreenLock()),
                            ),
                          ],
                        ),
                      ),
                      Visibility(
                        visible: !isLocked,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasMultipleItems)
                                      IconButton(
                                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 48),
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.playPrevious();
                                        },
                                      ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      icon: const Icon(Icons.replay_10, color: Colors.white, size: 48),
                                      onPressed: () => _seek(-10),
                                    ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                        color: Colors.white,
                                        size: 80,
                                      ),
                                      onPressed: () {
                                        _startHideTimer();
                                        widget.controller.playPause();
                                      },
                                    ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      icon: const Icon(Icons.forward_10, color: Colors.white, size: 48),
                                      onPressed: () => _seek(10),
                                    ),
                                    const SizedBox(width: 24),
                                    if (hasMultipleItems)
                                      IconButton(
                                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 48),
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.playNext();
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                // New row with percentage seek buttons
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(10, (index) {
                                      final percentage = index / 10.0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: OutlinedButton(
                                          onPressed: () => _goToVideoPercentage(percentage),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white30,
                                            side: const BorderSide(color: Colors.white30, width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          child: Text(
                                            '${index * 10}%',
                                            style: const TextStyle(color: Colors.white30, fontSize: 16),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: TimeLinePanel(controller: widget.controller),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _closePanel() =>
      _opacity == 0 ? context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.none)) : null;
}

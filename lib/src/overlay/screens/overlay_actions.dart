import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app_theme/app_theme.dart';
import '../../entity/clock_settings.dart';
import '../bloc/overlay_ui_bloc.dart';
import '../../utils/debouncer_throttler.dart';
import '../../localization/overlay_localizations.dart';
import '../media_ui_service/media3_ui_controller.dart';
import 'components/screenshot_frame.dart';
import 'overlay_intents.dart';

class OverlayActionsContainer {
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  final DebouncerThrottler debouncerThrottler;
  DateTime? _lastInfoPressTime;

  OverlayActionsContainer({
    required this.controller,
    required this.bloc,
    required this.debouncerThrottler,
  });

  Map<Type, Action<Intent>> getActions(BuildContext context) {
    return {
      PlayPauseIntent: CallbackAction<PlayPauseIntent>(onInvoke: (_) => playPause()),
      StopIntent: CallbackAction<StopIntent>(onInvoke: (_) => controller.stop()),
      PlayNextIntent: CallbackAction<PlayNextIntent>(onInvoke: (_) => controller.playNext()),
      HandleArrowDownIntent: CallbackAction<HandleArrowDownIntent>(onInvoke: (_) => handleArrowDown()),
      ClockRandomIntent: CallbackAction<ClockRandomIntent>(onInvoke: (_) => clockRandom()),
      HandleInfoIntent: CallbackAction<HandleInfoIntent>(onInvoke: (_) => handleInfoPress(context)),
      SeekIntent: CallbackAction<SeekIntent>(onInvoke: (intent) => arrowRewind(intent.seconds)),
      SeekToPercentageIntent: CallbackAction<SeekToPercentageIntent>(onInvoke: (intent) => goToVideoPercentage(intent.percentage)),
      TogglePanelIntent: CallbackAction<TogglePanelIntent>(onInvoke: (intent) => openPanel(intent.panel, context)),
    };
  }

  Future<void> playPause() async {
    await controller.playPause();
    bloc.add(const SetActivePanel(playerPanel: PlayerPanel.info, debounce: true));
  }

  void openPanel(PlayerPanel playerPanel, BuildContext context) {
    if (bloc.state.sideSheetOpen == true) {
      Navigator.of(context).pop();
    }
    bloc.add(
      SetActivePanel(
        playerPanel: bloc.state.playerPanel == playerPanel ? PlayerPanel.none : playerPanel,
      ),
    );
  }

  void handleArrowDown() {
    if (bloc.state.playerPanel == PlayerPanel.horizontalPlaylist) {
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
      controller.playPrevious();
    } else {
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.horizontalPlaylist));
    }
  }

  Future<void> arrowRewind(int action) async {
    if (controller.playItem.programs != null) {
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.epg));
    }
    if (controller.playerState.isLive == true) return;

    await debouncerThrottler.throttle(const Duration(milliseconds: 200), () async {
      await _seekTo(action);
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true));
    });
  }

  Future<void> _seekTo(int action) async {
    final position = controller.playbackState.position;
    final duration = controller.playbackState.duration;
    final seconds = position + action < 0
        ? 0
        : position + action > duration
            ? duration - 5
            : position + action;
    await controller.seekTo(positionSeconds: seconds);
  }

  void goToVideoPercentage(double percentage) {
    if (controller.playerState.isLive == true) return;
    final positionSeconds = controller.playbackState.duration * percentage;
    controller.seekTo(positionSeconds: positionSeconds.toInt());
    bloc.add(const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true));
  }

  void clockRandom() {
    if (bloc.state.clockSettings.clockPosition == ClockPosition.random) {
      final clockPosition = ClockPosition.getRandomPosition();
      bloc.add(SetClockPosition(clockPosition: clockPosition));
    }
  }

  Future<void> handleInfoPress(BuildContext context) async {
    final now = DateTime.now();
    final screenshotsEnable = controller.playerState.playerSettings.screenshotsEnable;

    if (_lastInfoPressTime == null ||
        now.difference(_lastInfoPressTime!) > const Duration(milliseconds: 800) ||
        !screenshotsEnable) {
      _lastInfoPressTime = now;
      openPanel(PlayerPanel.info, context);
    } else {
      _lastInfoPressTime = null;
      await takeScreenshot(context);
    }
  }

  Future<void> takeScreenshot(BuildContext context) async {
    final overlay = Overlay.of(context);
    final playerState = controller.playerState;
    final playIndex = playerState.playIndex;
    final playlist = playerState.playlist;
    final playItem = playlist[playIndex];

    bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
    final int positionMs = controller.playbackState.position;
    final Uint8List? thumbnail = await controller.getVideoThumbnail(
      controller.playItem.url,
      timeInSeconds: positionMs.toDouble(),
    );

    if (thumbnail == null) {
      if (context.mounted) {
        _showSnack(context, OverlayLocalizations.get('screenshotFailed'), isError: true);
      }
      return;
    }

    final overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 100),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) => Container(
              color: Colors.white.withValues(alpha: 0.3 * (1.0 - value)),
            ),
          ),
          IgnorePointer(
            child: ScreenshotFrame(bytes: thumbnail, title: playItem.title),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 2000));
    overlayEntry.remove();
    if(context.mounted) {
      _showSnack(context, OverlayLocalizations.get('screenshotSuccess'));
    }
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppTheme.errColor : AppTheme.focusColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

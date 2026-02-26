import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'overlay_intents.dart';
import '../bloc/overlay_ui_bloc.dart';

class OverlayShortcuts {
  static Map<ShortcutActivator, Intent> get general => {
    const SingleActivator(LogicalKeyboardKey.mediaStop): const StopIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE): const StopIntent(),
    const SingleActivator(LogicalKeyboardKey.contextMenu): const TogglePanelIntent(PlayerPanel.setup),
    const SingleActivator(LogicalKeyboardKey.keyQ): const TogglePanelIntent(PlayerPanel.setup),
    const SingleActivator(LogicalKeyboardKey.info): const HandleInfoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyW): const HandleInfoIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): const PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.select): const PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPlayPause): const PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.digit0): const SeekToPercentageIntent(0.0),
    const SingleActivator(LogicalKeyboardKey.digit1): const SeekToPercentageIntent(0.1),
    const SingleActivator(LogicalKeyboardKey.digit2): const SeekToPercentageIntent(0.2),
    const SingleActivator(LogicalKeyboardKey.digit3): const SeekToPercentageIntent(0.3),
    const SingleActivator(LogicalKeyboardKey.digit4): const SeekToPercentageIntent(0.4),
    const SingleActivator(LogicalKeyboardKey.digit5): const SeekToPercentageIntent(0.5),
    const SingleActivator(LogicalKeyboardKey.digit6): const SeekToPercentageIntent(0.6),
    const SingleActivator(LogicalKeyboardKey.digit7): const SeekToPercentageIntent(0.7),
    const SingleActivator(LogicalKeyboardKey.digit8): const SeekToPercentageIntent(0.8),
    const SingleActivator(LogicalKeyboardKey.digit9): const SeekToPercentageIntent(0.9),
    const SingleActivator(LogicalKeyboardKey.arrowUp): const PlayNextIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const HandleArrowDownIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const SeekIntent(-10),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const SeekIntent(10),
    const SingleActivator(LogicalKeyboardKey.pageUp): const SeekIntent(600),
    const SingleActivator(LogicalKeyboardKey.pageDown): const SeekIntent(-600),
    const SingleActivator(LogicalKeyboardKey.backspace): const ClockRandomIntent(),
  };

  static Map<ShortcutActivator, Intent> get placeholder => {
    const SingleActivator(LogicalKeyboardKey.mediaStop): const StopIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE): const StopIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp): const PlayNextIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const HandleArrowDownIntent(),
  };

  static Map<ShortcutActivator, Intent> get simple {
    final map = Map<ShortcutActivator, Intent>.from(general);
    map[const SingleActivator(LogicalKeyboardKey.arrowUp)] = const SeekIntent(60);
    map[const SingleActivator(LogicalKeyboardKey.arrowDown)] = const SeekIntent(-60);
    return map;
  }
}

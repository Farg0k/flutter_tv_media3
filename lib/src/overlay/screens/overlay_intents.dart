import 'package:flutter/widgets.dart';
import '../bloc/overlay_ui_bloc.dart';

class PlayPauseIntent extends Intent { const PlayPauseIntent(); }
class StopIntent extends Intent { const StopIntent(); }
class PlayNextIntent extends Intent { const PlayNextIntent(); }
class HandleArrowDownIntent extends Intent { const HandleArrowDownIntent(); }
class ClockRandomIntent extends Intent { const ClockRandomIntent(); }
class HandleInfoIntent extends Intent { const HandleInfoIntent(); }

class SeekIntent extends Intent {
  final int seconds;
  const SeekIntent(this.seconds);
}

class SeekToPercentageIntent extends Intent {
  final double percentage;
  const SeekToPercentageIntent(this.percentage);
}

class TogglePanelIntent extends Intent {
  final PlayerPanel panel;
  const TogglePanelIntent(this.panel);
}

class PlaylistMoveIntent extends Intent {
  final int direction;
  const PlaylistMoveIntent(this.direction);
}

class PlaylistSelectIntent extends Intent {
  const PlaylistSelectIntent();
}

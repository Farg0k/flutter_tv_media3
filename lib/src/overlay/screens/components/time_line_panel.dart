import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';

import 'widgets/clock_widget.dart';
import '../../../entity/playback_state.dart';
import '../../../entity/player_state.dart';
import '../../../utils/string_utils.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'widgets/custom_info_text_widget.dart';

class TimeLinePanel extends StatefulWidget {
  final Media3UiController controller;
  const TimeLinePanel({super.key, required this.controller});

  @override
  State<TimeLinePanel> createState() => _TimeLinePanelState();
}

class _TimeLinePanelState extends State<TimeLinePanel> {
  double? _sliderPositionOnDrag;

  final style = const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18);

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.controller.playerState.isLive;

    return Material(
      color: Colors.transparent,
      child: Row(
        spacing: 8,
        children: [
          StreamBuilder<PlayerState>(
            stream: widget.controller.playerStateStream,
            initialData: widget.controller.playerState,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              if (playerState == null) return const SizedBox(width: 40);

              return playerState.stateValue == StateValue.paused
                  ? const Icon(Icons.pause, color: Colors.white, size: 40)
                  : const Icon(Icons.play_arrow, color: Colors.white, size: 40);
            },
          ),
          StreamBuilder<PlaybackState>(
            stream: widget.controller.playbackStateStream,
            initialData: widget.controller.playbackState,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.duration <= 0) {
                return const Expanded(child: SizedBox.shrink());
              }

              final positionPercentage = StringUtils.getPercentage(duration: data.duration, position: data.position);
              final bufferedPercentage = StringUtils.getPercentage(
                duration: data.duration,
                position: data.bufferedPosition,
              );

              final timeLeft = StringUtils.getTimeLeft(position: data.position, duration: data.duration);
              final currentPosition = StringUtils.formatDuration(seconds: data.position);
              final totalDuration = StringUtils.formatDuration(seconds: data.duration);

              return Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            isLive
                                ? const SizedBox.shrink()
                                : Text('${((_sliderPositionOnDrag ?? positionPercentage) * 100).round()}%', style: style),
                            const CustomInfoTextWidget(),
                            const ClockWidget(),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 10.0,
                            thumbShape: const CustomThumbShape(
                              thumbRadius: 8.0,
                              borderWidth: 3.0,
                              cornerRadius: 4.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                            trackShape: const RectangularSliderTrackShape(),
                          ),
                          child: Slider(
                            value: _sliderPositionOnDrag ?? positionPercentage,
                            secondaryTrackValue: bufferedPercentage,
                            min: 0.0,
                            max: 1.0,

                            activeColor: AppTheme.fullFocusColor,
                            secondaryActiveColor: AppTheme.colorMuted,
                            inactiveColor: AppTheme.colorPrimary,
                            thumbColor: AppTheme.fullFocusColor,

                            onChangeEnd: (newValue) {
                              final newPosition = data.duration * newValue;
                              widget.controller.seekTo(positionSeconds: newPosition.toInt());
                              setState(() {
                                _sliderPositionOnDrag = null;
                              });
                            },
                            onChanged: (newValue) {
                              setState(() {
                                _sliderPositionOnDrag = newValue;
                              });
                            },
                          ),
                        ),
                        isLive
                            ? const SizedBox.shrink()
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(timeLeft, style: style),
                            RichText(
                              text: TextSpan(
                                text: currentPosition,
                                style: style,
                                children: [const TextSpan(text: ' / '), TextSpan(text: totalDuration)],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CustomThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final double borderWidth;
  final double cornerRadius;

  const CustomThumbShape({
    this.thumbRadius = 10.0,
    this.borderWidth = 3.0,
    this.cornerRadius = 4.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    final outerPaint = Paint()
      ..color = AppTheme.fullFocusColor
      ..style = PaintingStyle.fill;

    final innerPaint = Paint()
      ..color = AppTheme.colorPrimary
      ..style = PaintingStyle.fill;

    final outerRect = Rect.fromCenter(
      center: center,
      width: thumbRadius * 2,
      height: thumbRadius * 2,
    );
    final outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(cornerRadius));

    final innerRect = outerRect.deflate(borderWidth);

    final innerCornerRadius = max(0.0, cornerRadius - borderWidth);
    final innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(innerCornerRadius));

    canvas.drawRRect(outerRRect, outerPaint);
    canvas.drawRRect(innerRRect, innerPaint);
  }
}
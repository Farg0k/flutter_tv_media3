import 'package:flutter/material.dart';

import 'widgets/clock_widget.dart';
import '../../../entity/playback_state.dart';
import '../../../entity/player_state.dart';
import '../../../utils/string_utils.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'widgets/custom_info_text_widget.dart';

class TimeLinePanel extends StatelessWidget {
  final Media3UiController controller;
  const TimeLinePanel({super.key, required this.controller});

  final style = const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18);

  @override
  Widget build(BuildContext context) {
    final bool isLive = controller.playerState.isLive;
    return Material(
      color: Colors.transparent,
      child: Row(
        spacing: 8,
        children: [
          StreamBuilder<PlayerState>(
            stream: controller.playerStateStream,
            initialData: controller.playerState,
            builder: (context, snapshot) {
              return snapshot.data?.stateValue == StateValue.paused
                  ? const Icon(Icons.pause, color: Colors.white, size: 40)
                  : const Icon(Icons.play_arrow, color: Colors.white, size: 40);
            },
          ),
          StreamBuilder<PlaybackState>(
            stream: controller.playbackStateStream,
            initialData: controller.playbackState,
            builder: (context, snapshot) {
              final data = snapshot.data!;
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            isLive
                                ? const SizedBox.shrink()
                                : Text('${(positionPercentage * 100).round()}%', style: style),
                            const CustomInfoTextWidget(),
                            const ClockWidget(),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(color: Colors.white, height: 10),
                            Container(
                              color: Colors.grey,
                              height: 10,
                              width: bufferedPercentage > 0 ? constraints.maxWidth * bufferedPercentage : 0,
                            ),
                            Container(
                              color: Colors.blue,
                              height: 10,
                              width: positionPercentage > 0 ? constraints.maxWidth * positionPercentage : 0,
                            ),
                          ],
                        ),
                        isLive
                            ? Text('', style: style)
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
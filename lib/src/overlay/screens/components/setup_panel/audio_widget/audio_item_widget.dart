import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/media_track.dart';
import '../../../../../utils/string_utils.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/marquee_title_widget.dart';
import '../../widgets/video_info_item.dart';

class AudioItemWidget extends StatelessWidget {
  const AudioItemWidget({
    super.key,
    required this.controller,
    required this.track,
    required this.index,
    required this.isFocused,
  });

  final Media3UiController controller;
  final AudioTrack track;
  final int index;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = track.isSelected == true;
    final Color backgroundColor =
    isFocused
        ? AppTheme.focusColor
        : isSelected
        ? AppTheme.focusColor.withValues(alpha: 0.3)
        : Colors.transparent;
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () async {
          final bloc = context.read<OverlayUiBloc>();
          await controller.selectAudioTrack(track: track);
          bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            spacing: 16,
            children: [
              Icon(_getIcon(track), size: 40, color: isFocused || isSelected ? Colors.white : Colors.white70),
              Expanded(
                child: MarqueeWidget(
                  text: StringUtils.getAudioTrackLabel(track: track, index: index),
                  focus: isFocused,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isFocused || isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isFocused || isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (track.codec != null)
                    VideoInfoItem(icon: Icons.audiotrack, title: StringUtils.simplifyCodec(track.codec)),
                  if (track.mimeType != null)
                    VideoInfoItem(icon: Icons.multitrack_audio, title: StringUtils.simplifyMimeType(track.mimeType)),
                  if (track.bitrate != null)
                    VideoInfoItem(icon: Icons.equalizer, title: StringUtils.formatBitrate(track.bitrate)),
                  if ((track.channelCount ?? 0) > 0)
                    VideoInfoItem(icon: Icons.surround_sound, title: StringUtils.formatChannels(track.channelCount)),
                  if ((track.sampleRate ?? 0) > 0)
                    VideoInfoItem(icon: Icons.waves, title: '${track.sampleRate! ~/ 1000} kHz'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(AudioTrack track) {
    if (track.index == -1) {
      return Icons.close;
    }
    return track.isSelected == true ? Icons.audiotrack : Icons.audiotrack_outlined;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/media_track.dart';
import '../../../../../utils/string_utils.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/marquee_title_widget.dart';
import '../../widgets/video_info_item.dart';

class VideoItemWidget extends StatelessWidget {
  const VideoItemWidget({super.key, required this.controller, required this.track, required this.isFocused});

  final Media3UiController controller;
  final VideoTrack track;
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
          await controller.selectVideoTrack(track: track);
          bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            spacing: 16,
            children: [
              Icon(
                isSelected ? Icons.check : _getIcon(width: track.width, label: track.label),
                color: isFocused || isSelected ? Colors.white : Colors.white70,
              ),
              Expanded(
                child: MarqueeWidget(
                  text: StringUtils.getVideoTrackLabel(track),
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
                  if (track.width != null && track.height != null)
                    VideoInfoItem(icon: _getIcon(width: track.width), title: '${track.width}x${track.height}'),
                  if (track.containerMimeType != null)
                    VideoInfoItem(
                      icon: Icons.video_collection,
                      title: StringUtils.simplifyMimeType(track.containerMimeType),
                    ),
                  if (track.frameRate != null && track.frameRate! > 1.0)
                    VideoInfoItem(icon: Icons.video_label, title: '${track.frameRate!.toStringAsFixed(1)} fps'),
                  if (track.bitrate != null)
                    VideoInfoItem(icon: Icons.speed, title: StringUtils.formatBitrate(track.bitrate!)),
                  if (track.sampleMimeType != null)
                    VideoInfoItem(icon: Icons.video_file, title: StringUtils.simplifyMimeType(track.sampleMimeType!)),
                  if (track.codecs != null)
                    VideoInfoItem(icon: Icons.personal_video, title: StringUtils.simplifyCodec(track.codecs!)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _getIcon({int? width, String? label}) {
    if (width != null) {
      if (width > 2000) {
        return Icons.four_k_outlined;
      } else if (width > 1000) {
        return Icons.hd_outlined;
      } else {
        return Icons.sd_outlined;
      }
    }
    if (label != null) {
      final lowerLabel = label.toLowerCase();
      if (lowerLabel.contains('4k')) {
        return Icons.four_k_outlined;
      } else if (RegExp(r'1080|720|hd').hasMatch(lowerLabel)) {
        return Icons.hd_outlined;
      } else if (RegExp(r'480|360|sd').hasMatch(lowerLabel)) {
        return Icons.sd_outlined;
      }
    }
    return Icons.slideshow;
  }
}

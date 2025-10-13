import 'package:flutter/material.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/find_subtitles_state.dart';
import '../../../../../entity/media_track.dart';
import '../../../../../utils/string_utils.dart';
import '../../widgets/marquee_title_widget.dart';

class SubtitleItemWidget extends StatelessWidget {
  const SubtitleItemWidget({
    super.key,
    required this.track,
    required this.index,
    required this.isFocused,
    this.searchStatus = SubtitleSearchStatus.idle,
    this.stateInfoLabel,
    this.onTap,
  });

  final SubtitleTrack track;
  final int index;
  final bool isFocused;
  final SubtitleSearchStatus searchStatus;
  final String? stateInfoLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = track.isSelected == true;
    final Color backgroundColor =
        isFocused
            ? AppTheme.focusColor
            : isSelected
            ? AppTheme.focusColor.withValues(alpha: 0.3)
            : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: _buildIcon(track, isSelected, isFocused),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MarqueeWidget(
                  text: StringUtils.getSubtitleTrackLabel(
                    track: track,
                    index: index,
                  ),
                  focus: isFocused,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        isFocused || isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                    color:
                        isFocused || isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              if (stateInfoLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    stateInfoLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isFocused ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              if (track.isExternal == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.file_download, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(SubtitleTrack track, bool isSelected, bool isFocused) {
    final color = isFocused || isSelected ? Colors.white : Colors.white70;

    if (track.id == '-2') {
      switch (searchStatus) {
        case SubtitleSearchStatus.loading:
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          );
        case SubtitleSearchStatus.error:
          return Icon(Icons.error_outline, size: 40, color: color);
        default:
          return Icon(Icons.search, size: 40, color: color);
      }
    }

    if (track.index == -1) {
      return Icon(Icons.subtitles_off_outlined, size: 40, color: color);
    }
    return Icon(
      isSelected ? Icons.subtitles : Icons.subtitles_outlined,
      size: 40,
      color: color,
    );
  }
}

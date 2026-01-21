import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_theme/app_theme.dart';
import '../../../entity/epg_channel.dart';
import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';
import 'widgets/video_info_widget.dart';

class InfoPanel extends StatelessWidget {
  final Media3UiController controller;

  const InfoPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
                buildWhen: (oldState, newState) => oldState.playIndex != newState.playIndex,
                builder: (context, state) {
                  final playItem = controller.playerState.playlist[state.playIndex];
                  final hasEpg = playItem.programs != null;
                  final programs = playItem.programs ?? [];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 16, right: 16),
                      constraints: BoxConstraints(minHeight: playItem.coverImg != null ? 170 : 120, maxHeight: 360),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: AppTheme.borderRadius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                if (playItem.coverImg != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, right: 16.0, bottom: 16.0),
                                    child: Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor,
                                        borderRadius: AppTheme.borderRadius,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.divider,
                                            blurRadius: 12,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      constraints: const BoxConstraints(maxHeight: 170, minWidth: 120),
                                      child: Image.network(
                                        playItem.coverImg!,
                                        fit: BoxFit.cover,
                                        height: 170,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              value:
                                                  loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(child: Icon(Icons.image, color: Colors.white38));
                                        },
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 3,
                                    children: [
                                      if (playItem.title != null || playItem.label != null)
                                        Text(
                                          playItem.title ?? playItem.label!,
                                          style: Theme.of(context).textTheme.titleLarge,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (hasEpg)
                                        if (programs.isNotEmpty)
                                          _EpgInfo(programs: programs)
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              OverlayLocalizations.get('live'),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.headlineSmall?.merge(AppTheme.extraLightTextStyle),
                                            ),
                                          )
                                      else ...[
                                        if (playItem.subTitle != null)
                                          Text(
                                            playItem.subTitle!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.merge(AppTheme.extraLightTextStyle),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (playItem.title != null &&
                                            playItem.label != null &&
                                            playItem.title != playItem.label)
                                          Text(
                                            playItem.label!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall?.merge(AppTheme.extraLightTextStyle),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (playItem.description != null)
                                          Text(
                                            playItem.description!,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VideoInfoWidget(controller: controller, state: state),
                          TimeLinePanel(controller: controller),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpgInfo extends StatefulWidget {
  final List<EpgProgram> programs;
  const _EpgInfo({required this.programs});

  @override
  State<_EpgInfo> createState() => _EpgInfoState();
}

class _EpgInfoState extends State<_EpgInfo> {
  EpgProgram? _currentProgram;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateProgram();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateProgram();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgram() {
    final now = DateTime.now();
    final currentProgram = widget.programs.firstWhere(
      (program) => now.isAfter(program.startTime) && now.isBefore(program.endTime),
    );
    if (currentProgram != _currentProgram) {
      setState(() {
        _currentProgram = currentProgram;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProgram == null) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final progress =
        now.difference(_currentProgram!.startTime).inSeconds /
        _currentProgram!.endTime.difference(_currentProgram!.startTime).inSeconds;

    final startTime = OverlayLocalizations.timeFormat(date: _currentProgram!.startTime);
    final endTime = OverlayLocalizations.timeFormat(date: _currentProgram!.endTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          _currentProgram!.title,
          style: Theme.of(context).textTheme.headlineMedium?.merge(AppTheme.extraLightTextStyle),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (_currentProgram!.description != null) ...[
          Text(
            _currentProgram!.description!,
            style: Theme.of(context).textTheme.bodyLarge?.merge(AppTheme.infoTextStyle),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        Row(
          spacing: 8,
          children: [
            Text(startTime, style: AppTheme.infoTextStyle),
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                color: Colors.white,
              ),
            ),
            Text(endTime, style: AppTheme.infoTextStyle),
          ],
        ),
        SizedBox(height: 4),
      ],
    );
  }
}

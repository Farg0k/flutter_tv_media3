import 'dart:async';
import 'package:flutter/material.dart';


import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/epg_channel.dart';
import '../../widgets/marquee_title_widget.dart';


class ProgramListItem extends StatefulWidget {
  final EpgProgram program;
  final bool isSelected;
  final bool isTheActiveProgram;

  const ProgramListItem({super.key, required this.program, required this.isSelected, required this.isTheActiveProgram});

  @override
  State<ProgramListItem> createState() => _ProgramListItemState();
}

class _ProgramListItemState extends State<ProgramListItem> {
  Timer? _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.isTheActiveProgram) {
      _updateProgress();
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(ProgramListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTheActiveProgram != oldWidget.isTheActiveProgram) {
      if (widget.isTheActiveProgram) {
        _updateProgress();
        _startTimer();
      } else {
        _stopTimer();
        setState(() {
          _progress = 0.0;
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel(); 
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateProgress();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _updateProgress() {
    final now = DateTime.now();
    final program = widget.program;
    if (now.isBefore(program.startTime) || now.isAfter(program.endTime)) {
      setState(() => _progress = 0.0);
      _timer?.cancel();
      return;
    }
    setState(() {
      _progress =
          (now.difference(program.startTime).inSeconds / program.endTime.difference(program.startTime).inSeconds).clamp(
            0.0,
            1.0,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final now = DateTime.now();
    final isPassed = program.endTime.isBefore(now);

    return Container(
      color: widget.isTheActiveProgram && widget.isSelected == false ? AppTheme.focusColor.withValues(alpha:0.2) : null,

      child: ListTile(
        leading: Text(
          '${program.startTime.hour}:${program.startTime.minute.toString().padLeft(2, '0')} - ${program.endTime.hour}:${program.endTime.minute.toString().padLeft(2, '0')}',
          style: isPassed ? AppTheme.programListPassedItemTimeStyle : AppTheme.programListItemTimeStyle,
        ),
        title: MarqueeWidget(
          text: program.title,
          style: TextStyle(
            fontWeight: widget.isSelected || widget.isTheActiveProgram
                ? FontWeight.bold
                : FontWeight.normal,
            color: isPassed
                ? AppTheme.colorSecondary.withValues(alpha:0.5)
                : AppTheme.colorPrimary,
          ),
          focus: widget.isSelected,
        ),
        subtitle: null,
        trailing: widget.isTheActiveProgram
            ? Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.0,
                        value: _progress,
                        color: AppTheme.fullFocusColor,
                        backgroundColor: AppTheme.divider,
                      ),
                    ),
                    Icon(Icons.play_arrow, color: AppTheme.colorPrimary, size: 18),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
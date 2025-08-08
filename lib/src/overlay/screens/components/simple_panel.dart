import 'package:flutter/material.dart';
import '../../../app_theme/app_theme.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';

class SimplePanel extends StatelessWidget {
  final Media3UiController controller;
  const SimplePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Stack(
        children: [
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              constraints: BoxConstraints(minHeight: 60, maxWidth: MediaQuery.of(context).size.width),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: AppTheme.borderRadius,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: TimeLinePanel(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

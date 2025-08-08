import 'package:flutter/material.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../widgets/clock_widget.dart';

class EpgPageIndicator extends StatelessWidget {
  final TabController tabController;
  final List<Tab> tabs;
  final Locale deviceLocale;

  const EpgPageIndicator({super.key, required this.tabController, required this.tabs, required this.deviceLocale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:  EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: TabBar(
              controller: tabController,
              tabs: tabs,
              indicator: UnderlineTabIndicator(borderSide: BorderSide(width: 2, color: AppTheme.fullFocusColor)),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.only(top: -4.0),
              labelPadding: EdgeInsets.zero,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              labelStyle: AppTheme.indicatorSelectedLabelStyle,
              unselectedLabelStyle: AppTheme.indicatorUnselectedLabelStyle,
              labelColor: AppTheme.colorPrimary,
              unselectedLabelColor: AppTheme.colorSecondary,
            ),
          ),
          ClockWidget(),
        ],
      ),
    );
  }
}

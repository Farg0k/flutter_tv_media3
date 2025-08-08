import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/epg_channel.dart';
import '../bloc/epg_bloc.dart';
import 'channel_logo_widget.dart';
import 'custom_list_widget.dart';
import 'program_list_item.dart';

class ProgramsListView extends StatelessWidget {
  final FocusNode focusNode;
  final bool hasFocus;
  final ValueChanged<bool> onScrollUpChanged;
  final ValueChanged<bool> onScrollDownChanged;

  const ProgramsListView({
    super.key,
    required this.focusNode,
    required this.hasFocus,
    required this.onScrollUpChanged,
    required this.onScrollDownChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EpgBloc>().state;
    final bloc = context.read<EpgBloc>();
    final programs = state.selectedChannel?.programs ?? [];
    final selectedChannel = state.selectedChannel;

    if (selectedChannel == null) {
      return Center(child: Text(OverlayLocalizations.get('selectChannel')));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            spacing: 8,
            children: [
              ChannelLogoWidget(logoUrl: selectedChannel.logoUrl, dimension: 40),
              Expanded(
                child: Text(
                  selectedChannel.name,
                  style: AppTheme.programsChannelNameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: programs.isEmpty
              ? Center(
                  child: Text(
                    OverlayLocalizations.get('live'),
                    style: Theme.of(context).textTheme.headlineMedium?.merge(AppTheme.boldTextStyle),
                  ),
                )
              : CustomListWidget<EpgProgram>(
                  focusNode: focusNode,
                  items: programs,
                  initialIndex: state.selectedProgramIndex,
                  hasFocus: hasFocus,
                  onSelectedIndexChanged: (newIndex) {
                    bloc.add(EpgProgramSelected(newIndex));
                  },
                  onScrollUpChanged: onScrollUpChanged,
                  onScrollDownChanged: onScrollDownChanged,
                  itemBuilder: (program, index, isSelected, isFocused) {
                    return ProgramListItem(
                      program: program,
                      isSelected: isSelected,
                      isTheActiveProgram: index == state.activeProgramIndex,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';

class ShortcutsItemsWidget extends ConsumerStatefulWidget {
  const ShortcutsItemsWidget({super.key, required this.data});
  final ShortcutsModel data;
  @override
  ConsumerState<ShortcutsItemsWidget> createState() =>
      _ShortcutsItemsWidgetState();
}

class _ShortcutsItemsWidgetState extends ConsumerState<ShortcutsItemsWidget> {
  late ShortcutsModel data;
  late List<Widget> shortcutsWidgetList = [];

  @override
  void didChangeDependencies() {
    data = widget.data;
    shortcutsWidgetList = _getShortcutsItemWidgetList();
    super.didChangeDependencies();
  }

  void _handleChipPress(
    BuildContext context,
    WidgetRef ref,
    ShortcutsItemsModel element,
  ) async {
    _handleTrackEvent(ref, element.id, element.title);
    await handleNavigation(
      context: context,
      element.type,
      [element.path.toString().getIdFromPath(), element.path],
      ref: ref,
    );
  }

  void _handleTrackEvent(WidgetRef ref, String chipId, String chipTitle) {
    var chipViewedModel = ChipTappedModel(chipId: chipId, chipTitle: chipTitle);
    var event = EventsModel(
      name: EventTypes.chipTapped,
      payload: chipViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      _handleShortcutWidgetPlacement(newIndex, oldIndex);
      _handleShortcutItemPlacementInPreference(oldIndex, newIndex);
    });
  }

  void _handleShortcutItemPlacementInPreference(int oldIndex, int newIndex) {
    var _data = [...data.shortcuts];
    final element = _data.removeAt(oldIndex);
    _data.insert(newIndex, element);
    data = data.copyWith(shortcuts: _data);
    var ids = _data.map((e) => e.id).toList();
    ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids));
  }

  void _handleShortcutWidgetPlacement(int newIndex, int oldIndex) {
    shortcutsWidgetList.insert(
      newIndex,
      shortcutsWidgetList.removeAt(oldIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableWrap(
      spacing: 8.0,
      runSpacing: 8.0,
      padding: EdgeInsets.zero,
      maxMainAxisCount: 2,
      minMainAxisCount: 2,
      onReorder: _onReorder,
      children: shortcutsWidgetList,
    );
  }

  List<Widget> _getShortcutsItemWidgetList() {
    var size = MediaQuery.of(context).size;
    final containerHeight = 48.0;
    final containerWidth = (size.width / 2) - (padding20 + 2);

    return data.shortcuts
        .map((e) => IntrinsicWidth(
              child: InkWell(
                key: ValueKey(e.id),
                onTap: () => _handleChipPress(context, ref, e),
                child: Container(
                  height: containerHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: ColorConstants.onyx,
                  ),
                  padding: EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: containerWidth,
                    minWidth: containerWidth,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${e.title}',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ))
        .toList();
  }
}

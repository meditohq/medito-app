import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';

class ShortcutsWidget extends ConsumerStatefulWidget {
  const ShortcutsWidget({super.key});

  @override
  ConsumerState<ShortcutsWidget> createState() => _ShortcutsWidgetState();
}

class _ShortcutsWidgetState extends ConsumerState<ShortcutsWidget> {
  late ShortcutsModel data;
  late List<Widget> shortcutsWidgetList = [];
  @override
  void initState() {
    super.initState();
  }

  void handleChipPress(
    BuildContext context,
    WidgetRef ref,
    HomeChipsItemsModel element,
  ) async {
    handleTrackEvent(ref, element.id, element.title);
    await handleNavigation(
      context: context,
      element.type,
      [element.path.toString().getIdFromPath(), element.path],
      ref: ref,
    );
  }

  void handleTrackEvent(WidgetRef ref, String chipId, String chipTitle) {
    var chipViewedModel = ChipTappedModel(chipId: chipId, chipTitle: chipTitle);
    var event = EventsModel(
      name: EventTypes.chipTapped,
      payload: chipViewedModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      handleShortcutWidgetPlacement(newIndex, oldIndex);
      handleShortcutItemPlacementInPreference(oldIndex, newIndex);
    });
  }

  void handleShortcutItemPlacementInPreference(int oldIndex, int newIndex) {
    var _data = [...data.shortcuts];
    final element = _data.removeAt(oldIndex);
    _data.insert(newIndex, element);
    data = data.copyWith(shortcuts: _data);
    var ids = _data.map((e) => e.id).toList();
    ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids));
  }

  void handleShortcutWidgetPlacement(int newIndex, int oldIndex) {
    shortcutsWidgetList.insert(
      newIndex,
      shortcutsWidgetList.removeAt(oldIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    var response = ref.watch(fetchShortcutsProvider);
    ref.listen(fetchShortcutsProvider, (previous, next) {
      if (next.hasValue) {
        data = next.value!;
        shortcutsWidgetList = getShortcutsItemWidgetList();
      }
    });

    return response.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: (_) => buildShortcuts(),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchShortcutsProvider),
        isLoading: response.isLoading,
        isScaffold: false,
      ),
      loading: () => const ShortcutsShimmerWidget(),
    );
  }

  ReorderableWrap buildShortcuts() {
    return ReorderableWrap(
      spacing: 8.0,
      runSpacing: 8.0,
      padding: EdgeInsets.zero,
      maxMainAxisCount: 2,
      minMainAxisCount: 2,
      onReorder: onReorder,
      children: shortcutsWidgetList,
    );
  }

  List<Widget> getShortcutsItemWidgetList() {
    var size = MediaQuery.of(context).size;
    final containerHeight = 48.0;
    final containerWidth = (size.width / 2) - (padding20 + 2);

    return data.shortcuts
        .map((e) => IntrinsicWidth(
              child: InkWell(
                key: ValueKey(e.id),
                onTap: () => handleNavigation(context: context, e.type, [
                  e.path.toString().getIdFromPath(),
                  e.path,
                ]),
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

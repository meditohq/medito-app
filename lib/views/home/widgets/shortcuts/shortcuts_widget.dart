import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class ShortcutsWidget extends ConsumerStatefulWidget {
  const ShortcutsWidget({super.key});

  @override
  ConsumerState<ShortcutsWidget> createState() => _ShortcutsWidgetState();
}

class _ShortcutsWidgetState extends ConsumerState<ShortcutsWidget> {
  var data = <HomeChipsItemsModel>[];
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var response = ref.watch(fetchShortcutsProvider);

    return response.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (data) => _buildShortcuts(data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchShortcutsProvider),
        isLoading: response.isLoading,
      ),
      loading: () => const ShortcutsShimmerWidget(),
    );
  }

  Padding _buildShortcuts(ShortcutsModel data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Theme(
        data: Theme.of(context).copyWith(canvasColor: ColorConstants.onyx),
        child: ReorderableGridView.count(
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          crossAxisCount: 2,
          shrinkWrap: true,
          childAspectRatio: 3,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          clipBehavior: Clip.hardEdge,
          children: data.shortcuts
              .map(
                (e) => InkWell(
                  key: ValueKey(e.id),
                  onTap: () => handleNavigation(context: context, e.type, [
                    e.path.toString().getIdFromPath(),
                    e.path,
                  ]),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: ColorConstants.onyx,
                    ),
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              height: 1,
                            ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final element = data.shortcuts.removeAt(oldIndex);
              data.shortcuts.insert(newIndex, element);
            });
          },
        ),
      ),
    );
  }

  void handleChipPress(
    BuildContext context,
    WidgetRef ref,
    HomeChipsItemsModel element,
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
}

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class FilterWidget extends ConsumerStatefulWidget {
  const FilterWidget({super.key, required this.chips});

  final List<List<HomeChipsItemsModel>> chips;

  @override
  ConsumerState<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends ConsumerState<FilterWidget> {
  var data = <HomeChipsItemsModel>[];
  @override
  void initState() {
    data = widget.chips.first;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
          children: data
              .map(
                (e) => Container(
                  key: ValueKey(e.id),
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
              )
              .toList(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final element = data.removeAt(oldIndex);
              data.insert(newIndex, element);
            });
          },
        ),
      ),
    );
    // return _filterListView(widget.chips.first);
  }

  Padding _filterListView(List<HomeChipsItemsModel> items) {
    return Padding(
      padding: const EdgeInsets.only(left: defaultPadding, right: 8),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
        ),
        itemBuilder: (context, itemIndex) {
          var element = items[itemIndex];

          return Theme(
            key: ValueKey(element.id),
            data: Theme.of(context).copyWith(canvasColor: ColorConstants.onyx),
            child: ActionChip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () => handleChipPress(context, ref, element),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              labelPadding: EdgeInsets.all(6),
              label: Text(
                element.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      height: 1,
                    ),
              ),
            ),
          );
        },
        // onReorder: (oldIndex, newIndex) {
        //   setState(() {
        //     if (oldIndex < newIndex) {
        //       newIndex -= 1;
        //     }
        //     var item = items.removeAt(oldIndex);

        //     items.insert(newIndex, item);
        //   });
        // },
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

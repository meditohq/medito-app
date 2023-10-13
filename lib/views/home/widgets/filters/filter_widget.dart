import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterWidget extends ConsumerWidget {
  const FilterWidget({super.key, required this.chips});
  final List<List<HomeChipsItemsModel>> chips;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: chips.map((e) => _filterListView(ref, e)).toList(),
      ),
    );
  }

  Padding _filterListView(WidgetRef ref, List<HomeChipsItemsModel> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: SizedBox(
        height: 49,
        child: ListView.builder(
          itemCount: items.length,
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            var element = items[index];

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(canvasColor: ColorConstants.onyx),
                child: ActionChip(
                  onPressed: () => handleChipPress(context, ref, element),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: ColorConstants.transparent,
                  labelPadding:
                      EdgeInsets.only(left: 12, right: 12, top: 3, bottom: 5),
                  label: Text(
                    element.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            );
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

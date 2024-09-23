import 'package:freezed_annotation/freezed_annotation.dart';

part 'explore_list_item.freezed.dart';

@freezed
class ExploreListItem with _$ExploreListItem {
  const factory ExploreListItem.track({
    required String id,
    required String title,
    required String subtitle,
    required String coverUrl,
    required String path,
  }) = TrackItem;

  const factory ExploreListItem.pack({
    required String id,
    required String title,
    required String subtitle,
    required String coverUrl,
    required String path,
  }) = PackItem;
}
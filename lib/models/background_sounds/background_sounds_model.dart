import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_sounds_model.freezed.dart';
part 'background_sounds_model.g.dart';

/// Id of the synthetic "no background sound" entry the repository prepends to
/// the fetched list. Identify it by id, never by title: the title is the
/// English literal 'None' and is localised for display, so comparing it to a
/// localised string silently fails on every non-English locale.
const kNoneBackgroundSoundId = '0';

@freezed
abstract class BackgroundSoundsModel with _$BackgroundSoundsModel {
  const factory BackgroundSoundsModel({
    required String id,
    required String title,
    required String path,
    required int duration,
  }) = _BackgroundSoundsModel;

  factory BackgroundSoundsModel.fromJson(Map<String, Object?> json) =>
      _$BackgroundSoundsModelFromJson(json);
}

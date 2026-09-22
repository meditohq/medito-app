import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_sounds_model.freezed.dart';
part 'background_sounds_model.g.dart';

/// Id of the synthetic "no background sound" entry the repository prepends to
/// the fetched list. Identify it by id, never by title: the title is the
/// English literal 'None' and is localised for display, so comparing it to a
/// localised string silently fails on every non-English locale.
const kNoneBackgroundSoundId = '0';

// A local playback mode, never a downloadable/looping ambient sound.
const kSessionBellsId = 'medito-session-bells';
const kSessionBellsUri = 'medito://session-bells';
const kSessionBellAsset = 'assets/audio/session_bell_v2.wav';
const kSessionBellsSound = BackgroundSoundsModel(
  id: kSessionBellsId,
  title: 'Session bells',
  path: kSessionBellsUri,
  duration: 0,
);

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

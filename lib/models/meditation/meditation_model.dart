import 'package:freezed_annotation/freezed_annotation.dart';
part 'meditation_model.freezed.dart';
part 'meditation_model.g.dart';

@unfreezed
abstract class MeditationModel with _$MeditationModel {
  const MeditationModel._();
  factory MeditationModel({
    required String id,
    required String title,
    String? subtitle,
    required String description,
    required String coverUrl,
    required bool isPublished,
    required bool hasBackgroundSound,
    @Default(null) MeditationArtistModel? artist,
    @Default(<MeditationAudioModel>[]) List<MeditationAudioModel> audio,
  }) = _MeditationModel;

  factory MeditationModel.fromJson(Map<String, Object?> json) =>
      _$MeditationModelFromJson(json);
  MeditationModel customCopyWith() {
    return MeditationModel(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      coverUrl: coverUrl,
      isPublished: isPublished,
      hasBackgroundSound: hasBackgroundSound,
      artist: artist,
      audio: [
        ...audio
            .map(
              (e) => MeditationAudioModel(
                guideName: e.guideName,
                files: [
                  ...e.files.map((e) => e).toList(),
                ],
              ),
            )
            .toList(),
      ],
    );
  }
}

@unfreezed
abstract class MeditationArtistModel with _$MeditationArtistModel {
  factory MeditationArtistModel({required String name, required String path}) =
      _MeditationArtistModel;

  factory MeditationArtistModel.fromJson(Map<String, Object?> json) =>
      _$MeditationArtistModelFromJson(json);
}

@unfreezed
abstract class MeditationAudioModel with _$MeditationAudioModel {
  factory MeditationAudioModel({
    String? guideName,
    @Default([]) List<MeditationFilesModel> files,
  }) = _MeditationAudioModel;

  factory MeditationAudioModel.fromJson(Map<String, Object?> json) =>
      _$MeditationAudioModelFromJson(json);
}

@unfreezed
abstract class MeditationFilesModel with _$MeditationFilesModel {
  factory MeditationFilesModel({
    required String id,
    required String path,
    required int duration,
  }) = _MeditationFilesModel;

  factory MeditationFilesModel.fromJson(Map<String, Object?> json) =>
      _$MeditationFilesModelFromJson(json);
}

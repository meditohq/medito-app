import 'package:freezed_annotation/freezed_annotation.dart';
part 'session_model.freezed.dart';
part 'session_model.g.dart';

@unfreezed
abstract class SessionModel with _$SessionModel {
   const SessionModel._();
  factory SessionModel(
      {required int id,
      required String title,
      required String description,
      required String coverUrl,
      required bool isPublished,
      required bool hasBackgroundSound,
      @Default(null) SessionArtistModel? artist,
      @Default([]) List<SessionAudioModel> audio}) = _SessionModel;

  factory SessionModel.fromJson(Map<String, Object?> json) =>
      _$SessionModelFromJson(json);
  SessionModel customCopyWith() {
    return SessionModel(
      id: id,
      title: title,
      description: description,
      coverUrl: coverUrl,
      isPublished: isPublished,
      hasBackgroundSound: hasBackgroundSound,
      artist: artist,
      audio: [
        ...audio
            .map(
              (e) => SessionAudioModel(
                guideName: e.guideName,
                files: [
                  ...e.files.map((e) => e).toList(),
                ],
              ),
            )
            .toList()
      ],
    );
  }
}

@unfreezed
abstract class SessionArtistModel with _$SessionArtistModel {
  factory SessionArtistModel({required String name, required String path}) =
      _SessionArtistModel;

  factory SessionArtistModel.fromJson(Map<String, Object?> json) =>
      _$SessionArtistModelFromJson(json);
}

@unfreezed
abstract class SessionAudioModel with _$SessionAudioModel {
  factory SessionAudioModel(
      {required String guideName,
      @Default([]) List<SessionFilesModel> files}) = _SessionAudioModel;

  factory SessionAudioModel.fromJson(Map<String, Object?> json) =>
      _$SessionAudioModelFromJson(json);
}

@unfreezed
abstract class SessionFilesModel with _$SessionFilesModel {
  factory SessionFilesModel({
    required int id,
    required String path,
    required int duration,
  }) = _SessionFilesModel;

  factory SessionFilesModel.fromJson(Map<String, Object?> json) =>
      _$SessionFilesModelFromJson(json);
}

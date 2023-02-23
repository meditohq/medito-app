import 'package:freezed_annotation/freezed_annotation.dart';
part 'session_model.freezed.dart';
part 'session_model.g.dart';

@freezed
abstract class SessionModel with _$SessionModel {
  const factory SessionModel(
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
}

@freezed
abstract class SessionArtistModel with _$SessionArtistModel {
  const factory SessionArtistModel(
      {required String title, required String path}) = _SessionArtistModel;

  factory SessionArtistModel.fromJson(Map<String, Object?> json) =>
      _$SessionArtistModelFromJson(json);
}

@freezed
abstract class SessionAudioModel with _$SessionAudioModel {
  const factory SessionAudioModel(
      {required String guideName,
      @Default([]) List<SessionFilesModel> files}) = _SessionAudioModel;

  factory SessionAudioModel.fromJson(Map<String, Object?> json) =>
      _$SessionAudioModelFromJson(json);
}

@freezed
abstract class SessionFilesModel with _$SessionFilesModel {
  const factory SessionFilesModel(
      {required int id,
      required String path,
      required int duration}) = _SessionFilesModel;

  factory SessionFilesModel.fromJson(Map<String, Object?> json) =>
      _$SessionFilesModelFromJson(json);
}

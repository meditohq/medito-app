import 'package:freezed_annotation/freezed_annotation.dart';

part 'events_model.freezed.dart';
part 'events_model.g.dart';

@freezed
abstract class EventsModel with _$EventsModel {
  const factory EventsModel({
    required String name,
    required Map<String, dynamic> payload,
  }) = _EventsModel;

  factory EventsModel.fromJson(Map<String, Object?> json) =>
      _$EventsModelFromJson(json);
}

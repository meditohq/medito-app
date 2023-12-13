import 'package:freezed_annotation/freezed_annotation.dart';

part 'pack_viewed_model.freezed.dart';
part 'pack_viewed_model.g.dart';

@freezed
abstract class PackViewedModel with _$PackViewedModel {
  const factory PackViewedModel({
    required String packId,
  }) = _PackViewedModel;

  factory PackViewedModel.fromJson(Map<String, Object?> json) =>
      _$PackViewedModelFromJson(json);
}

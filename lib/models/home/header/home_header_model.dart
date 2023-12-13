import 'package:Medito/models/models.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_header_model.freezed.dart';
part 'home_header_model.g.dart';

@freezed
abstract class HomeHeaderModel with _$HomeHeaderModel {
  const factory HomeHeaderModel({
    required String greeting,
    AnnouncementModel? announcement,
    @Default(<HomeMenuModel>[]) List<HomeMenuModel> menu,
  }) = _HomeHeaderModel;

  factory HomeHeaderModel.fromJson(Map<String, Object?> json) =>
      _$HomeHeaderModelFromJson(json);
}

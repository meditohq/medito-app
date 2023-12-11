import 'package:freezed_annotation/freezed_annotation.dart';

import 'announcement/announcement_model.dart';
import 'chips/home_chips_items_model.dart';
import 'menu/home_menu_model.dart';
import 'rows/home_rows_model.dart';

part 'home_model.freezed.dart';
part 'home_model.g.dart';

@freezed
abstract class HomeModel with _$HomeModel {
  const factory HomeModel({
    AnnouncementModel? announcement,
    @Default(<HomeMenuModel>[]) List<HomeMenuModel> menu,
    @Default(<List<HomeChipsItemsModel>>[])
        List<List<HomeChipsItemsModel>> chips,
    @Default(<HomeRowsModel>[]) List<HomeRowsModel> rows,
  }) = _HomeModel;

  factory HomeModel.fromJson(Map<String, Object?> json) =>
      _$HomeModelFromJson(json);
}

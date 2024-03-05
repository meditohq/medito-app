import 'package:Medito/models/home/shortcuts/shortcuts_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_model.freezed.dart';
part 'home_model.g.dart';

@freezed
class HomeModel with _$HomeModel {
  const factory HomeModel({
    String? greeting,
    @Default(<HomeMenuModel>[]) List<HomeMenuModel> menu,
    @Default(<ShortcutsModel>[]) List<ShortcutsModel> shortcuts,
    @Default(<HomeCarouselModel>[]) List<HomeCarouselModel> carousel,
    HomeQuoteModel? todayQuote,
  }) = _HomeModel;

  factory HomeModel.fromJson(Map<String, dynamic> json) =>
      _$HomeModelFromJson(json);
}

@freezed
class HomeMenuModel with _$HomeMenuModel {
  const factory HomeMenuModel({
    required String id,
    required String type,
    required String title,
    required String icon,
    required String path,
  }) = _HomeMenuModel;

  factory HomeMenuModel.fromJson(Map<String, dynamic> json) =>
      _$HomeMenuModelFromJson(json);
}

@freezed
class HomeCarouselModel with _$HomeCarouselModel {
  const factory HomeCarouselModel({
    required String id,
    required String title,
    required String subtitle,
    required String coverUrl,
    required String path,
    required String type,
  }) = _HomeCarouselModel;

  factory HomeCarouselModel.fromJson(Map<String, dynamic> json) =>
      _$HomeCarouselModelFromJson(json);
}

@freezed
class HomeQuoteModel with _$HomeQuoteModel {
  const factory HomeQuoteModel({
    required String id,
    required String quote,
    required String author,
    String? sharedBy,
  }) = _HomeQuoteModel;

  factory HomeQuoteModel.fromJson(Map<String, dynamic> json) =>
      _$HomeQuoteModelFromJson(json);
}

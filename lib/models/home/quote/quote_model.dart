import 'package:freezed_annotation/freezed_annotation.dart';

part 'quote_model.freezed.dart';
part 'quote_model.g.dart';

@freezed
abstract class QuoteModel with _$QuoteModel {
  const factory QuoteModel({
    required String id,
    required String text,
    required String author,
  }) = _QuoteModel;

  factory QuoteModel.fromJson(Map<String, Object?> json) =>
      _$QuoteModelFromJson(json);
}

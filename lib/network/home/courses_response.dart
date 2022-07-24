import 'package:Medito/utils/utils.dart';

class CoursesResponse {
  List<Data> data = [];

  CoursesResponse({data});

  CoursesResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['data'] = this.data.map((v) => v.toJson()).toList();
    return data;
  }
}

class Data {
  String? title;
  String? subtitle;
  String? type;
  String? id;
  String? cover;
  String? get coverUrl => cover?.toAssetUrl() ?? '';
  String? get backgroundImageUrl => backgroundImage?.toAssetUrl() ?? '';
  String? backgroundImage;
  String? colorPrimary;

  Data(
      {this.title,
      this.subtitle,
      this.type,
      this.id,
      this.cover,
      this.backgroundImage,
      this.colorPrimary});

  Data.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    subtitle = json['subtitle'];
    type = json['type'];
    id = json['id'];
    cover = json['cover'];
    backgroundImage = json['background_image'];
    colorPrimary = json['color_primary'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['type'] = type;
    data['id'] = id;
    data['cover'] = cover;
    data['background_image'] = backgroundImage;
    data['color_primary'] = colorPrimary;
    return data;
  }
}

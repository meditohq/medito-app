/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/utils/utils.dart';

class ShortcutsResponse {
  List<ShortcutData>? data = [];

  ShortcutsResponse({this.data});

  ShortcutsResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <ShortcutData>[];
      json['data'].forEach((v) {
        data?.add(ShortcutData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ShortcutData {
  String? title;
  String? type;
  String? id;
  String? cover;
  String? get coverUrl => cover?.toAssetUrl();
  String? get bgImageUrl => backgroundImage?.toAssetUrl();
  String? backgroundImage;
  String? groundImage;
  String? colorPrimary;

  ShortcutData(
      {this.title,
        this.type,
        this.id,
        this.cover,
        this.backgroundImage,
        this.colorPrimary});

  ShortcutData.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    type = json['type'];
    id = json['id'];
    cover = json['cover'];
    backgroundImage = json['background_image'];
    colorPrimary = json['color_primary'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['type'] = type;
    data['id'] = id;
    data['cover'] = cover;
    data['background_image'] = backgroundImage;
    data['color_primary'] = colorPrimary;
    return data;
  }
}
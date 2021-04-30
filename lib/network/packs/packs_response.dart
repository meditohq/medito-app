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

import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/utils/utils.dart';

class PacksResponse {
  List<PacksData> data;

  PacksResponse({this.data});

  PacksResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <PacksData>[];
      json['data'].forEach((v) {
        data.add(PacksData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class PacksData {
  String title;
  String subtitle;
  String id;

  String get cover => coverOld?.toAssetUrl();
  String colorPrimary;
  String colorSecondary;

  String get backgroundImageUrl => backgroundImage?.toAssetUrl();
  String type;

  FileType get fileType {
    if (type == 'session') return FileType.session;
    if (type == 'article') return FileType.text;
    if (type == 'folder') return FileType.folder;
    if (type == 'url') return FileType.url;
    if (type == 'daily') return FileType.daily;
    return null;
  }

  @Deprecated('Use backgroundImageUrl')
  String backgroundImage;
  @Deprecated('Use cover instead')
  String coverOld;

  PacksData(
      {this.title,
      this.subtitle,
      this.type,
      this.id,
      this.colorPrimary,
      this.colorSecondary,
      this.coverOld});

  PacksData.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    subtitle = json['subtitle'];
    type = json['type'];
    id = json['id'];
    backgroundImage = json['background_image'];
    colorPrimary = json['color_primary'];
    colorSecondary = json['color_secondary'];
    coverOld = json['cover'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['type'] = type;
    data['id'] = id;
    data['background_image'] = backgroundImage;
    data['color_primary'] = colorPrimary;
    data['color_secondary'] = colorSecondary;
    data['cover'] = coverOld;
    return data;
  }
}
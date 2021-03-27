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

import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/viewmodel/auth.dart';

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
  String get id => idOld.toString();
  String get cover => '${baseUrl}assets/$coverOld?download';
  String colorPrimary;
  String colorSecondary;

  FileType get fileType {
    if (type == 'session') return FileType.session;
    if (type == 'article') return FileType.text;
    if (type == 'folder') return FileType.folder;
    if (type == 'url') return FileType.folder;
    if (type == 'dailies') return FileType.dailies;
    return null;
  }

  @Deprecated('Use cover instead')
  String coverOld;
  @Deprecated('Use fileType instead')
  String type;
  @Deprecated('Use id instead')
  int idOld;

  PacksData(
      {this.title,
      this.subtitle,
      this.type,
      this.idOld,
      this.colorPrimary,
      this.colorSecondary,
      this.coverOld});

  PacksData.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    subtitle = json['subtitle'];
    type = json['type'];
    idOld = json['id'];
    colorPrimary = json['color_primary'];
    colorSecondary = json['color_secondary'];
    coverOld = json['cover'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['subtitle'] = subtitle;
    data['type'] = type;
    data['id'] = idOld;
    data['color_primary'] = colorPrimary;
    data['color_secondary'] = colorSecondary;
    data['cover'] = coverOld;
    return data;
  }
}

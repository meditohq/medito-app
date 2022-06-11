/*file is part of Medito App.

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

class FolderResponse {
  Data? _data;

  bool get hasData => _data != null;

  String get title => _data?.title;

  String get description => _data?.description;

  String get colour => _data?.primaryColor;

  String get backgroundImageUrl => _data?.backgroundImage?.toAssetUrl();

  String get cover => _data?.cover;

  String get coverUrl => cover?.toAssetUrl();

  String get id => _data?.id.toString();

  List<Item> get items => _data?.items
      ?.map((e) => e.item)
      ?.toList()
      ?.whereType<Item>()
      ?.toList(); //removes nulls

  FolderResponse({data});

  FolderResponse.fromJson(Map<String, dynamic> json) {
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (data != null) {
      data['data'] = this._data.toJson();
    }
    return data;
  }
}

class Data {
  int id;
  String title;
  String description;
  String primaryColor;
  String backgroundImage;
  String cover;
  List<Items> items;

  Data({id, title, subtitle, cover, items});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    primaryColor = json['color_primary'];
    backgroundImage = json['background_image'];
    cover = json['cover'];
    if (json['items'] != null) {
      items = <Items>[];
      json['items'].forEach((v) {
        items.add(Items.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['description'] = description;
    data['background_image'] = backgroundImage;
    data['color_primary'] = primaryColor;
    data['cover'] = cover;
    if (items != null) {
      data['items'] = items.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Items {
  Item? item;

  Items.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (item != null) {
      data['item'] = item?.toJson();
    }
    return data;
  }
}

class Item {
  String? get id => _idInt.toString();
  String? oldId;
  String? title;
  String? subtitle;

  FileType get fileType {
    if (type == 'session') return FileType.session;
    if (type == 'article') return FileType.text;
    if (type == 'folder') return FileType.folder;
    if (type == 'url') {
      return FileType.folder;
    } else {
      return FileType.app;
    }
  }

  String? type;
  int? _idInt;

  Item({id, type, title, subtitle});

  Item.fromJson(Map<String, dynamic> json) {
    _idInt = json['id'];
    oldId = json['old_id'];
    type = json['type'];
    title = json['title'];
    subtitle = json['subtitle'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = _idInt;
    data['old_id'] = oldId;
    data['type'] = type;
    data['title'] = title;
    data['subtitle'] = subtitle;
    return data;
  }
}

enum FileType { folder, text, session, url, daily, app }

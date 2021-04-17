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
class FolderResponse {
  @Deprecated('Use values below')
  Data data;

  bool get hasData => data != null;

  String get title => data.title;

  String get subtitle => data.subtitle;

  String get cover => data.cover;

  String get id => data.id.toString();

  List<Item> get items => data.items.map((e) => e.item).toList();

  FolderResponse({data});

  FolderResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (data != null) {
      data['data'] = this.data.toJson();
    }
    return data;
  }
}

class Data {
  int id;
  String title;
  String subtitle;
  String cover;
  List<Items> items;

  Data({id, title, subtitle, cover, items});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    subtitle = json['subtitle'];
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
    data['subtitle'] = subtitle;
    data['cover'] = cover;
    if (items != null) {
      data['items'] = items.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Items {
  Item item;

  Items({item});

  Items.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (item != null) {
      data['item'] = item.toJson();
    }
    return data;
  }
}

class Item {
  String get id => idInt.toString();
  String oldId;
  String title;
  String subtitle;

  FileType get fileType {
    if (type == 'session') return FileType.session;
    if (type == 'article') return FileType.text;
    if (type == 'folder') return FileType.folder;
    if (type == 'url') return FileType.folder;
    return null;
  }

  @Deprecated('Use filetype instead')
  String type;
  @Deprecated('Use id instead')
  int idInt;

  Item({id, type, title, subtitle});

  Item.fromJson(Map<String, dynamic> json) {
    idInt = json['id'];
    oldId = json['old_id'];
    type = json['type'];
    title = json['title'];
    subtitle = json['subtitle'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = idInt;
    data['old_id'] = oldId;
    data['type'] = type;
    data['title'] = title;
    data['subtitle'] = subtitle;
    return data;
  }
}

enum FileType { folder, text, session, url, daily }

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


import 'package:Medito/network/folder/folder_items.dart';

class Packs {
  Data data;

  Packs({this.data});

  Packs.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data.toJson();
    }
    return data;
  }
}

class Data {
  Content content;

  Data({this.content});

  Data.fromJson(Map<String, dynamic> json) {
    content =
        json['content'] != null ? Content.fromJson(json['content']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content.toJson();
    }
    return data;
  }
}

class Content {
  List<PackItem> items;

  Content({this.items});

  Content.fromJson(Map<String, dynamic> json) {
    if (json['items'] != null) {
      items = <PackItem>[];
      json['items'].forEach((v) {
        items.add(PackItem.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (items != null) {
      data['items'] = items.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class PackItem {
  /// "folder"/"article"/"session"/"daily"
  /// Check this value on tile tap to open correct page

  FileType get fileType {
    if (itemType == 'session') return FileType.session;
    if (itemType == 'article') return FileType.text;
    if (itemType == 'folder') return FileType.folder;
    return null;
  }

  /// Used to show/hide tile
  bool display;

  /// Use these
  String get title => overrideData ? itemTitle : itemPath[0].text;

  String get subtitle => overrideData ? itemSubtitle : itemPath[0].info;

  String itemSubtitle; //use subtitle above

  ///   ItemPath.link is the link to go to the item
  List<ItemPath> itemPath; // don't use
  String get link => itemPath.first.link;

  /// ItemCover.image.url is image of card
  List<ItemCover> itemCover; // don't use
  String get imageUrl => itemCover.first.url;

  /// Tile bg color
  String colorPrimary;

  /// the text color (default if null should be #ff000000)
  String get textColor => colorSecondary ?? '#ff000000';

  /// IGNORE -----------------------------------------
  /// Ignore. Sometimes the subtitle/title will be missing, so get them from another place
  ///
  @Deprecated('Don\'t use.')
  bool overrideData;

  @Deprecated('Don\'t use. Use [title] instead')
  String itemTitle;
  @Deprecated('Don\'t use. Use [textColor] instead')
  String colorSecondary;
  @Deprecated('Use [fileType] instead')
  String itemType;

  /// END IGNORE --------------------------------------

  PackItem(
      {this.itemType,
      this.display,
      this.overrideData,
      this.itemTitle,
      this.itemSubtitle,
      this.itemPath,
      this.itemCover,
      this.colorPrimary,
      this.colorSecondary});

  PackItem.fromJson(Map<String, dynamic> json) {
    itemType = json['item_type'];
    display = json['display'];
    overrideData = json['override_data'];
    itemTitle = json['item_title'];
    itemSubtitle = json['item_subtitle'];
    if (json['item_path'] != null) {
      itemPath = <ItemPath>[];
      json['item_path'].forEach((v) {
        itemPath.add(ItemPath.fromJson(v));
      });
    }
    if (json['item_cover'] != null) {
      itemCover = <ItemCover>[];
      json['item_cover'].forEach((v) {
        itemCover.add(ItemCover.fromJson(v));
      });
    }
    colorPrimary = json['color_primary'];
    colorSecondary = json['color_secondary'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['item_type'] = itemType;
    data['display'] = display;
    data['override_data'] = overrideData;
    data['item_title'] = itemTitle;
    data['item_subtitle'] = itemSubtitle;
    if (itemPath != null) {
      data['item_path'] = itemPath.map((v) => v.toJson()).toList();
    }
    if (itemCover != null) {
      data['item_cover'] = itemCover.map((v) => v.toJson()).toList();
    }
    data['color_primary'] = colorPrimary;
    data['color_secondary'] = colorSecondary;
    return data;
  }
}

class ItemPath {
  String info;
  String link;
  String text;

  ItemPath({this.info, this.link, this.text});

  ItemPath.fromJson(Map<String, dynamic> json) {
    info = json['info'];
    link = json['link'];
    text = json['text'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['info'] = info;
    data['link'] = link;
    data['text'] = text;
    return data;
  }
}

class ItemCover {
  String url;

  ItemCover({this.url});

  ItemCover.fromJson(Map<String, dynamic> json) {
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['url'] = url;
    return data;
  }
}

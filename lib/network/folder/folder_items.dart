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

class FolderItems {
  Data data;

  FolderItems({this.data});

  FolderItems.fromJson(Map<String, dynamic> json) {
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
  FolderContent content;

  Data({this.content});

  Data.fromJson(Map<String, dynamic> json) {
    content = json['content'] != null
        ? FolderContent.fromJson(json['content'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content.toJson();
    }
    return data;
  }
}

class FolderContent {
  String subtitle;

  FolderCover get coverDetails => cover.first;
  List<FolderItem> items;
  String title;

  @Deprecated('Use coverDetails instead')
  List<FolderCover> cover;

  FolderContent({this.subtitle, this.cover, this.items, this.title});

  FolderContent.fromJson(Map<String, dynamic> json) {
    subtitle = json['subtitle'];
    if (json['cover'] != null) {
      cover = <FolderCover>[];
      json['cover'].forEach((v) {
        cover.add(FolderCover.fromJson(v)..setCoverTitle(title));
      });
    }
    if (json['items'] != null) {
      items = <FolderItem>[];
      json['items'].forEach((v) {
        items.add(FolderItem.fromJson(v));
      });
    }
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['subtitle'] = subtitle;
    if (cover != null) {
      data['cover'] = cover.map((v) => v.toJson()).toList();
    }
    if (items != null) {
      data['items'] = items.map((v) => v.toJson()).toList();
    }
    data['title'] = title;
    return data;
  }
}

class FolderCover {
  Image image;
  String coverTitle;

  String get url => image.url;

  FolderCover({this.image});

  FolderCover.fromJson(Map<String, dynamic> json) {
    image = json['image'] != null ? Image.fromJson(json['image']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (image != null) {
      data['image'] = image.toJson();
    }
    return data;
  }

  void setCoverTitle(String title) {
    coverTitle = title;
  }
}

/// DON'T USE
@Deprecated('No need to use this class')
class Image {
  String url;

  Image({this.url});

  Image.fromJson(Map<String, dynamic> json) {
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['url'] = url;
    return data;
  }
}

class FolderItem {
  bool display;

  String get title =>  itemPath.first.text;

  String get subtitle =>  itemPath.first.info;

  String get id => itemPath.first.link;

  String get link => itemPath.first.link;

  FileType get fileType {
    if (itemType == 'session') return FileType.session;
    if (itemType == 'article') return FileType.text;
    if (itemType == 'folder') return FileType.folder;
    return null;
  }

  @Deprecated('Don\'t use directly')
  List<ItemPath> itemPath;

  @Deprecated('Don\'t use. Use [subtitle] instead')
  String itemSubtitle;

  @Deprecated('Don\'t use. Use [title] instead')
  String itemTitle;

  @Deprecated('Don\'t use. Use [fileType] instead')
  String itemType;

  FolderItem(
      {this.itemType,
      this.display,
      this.itemTitle,
      this.itemSubtitle,
      this.itemPath});

  FolderItem.fromJson(Map<String, dynamic> json) {
    itemType = json['item_type'];
    display = json['display'];
    itemTitle = json['item_title'];
    itemSubtitle = json['item_subtitle'];
    if (json['item_path'] != null) {
      itemPath = <ItemPath>[];
      json['item_path'].forEach((v) {
        itemPath.add(ItemPath.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['item_type'] = itemType;
    data['display'] = display;
    data['item_title'] = itemTitle;
    data['item_subtitle'] = itemSubtitle;
    if (itemPath != null) {
      data['item_path'] = itemPath.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ItemPath {
  String link;
  String info;
  String text;
  String url;

  ItemPath({link, info, text, url});

  ItemPath.fromJson(Map<String, dynamic> json) {
    link = json['link'];
    info = json['info'];
    text = json['text'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['link'] = link;
    data['info'] = info;
    data['text'] = text;
    data['url'] = url;
    return data;
  }
}

enum FileType { folder, text, session, url }

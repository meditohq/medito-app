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
import 'attributions_content.dart';

class Attributions {
  int code;
  Data data;
  String status;
  String type;

  Attributions({this.code, this.data, this.status, this.type});

  Attributions.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    status = json['status'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['code'] = code;
    if (this.data != null) {
      data['data'] = this.data.toJson();
    }
    data['status'] = status;
    data['type'] = type;
    return data;
  }
}

class Data {
  Content content;
  String id;
  int num;
  Options options;
  Parent parent;
  String slug;
  String status;
  String template;
  String title;
  String url;

  Data(
      {this.content,
        this.id,
        this.num,
        this.options,
        this.parent,
        this.slug,
        this.status,
        this.template,
        this.title,
        this.url});

  Data.fromJson(Map<String, dynamic> json) {
    content =
    json['content'] != null ? Content.fromJson(json['content']) : null;
    id = json['id'];
    num = json['num'];
    options =
    json['options'] != null ? Options.fromJson(json['options']) : null;
    parent =
    json['parent'] != null ? Parent.fromJson(json['parent']) : null;
    slug = json['slug'];
    status = json['status'];
    template = json['template'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content.toJson();
    }
    data['id'] = id;
    data['num'] = num;
    if (options != null) {
      data['options'] = options.toJson();
    }
    if (parent != null) {
      data['parent'] = parent.toJson();
    }
    data['slug'] = slug;
    data['status'] = status;
    data['template'] = template;
    data['title'] = title;
    data['url'] = url;
    return data;
  }
}

class Options {
  bool changeSlug;
  bool changeStatus;
  bool changeTemplate;
  bool changeTitle;
  bool create;
  bool delete;
  bool duplicate;
  bool read;
  bool preview;
  bool sort;
  bool update;

  Options(
      {this.changeSlug,
        this.changeStatus,
        this.changeTemplate,
        this.changeTitle,
        this.create,
        this.delete,
        this.duplicate,
        this.read,
        this.preview,
        this.sort,
        this.update});

  Options.fromJson(Map<String, dynamic> json) {
    changeSlug = json['changeSlug'];
    changeStatus = json['changeStatus'];
    changeTemplate = json['changeTemplate'];
    changeTitle = json['changeTitle'];
    create = json['create'];
    delete = json['delete'];
    duplicate = json['duplicate'];
    read = json['read'];
    preview = json['preview'];
    sort = json['sort'];
    update = json['update'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['changeSlug'] = changeSlug;
    data['changeStatus'] = this.changeStatus;
    data['changeTemplate'] = this.changeTemplate;
    data['changeTitle'] = this.changeTitle;
    data['create'] = this.create;
    data['delete'] = this.delete;
    data['duplicate'] = this.duplicate;
    data['read'] = this.read;
    data['preview'] = this.preview;
    data['sort'] = this.sort;
    data['update'] = this.update;
    return data;
  }
}

class Parent {
  Null colorBackground;
  Null colorDark;
  Null colorLight;
  Null contentText;
  Null description;
  String id;
  Null illustrationUrl;
  Null num;
  String template;
  String title;
  String url;

  Parent(
      {this.colorBackground,
        this.colorDark,
        this.colorLight,
        this.contentText,
        this.description,
        this.id,
        this.illustrationUrl,
        this.num,
        this.template,
        this.title,
        this.url});

  Parent.fromJson(Map<String, dynamic> json) {
    colorBackground = json['color_background'];
    colorDark = json['color_dark'];
    colorLight = json['color_light'];
    contentText = json['contentText'];
    description = json['description'];
    id = json['id'];
    illustrationUrl = json['illustrationUrl'];
    num = json['num'];
    template = json['template'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['color_background'] = colorBackground;
    data['color_dark'] = colorDark;
    data['color_light'] = colorLight;
    data['contentText'] = contentText;
    data['description'] = description;
    data['id'] = id;
    data['illustrationUrl'] = illustrationUrl;
    data['num'] = num;
    data['template'] = template;
    data['title'] = title;
    data['url'] = url;
    return data;
  }
}

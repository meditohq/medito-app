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
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
    status = json['status'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    if (this.data != null) {
      data['data'] = this.data.toJson();
    }
    data['status'] = this.status;
    data['type'] = this.type;
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
    json['content'] != null ? new Content.fromJson(json['content']) : null;
    id = json['id'];
    num = json['num'];
    options =
    json['options'] != null ? new Options.fromJson(json['options']) : null;
    parent =
    json['parent'] != null ? new Parent.fromJson(json['parent']) : null;
    slug = json['slug'];
    status = json['status'];
    template = json['template'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.content != null) {
      data['content'] = this.content.toJson();
    }
    data['id'] = this.id;
    data['num'] = this.num;
    if (this.options != null) {
      data['options'] = this.options.toJson();
    }
    if (this.parent != null) {
      data['parent'] = this.parent.toJson();
    }
    data['slug'] = this.slug;
    data['status'] = this.status;
    data['template'] = this.template;
    data['title'] = this.title;
    data['url'] = this.url;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['changeSlug'] = this.changeSlug;
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
    data['color_background'] = this.colorBackground;
    data['color_dark'] = this.colorDark;
    data['color_light'] = this.colorLight;
    data['contentText'] = this.contentText;
    data['description'] = this.description;
    data['id'] = this.id;
    data['illustrationUrl'] = this.illustrationUrl;
    data['num'] = this.num;
    data['template'] = this.template;
    data['title'] = this.title;
    data['url'] = this.url;
    return data;
  }
}

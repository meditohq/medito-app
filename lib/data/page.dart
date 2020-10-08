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
class Pages {
  int code;
  Data data;
  String status;
  String type;

  Pages({this.code, this.data, this.status, this.type});

  Pages.fromJson(Map<String, dynamic> json) {
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

class Content {
  String description;
  String subtitle;
  String body;
  List<Illustration> illustration;
  String primaryColor;
  String secondaryColor;
  List<Files> files;
  String title;
  bool backgroundMusic;
  String date;
  String customLength;

  Content(
      {this.description,
      this.body,
      this.subtitle,
      this.illustration,
      this.primaryColor,
      this.files,
      this.title,
      this.backgroundMusic,
      this.date,
      this.customLength});

  Content.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    subtitle = json['subtitle'];
    body = json['body'];
    if (json['illustration'] != null) {
      illustration = new List<Illustration>();
      json['illustration'].forEach((v) {
        illustration.add(new Illustration.fromJson(v));
      });
    }
    backgroundMusic = json['service_backgroundmusic'];
    primaryColor = json['color_primary'];
    if (json['files'] != null) {
      files = new List<Files>();
      json['files'].forEach((v) {
        files.add(new Files.fromJson(v));
      });
    }
    title = json['title'];
    date = json['date'];
    customLength = json['customlength'];
    secondaryColor = json['color_secondary'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['description'] = this.description;
    data['subtitle'] = this.subtitle;
    data['body'] = this.body;
    if (this.illustration != null) {
      data['illustration'] = this.illustration.map((v) => v.toJson()).toList();
    }
    data['service_backgroundmusic'] = this.backgroundMusic;
    data['color_primary'] = this.primaryColor;
    if (this.files != null) {
      data['files'] = this.files.map((v) => v.toJson()).toList();
    }
    data['title'] = this.title;
    data['date'] = this.date;
    data['customlength'] = this.customLength;
    data['color_secondary'] = this.secondaryColor;
    return data;
  }
}

class Illustration {
  String filename;
  String id;
  String info;
  String link;
  String text;
  String type;
  String url;
  String uuid;
  String voice;
  String length;
  String attributions;

  Illustration(
      {this.filename,
      this.id,
      this.info,
      this.link,
      this.text,
      this.type,
      this.url,
      this.uuid,
      this.voice,
      this.length,
      this.attributions});

  Illustration.fromJson(Map<String, dynamic> json) {
    filename = json['filename'];
    id = json['id'];
    info = json['info'];
    link = json['link'];
    text = json['text'];
    type = json['type'];
    url = json['url'];
    uuid = json['uuid'];
    voice = json['voice'];
    length = json['length'];
    attributions = json['attributions'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['filename'] = this.filename;
    data['id'] = this.id;
    data['info'] = this.info;
    data['link'] = this.link;
    data['text'] = this.text;
    data['type'] = this.type;
    data['url'] = this.url;
    data['uuid'] = this.uuid;
    data['voice'] = this.voice;
    data['length'] = this.length;
    data['attributions'] = this.attributions;
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
  String colorBackground;
  String colorDark;
  String colorLight;
  Null contentText;
  String description;
  String id;
  Null illustrationUrl;
  int num;
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
    colorBackground = json['colorBackground'];
    colorDark = json['colorDark'];
    colorLight = json['colorLight'];
    contentText = json['content_text'];
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
    data['colorBackground'] = this.colorBackground;
    data['colorDark'] = this.colorDark;
    data['colorLight'] = this.colorLight;
    data['content_text'] = this.contentText;
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

class Files {
  String filename;
  String id;
  String info;
  String link;
  String text;
  String type;
  String url;
  String uuid;
  String voice;
  String length;
  String attributions;

  Files(
      {this.filename,
      this.id,
      this.info,
      this.link,
      this.text,
      this.type,
      this.url,
      this.uuid,
      this.voice,
      this.length,
      this.attributions});

  Files.fromJson(Map<String, dynamic> json) {
    filename = json['filename'];
    id = json['id'];
    info = json['info'];
    link = json['link'];
    text = json['text'];
    type = json['type'];
    url = json['url'];
    uuid = json['uuid'];
    voice = json['voice'];
    length = json['length'];
    attributions = json['attributions'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['filename'] = this.filename;
    data['id'] = this.id;
    data['info'] = this.info;
    data['link'] = this.link;
    data['text'] = this.text;
    data['type'] = this.type;
    data['url'] = this.url;
    data['uuid'] = this.uuid;
    data['voice'] = this.voice;
    data['length'] = this.length;
    data['attributions'] = this.attributions;
    return data;
  }
}

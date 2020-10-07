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
class PagesChildren {
  int code;
  List<DataChildren> data;
  Pagination pagination;
  String status;
  String type;

  PagesChildren(
      {this.code, this.data, this.pagination, this.status, this.type});

  PagesChildren.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    if (json['data'] != null) {
      data = new List<DataChildren>();
      json['data'].forEach((v) {
        data.add(new DataChildren.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? new Pagination.fromJson(json['pagination'])
        : null;
    status = json['status'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    if (this.data != null) {
      data['data'] = this.data.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination.toJson();
    }
    data['status'] = this.status;
    data['type'] = this.type;
    return data;
  }
}

class DataChildren {
  String buttonLabel;
  String pathTemplate;
  String primaryColor;
  String secondaryColor;
  String description;
  String contentPath;
  String subtitle;
  String body;
  String id;
  String illustrationUrl;
  int num;
  String template;
  String title;
  String url;
  Content content;

  DataChildren(
      {this.buttonLabel,
      this.primaryColor,
      this.secondaryColor,
      this.description,
      this.contentPath,
      this.subtitle,
      this.body,
      this.id,
      this.content,
      this.pathTemplate,
      this.illustrationUrl,
      this.num,
      this.template,
      this.title,
      this.url});

  DataChildren.fromJson(Map<String, dynamic> json) {
    buttonLabel = json['buttonLabel'];
    primaryColor = json['color_primary'];
    secondaryColor = json['color_secondary'];
    body = json['body'];
    description = json['description'];
    contentPath = json['contentPath'];
    subtitle = json['subtitle'];
    id = json['id'];
    content =
        json['content'] != null ? new Content.fromJson(json['content']) : null;
    illustrationUrl = json['illustrationUrl'];
    num = json['num'];
    pathTemplate = json['pathTemplate'];
    template = json['template'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['buttonLabel'] = this.buttonLabel;
    data['color_primary'] = this.primaryColor;
    data['color_secondary'] = this.secondaryColor;
    data['description'] = this.description;
    data['contentPath'] = this.contentPath;
    data['subtitle'] = this.subtitle;
    data['id'] = this.id;
    data['content'] = this.content;
    data['body'] = this.body;
    data['illustrationUrl'] = this.illustrationUrl;
    data['num'] = this.num;
    data['template'] = this.template;
    data['pathTemplate'] = this.pathTemplate;
    data['title'] = this.title;
    data['url'] = this.url;
    return data;
  }
}

class Pagination {
  int page;
  int total;
  int offset;
  int limit;

  Pagination({this.page, this.total, this.offset, this.limit});

  Pagination.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    total = json['total'];
    offset = json['offset'];
    limit = json['limit'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['page'] = this.page;
    data['total'] = this.total;
    data['offset'] = this.offset;
    data['limit'] = this.limit;
    return data;
  }
}

class Content {
  String description;
  String contentText;
  String primaryColor;
  String textColor;
  String title;
  String date;
  String customlength;

  Content(
      {this.description,
      this.contentText,
      this.primaryColor,
      this.title,
      this.date,
      this.customlength});

  Content.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    contentText = json['content_text'];
    primaryColor = json['primary_color'];
    title = json['title'];
    date = json['date'];
    customlength = json['customlength'];
    textColor = json['color_secondary'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['description'] = this.description;
    data['content_text'] = this.contentText;
    data['color_primary'] = this.primaryColor;
    data['title'] = this.title;
    data['date'] = this.date;
    data['customlength'] = this.customlength;
    data['color_secondary'] = this.textColor;
    return data;
  }
}

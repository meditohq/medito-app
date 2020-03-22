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
  String colorBackground;
  String colorDark;
  String colorLight;
  String contentText;
  String description;
  String id;
  String illustrationUrl;
  int num;
  String template;
  String title;
  String url;

  DataChildren(
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

  DataChildren.fromJson(Map<String, dynamic> json) {
    colorBackground = json['colorBackground'];
    colorDark = json['colorDark'];
    colorLight = json['colorLight'];
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
    data['colorBackground'] = this.colorBackground;
    data['colorDark'] = this.colorDark;
    data['colorLight'] = this.colorLight;
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

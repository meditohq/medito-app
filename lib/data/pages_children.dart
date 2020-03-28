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
  String contentText;
  String contentPath;
  String description;
  String id;
  String illustrationUrl;
  int num;
  String template;
  String title;
  String url;

  DataChildren(
      {
        this.buttonLabel,
        this.primaryColor,
        this.secondaryColor,
        this.contentText,
        this.contentPath,
        this.description,
        this.id,
        this.pathTemplate,
        this.illustrationUrl,
        this.num,
        this.template,
        this.title,
        this.url});

  DataChildren.fromJson(Map<String, dynamic> json) {
    buttonLabel = json['buttonLabel'];
    primaryColor = json['primaryColor'];
    secondaryColor = json['secondaryColor'];
    contentText = json['contentText'];
    contentPath = json['contentPath'];
    description = json['description'];
    id = json['id'];
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
    data['primaryColor'] = this.primaryColor;
    data['secondaryColor'] = this.secondaryColor;
    data['contentText'] = this.contentText;
    data['contentPath'] = this.contentPath;
    data['description'] = this.description;
    data['id'] = this.id;
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

class Pages {
  int code;
  List<Data> data;
  Pagination pagination;
  String status;
  String type;

  Pages({this.code, this.data, this.pagination, this.status, this.type});

  Pages.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    if (json['data'] != null) {
      data = new List<Data>();
      json['data'].forEach((v) {
        data.add(new Data.fromJson(v));
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

class Data {
  String description;
  String contentText;
  String id;
  int num;
  String template;
  int timeCreated;
  String title;
  String url;
  bool hasFiles;

  Data(
      {this.description,
        this.contentText,
        this.id,
        this.num,
        this.template,
        this.timeCreated,
        this.title,
        this.url, this.hasFiles});

  Data.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    contentText = json['contentText'];
    id = json['id'];
    num = json['num'];
    template = json['template'];
    timeCreated = json['timeCreated'];
    title = json['title'];
    url = json['url'];
    hasFiles = json['hasFiles'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['description'] = this.description;
    data['contentText'] = this.contentText;
    data['id'] = this.id;
    data['num'] = this.num;
    data['template'] = this.template;
    data['timeCreated'] = this.timeCreated;
    data['title'] = this.title;
    data['url'] = this.url;
    data['hasFiles'] = this.hasFiles;
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

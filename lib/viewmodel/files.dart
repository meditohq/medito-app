import 'files_data.dart';

class Files {
  int code;
  List<Data> data;
  Pagination pagination;
  String status;
  String type;

  Files({this.code, this.data, this.pagination, this.status, this.type});

  Files.fromJson(Map<String, dynamic> json) {
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

class Content {
  String alt;

  Content({this.alt});

  Content.fromJson(Map<String, dynamic> json) {
    alt = json['alt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['alt'] = this.alt;
    return data;
  }
}

class Dimensions {
  int width;
  int height;
  int ratio;
  bool orientation;

  Dimensions({this.width, this.height, this.ratio, this.orientation});

  Dimensions.fromJson(Map<String, dynamic> json) {
    width = json['width'];
    height = json['height'];
    ratio = json['ratio'];
    orientation = json['orientation'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['width'] = this.width;
    data['height'] = this.height;
    data['ratio'] = this.ratio;
    data['orientation'] = this.orientation;
    return data;
  }
}

class Options {
  bool changeName;
  bool create;
  bool delete;
  bool replace;
  bool update;

  Options(
      {this.changeName, this.create, this.delete, this.replace, this.update});

  Options.fromJson(Map<String, dynamic> json) {
    changeName = json['changeName'];
    create = json['create'];
    delete = json['delete'];
    replace = json['replace'];
    update = json['update'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['changeName'] = this.changeName;
    data['create'] = this.create;
    data['delete'] = this.delete;
    data['replace'] = this.replace;
    data['update'] = this.update;
    return data;
  }
}

class Parent {
  String description;
  String id;
  int num;
  String template;
  String timeCreated;
  String title;
  String url;

  Parent(
      {this.description,
        this.id,
        this.num,
        this.template,
        this.timeCreated,
        this.title,
        this.url});

  Parent.fromJson(Map<String, dynamic> json) {
    description = json['description'];
    id = json['id'];
    num = json['num'];
    template = json['template'];
    timeCreated = json['timeCreated'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['description'] = this.description;
    data['id'] = this.id;
    data['num'] = this.num;
    data['template'] = this.template;
    data['timeCreated'] = this.timeCreated;
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

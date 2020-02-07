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

class Data {
  Content content;
  Dimensions dimensions;
  bool exists;
  String extension;
  String filename;
  String id;
  String link;
  String mime;
  String modified;
  Object name;
  Object next;
  String niceSize;
  Options options;
  Parent parent;
  Object prev;
  int size;
  Object template;
  String type;
  String url;

  Data(
      {this.content,
        this.dimensions,
        this.exists,
        this.extension,
        this.filename,
        this.id,
        this.link,
        this.mime,
        this.modified,
        this.name,
        this.next,
        this.niceSize,
        this.options,
        this.parent,
        this.prev,
        this.size,
        this.template,
        this.type,
        this.url});

  Data.fromJson(Map<String, dynamic> json) {
    content =
    json['content'] != null ? new Content.fromJson(json['content']) : null;
    dimensions = json['dimensions'] != null
        ? new Dimensions.fromJson(json['dimensions'])
        : null;
    exists = json['exists'];
    extension = json['extension'];
    filename = json['filename'];
    id = json['id'];
    link = json['link'];
    mime = json['mime'];
    modified = json['modified'];
    name = json['name'];
    next = json['next'];
    niceSize = json['niceSize'];
    options =
    json['options'] != null ? new Options.fromJson(json['options']) : null;
    parent =
    json['parent'] != null ? new Parent.fromJson(json['parent']) : null;
    prev = json['prev'];
    size = json['size'];
    template = json['template'];
    type = json['type'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.content != null) {
      data['content'] = this.content.toJson();
    }
    if (this.dimensions != null) {
      data['dimensions'] = this.dimensions.toJson();
    }
    data['exists'] = this.exists;
    data['extension'] = this.extension;
    data['filename'] = this.filename;
    data['id'] = this.id;
    data['link'] = this.link;
    data['mime'] = this.mime;
    data['modified'] = this.modified;
    data['name'] = this.name;
    data['next'] = this.next;
    data['niceSize'] = this.niceSize;
    if (this.options != null) {
      data['options'] = this.options.toJson();
    }
    if (this.parent != null) {
      data['parent'] = this.parent.toJson();
    }
    data['prev'] = this.prev;
    data['size'] = this.size;
    data['template'] = this.template;
    data['type'] = this.type;
    data['url'] = this.url;
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

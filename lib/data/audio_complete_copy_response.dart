class AudioCompleteCopyResponse {
  int code;
  Data data;
  String status;
  String type;

  AudioCompleteCopyResponse({this.code, this.data, this.status, this.type});

  AudioCompleteCopyResponse.fromJson(Map<String, dynamic> json) {
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
  Null num;
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
  List<Versions> versions;
  String title;

  Content({this.versions, this.title});

  Content.fromJson(Map<String, dynamic> json) {
    if (json['versions'] != null) {
      versions = new List<Versions>();
      json['versions'].forEach((v) {
        versions.add(new Versions.fromJson(v));
      });
    }
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.versions != null) {
      data['versions'] = this.versions.map((v) => v.toJson()).toList();
    }
    data['title'] = this.title;
    return data;
  }
}

class Versions {
  int version;
  bool active;
  String title;
  String subtitle;
  String buttonIcon;
  String buttonLabel;
  String buttonDestination;

  Versions(
      {this.version,
        this.active,
        this.title,
        this.subtitle,
        this.buttonIcon,
        this.buttonLabel,
        this.buttonDestination});

  Versions.fromJson(Map<String, dynamic> json) {
    version = json['version'];
    active = json['active'];
    title = json['title'];
    subtitle = json['subtitle'];
    buttonIcon = json['button_icon'];
    buttonLabel = json['button_label'];
    buttonDestination = json['button_destination'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['version'] = this.version;
    data['active'] = this.active;
    data['title'] = this.title;
    data['subtitle'] = this.subtitle;
    data['button_icon'] = this.buttonIcon;
    data['button_label'] = this.buttonLabel;
    data['button_destination'] = this.buttonDestination;
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
  Null buttonLabel;
  Null contentPath;
  Null contentText;
  Null description;
  String id;
  Null illustrationUrl;
  Null num;
  Null pathTemplate;
  Null primaryColor;
  Null secondaryColor;
  String template;
  String title;
  String url;

  Parent(
      {this.buttonLabel,
        this.contentPath,
        this.contentText,
        this.description,
        this.id,
        this.illustrationUrl,
        this.num,
        this.pathTemplate,
        this.primaryColor,
        this.secondaryColor,
        this.template,
        this.title,
        this.url});

  Parent.fromJson(Map<String, dynamic> json) {
    buttonLabel = json['buttonLabel'];
    contentPath = json['contentPath'];
    contentText = json['contentText'];
    description = json['description'];
    id = json['id'];
    illustrationUrl = json['illustrationUrl'];
    num = json['num'];
    pathTemplate = json['pathTemplate'];
    primaryColor = json['primaryColor'];
    secondaryColor = json['secondaryColor'];
    template = json['template'];
    title = json['title'];
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['buttonLabel'] = this.buttonLabel;
    data['contentPath'] = this.contentPath;
    data['contentText'] = this.contentText;
    data['description'] = this.description;
    data['id'] = this.id;
    data['illustrationUrl'] = this.illustrationUrl;
    data['num'] = this.num;
    data['pathTemplate'] = this.pathTemplate;
    data['primaryColor'] = this.primaryColor;
    data['secondaryColor'] = this.secondaryColor;
    data['template'] = this.template;
    data['title'] = this.title;
    data['url'] = this.url;
    return data;
  }
}

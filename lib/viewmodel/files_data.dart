
import 'files.dart';

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

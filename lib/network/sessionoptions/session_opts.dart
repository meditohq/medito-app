class SessionOpts {

  String get title => data.content.title;
  String get author => data.content.author;
  String get description => data.content.description;
  String get coverUrl => data.content.cover.first.url;
  String get colorPrimary => data.content.colorPrimary;
  String get colorSecondary => data.content.colorSecondary;
  List<AudioFile> get files => data.content.files;
  bool get hasBackgroundMusic => data.content.backgroundSound;

  @Deprecated('Don\'t use')
  Data _data;

  Data get data => _data;

  SessionOpts({
      Data data}){
    _data = data;
}

  SessionOpts.fromJson(dynamic json) {
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    if (_data != null) {
      map['data'] = _data.toJson();
    }
    return map;
  }

}

class Data {
  Content _content;

  Content get content => _content;

  Data({
      Content content}){
    _content = content;
}

  Data.fromJson(dynamic json) {
    _content = json['content'] != null ? Content.fromJson(json['content']) : null;
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    if (_content != null) {
      map['content'] = _content.toJson();
    }
    return map;
  }

}

class Content {
  String _description;
  List<Cover> _cover;
  String _colorPrimary;
  String _colorSecondary;
  List<AudioFile> _files;
  bool _backgroundSound;
  String _title;
  String _author;

  String get description => _description;
  List<Cover> get cover => _cover;
  String get colorPrimary => _colorPrimary;
  String get colorSecondary => _colorSecondary;
  List<AudioFile> get files => _files;
  bool get backgroundSound => _backgroundSound;
  String get title => _title;
  String get author => _author;

  Content({
      String description, 
      List<Cover> cover, 
      String colorPrimary, 
      String colorSecondary, 
      List<AudioFile> files, 
      bool backgroundSound,
      String title, String author}){
    _description = description;
    _cover = cover;
    _colorPrimary = colorPrimary;
    _colorSecondary = colorSecondary;
    _files = files;
    _backgroundSound = backgroundSound;
    _title = title;
    _author = author;
}

  Content.fromJson(dynamic json) {
    _description = json['description'];
    if (json['cover'] != null) {
      _cover = [];
      json['cover'].forEach((v) {
        _cover.add(Cover.fromJson(v));
      });
    }
    _colorPrimary = json['color_primary'];
    _colorSecondary = json['color_secondary'];
    if (json['files'] != null) {
      _files = [];
      json['files'].forEach((v) {
        _files.add(AudioFile.fromJson(v));
      });
    }
    _backgroundSound = json['background_sound'];
    _title = json['title'];
    _author = json['author'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['description'] = _description;
    if (_cover != null) {
      map['cover'] = _cover.map((v) => v.toJson()).toList();
    }
    map['color_primary'] = _colorPrimary;
    map['color_secondary'] = _colorSecondary;
    if (_files != null) {
      map['files'] = _files.map((v) => v.toJson()).toList();
    }
    map['background_sound'] = _backgroundSound;
    map['title'] = _title;
    map['author'] = _author;
    return map;
  }

}

class AudioFile {
  String _info;
  String _url;

  String get voice => info.split(',')[0];
  String get length => info.split(',')[1];
  String get url => _url;

  @Deprecated('Use [voice] and [length]')
  String get info => _info;

  AudioFile({
      String info, 
      String url}){
    _info = info;
    _url = url;
}

  AudioFile.fromJson(dynamic json) {
    _info = json['info'];
    _url = json['url'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['info'] = _info;
    map['url'] = _url;
    return map;
  }

}

class Cover {
  String _url;

  String get url => _url;

  Cover({
      String url}){
    _url = url;
}

  Cover.fromJson(dynamic json) {
    _url = json['url'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['url'] = _url;
    return map;
  }

}
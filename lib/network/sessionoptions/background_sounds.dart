class BackgroundSounds {
  int _code;
  List<Data> _data;

  BackgroundSounds({int code, List<Data> data}) {
    _code = code;
    _data = data;
  }

  int get code => _code;

  set code(int code) => _code = code;

  List<Data> get list => _data;

  set data(List<Data> data) => _data = data;

  BackgroundSounds.fromJson(Map<String, dynamic> json) {
    _code = json['code'];
    if (json['data'] != null) {
      _data = <Data>[];
      json['data'].forEach((v) {
        _data.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['code'] = _code;
    if (_data != null) {
      data['data'] = _data.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  Content _content;
  String _url;

  Data({Content content, String url}) {
    _content = content;
    _url = url;
  }

  set content(Content content) => _content = content;
  set url(String url) => _url = url;

  String get name => _content.title;
  String get url => _url;

  Data.fromJson(Map<String, dynamic> json) {
    _content =
        json['content'] != null ? Content.fromJson(json['content']) : null;
    _url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (_content != null) {
      data['content'] = _content.toJson();
    }
    data['url'] = _url;
    return data;
  }
}

class Content {
  String _title;

  Content({String title}) {
    _title = title;
  }

  String get title => _title;

  set title(String title) => _title = title;

  Content.fromJson(Map<String, dynamic> json) {
    _title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = _title;
    return data;
  }
}

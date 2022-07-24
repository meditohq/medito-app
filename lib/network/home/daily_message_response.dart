class DailyMessageResponse {

  Data? _data;

  String? get title => _data?.title ?? '';

  String? get body => _data?.body ?? '';

  DailyMessageResponse(this._data);

  DailyMessageResponse.fromJson(Map<String, dynamic> json) {
    _data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (_data != null) {
      data['data'] = _data?.toJson();
    }
    return data;
  }

}

class Data {
  String? title;
  String? body;

  Data({this.title, this.body});

  Data.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    body = json['body'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['title'] = title;
    data['body'] = body;
    return data;
  }
}

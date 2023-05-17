// ignore_for_file: avoid-dynamic

class UserResponse {
  Data? data;

  UserResponse({this.data});

  UserResponse.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    var mainData = this.data;
    if (mainData != null) {
      data['data'] = mainData.toJson();
    }

    return data;
  }
}

class Data {
  String? id;

  Data({this.id});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;

    return data;
  }
}

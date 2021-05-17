class BackgroundSoundsResponse {
  List<BackgroundSoundData> data;

  BackgroundSoundsResponse({this.data});

  BackgroundSoundsResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <BackgroundSoundData>[];
      json['data']?.forEach((v) {
        data.add(BackgroundSoundData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (data != null) {
      data['data'] = this.data.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class BackgroundSoundData {
  int id;
  String name;
  String file;
  int sort;

  BackgroundSoundData({this.id, this.name, this.file, this.sort});

  BackgroundSoundData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    file = json['file'];
    sort = json['sort'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['file'] = file;
    data['sort'] = sort;
    return data;
  }
}
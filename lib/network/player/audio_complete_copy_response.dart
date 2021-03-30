class PlayerCopyResponse {
  List<PlayerCopyData> data;

  PlayerCopyResponse({data});

  PlayerCopyResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <PlayerCopyData>[];
      json['data'].forEach((v) {
        data.add(PlayerCopyData.fromJson(v));
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

class PlayerCopyData {
  int id;
  String body;
  String buttonIcon;
  String buttonLabel;
  String buttonType;
  String buttonPath;
  String title;

  PlayerCopyData(
      {id,
        body,
        buttonIcon,
        buttonLabel,
        buttonType,
        buttonPath,
        title});

  PlayerCopyData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    body = json['body'];
    buttonIcon = json['button_icon'];
    buttonLabel = json['button_label'];
    buttonType = json['button_type'];
    buttonPath = json['button_path'];
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['body'] = body;
    data['button_icon'] = buttonIcon;
    data['button_label'] = buttonLabel;
    data['button_type'] = buttonType;
    data['button_path'] = buttonPath;
    data['title'] = title;
    return data;
  }
}
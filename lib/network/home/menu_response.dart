class MenuResponse {
  List<MenuData> data;

  MenuResponse({this.data});

  MenuResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <MenuData>[];
      json['data'].forEach((v) {
        data.add(MenuData.fromJson(v));
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

class MenuData {
  String itemLabel;
  String itemType;
  String itemPath;

  MenuData({itemLabel, itemType, itemPath});

  MenuData.fromJson(Map<String, dynamic> json) {
    itemLabel = json['item_label'];
    itemType = json['item_type'];
    itemPath = json['item_path'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['item_label'] = itemLabel;
    data['item_type'] = itemType;
    data['item_path'] = itemPath;
    return data;
  }
}

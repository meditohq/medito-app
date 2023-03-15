import 'package:equatable/equatable.dart';
// ignore_for_file: avoid-dynamic

class MenuResponse extends Equatable {
  final List<MenuData>? data;

  MenuResponse({this.data});

  factory MenuResponse.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      var _data = <MenuData>[];
      json['data'].forEach((v) {
        _data.add(MenuData.fromJson(v));
      });
      return MenuResponse(data: _data);
    }
    return MenuResponse(data: []);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['data'] = this.data?.map((v) => v.toJson()).toList();
    return data;
  }

  @override
  List<Object?> get props => [data];
}

class MenuData extends Equatable {
  final String? itemLabel;
  final String? itemType;
  final String itemPath;

  MenuData({this.itemLabel, this.itemType, this.itemPath = ''});

  factory MenuData.fromJson(Map<String, dynamic> json) {
    var _itemLabel = json['item_label'];
    var _itemType = json['item_type'];
    var _itemPath = json['item_path'];
    return MenuData(itemLabel: _itemLabel, itemType: _itemType, itemPath: _itemPath);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['item_label'] = itemLabel;
    data['item_type'] = itemType;
    data['item_path'] = itemPath;
    return data;
  }

  @override
  List<Object?> get props => [itemLabel, itemType, itemPath];
}

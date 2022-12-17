// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_folder_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_NewFolderResponse _$$_NewFolderResponseFromJson(Map<String, dynamic> json) =>
    _$_NewFolderResponse(
      data: json['data'] == null
          ? null
          : Data.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_NewFolderResponseToJson(
        _$_NewFolderResponse instance) =>
    <String, dynamic>{
      'data': instance.data,
    };

_$_Data _$$_DataFromJson(Map<String, dynamic> json) => _$_Data(
      id: json['id'] as int?,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => FolderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_DataToJson(_$_Data instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'description': instance.description,
      'items': instance.items,
    };

_$_FolderItem _$$_FolderItemFromJson(Map<String, dynamic> json) =>
    _$_FolderItem(
      item: json['item'] == null
          ? null
          : Item.fromJson(json['item'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$_FolderItemToJson(_$_FolderItem instance) =>
    <String, dynamic>{
      'item': instance.item,
    };

_$_Item _$$_ItemFromJson(Map<String, dynamic> json) => _$_Item(
      id: json['id'] as int?,
      type: json['type'] as String?,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
    );

Map<String, dynamic> _$$_ItemToJson(_$_Item instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'subtitle': instance.subtitle,
    };

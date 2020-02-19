import 'package:Medito/viewmodel/pages_data.dart';

import '../utils.dart';

class Pages {
  int code;
  List<Data> data;
  Pagination pagination;
  String status;
  String type;

  Pages({this.code, this.data, this.pagination, this.status, this.type});

  Pages.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    if (json['data'] != null) {
      data = new List<Data>();
      json['data'].forEach((v) {
        data.add(new Data.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? new Pagination.fromJson(json['pagination'])
        : null;
    status = json['status'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() => {
        '\"code\"': this.code,
        '\"data\"': this.data?.map((v) => v.toJson())?.toList(),
        '\"pagination\"': this.pagination?.toJson(),
        '\"status\"': "\"" + blankIfNull(this.status) + "\"",
        '\"type\"': "\"" + blankIfNull(this.type) + "\"",
      };
}

class Pagination {
  int page;
  int total;
  int offset;
  int limit;

  Pagination({this.page, this.total, this.offset, this.limit});

  Pagination.fromJson(Map<String, dynamic> json) {
    page = json['page'];
    total = json['total'];
    offset = json['offset'];
    limit = json['limit'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['\"page\"'] = this.page;
    data['\"total\"'] = this.total;
    data['\"offset\"'] = this.offset;
    data['\"limit\"'] = this.limit;
    return data;
  }
}

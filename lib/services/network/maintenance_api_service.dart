import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medito/constants/constants.dart';

class MaintenanceApiService {
  static final MaintenanceApiService _instance =
      MaintenanceApiService._internal();
  final _client = http.Client();
  final String _baseUrl;

  factory MaintenanceApiService() {
    return _instance;
  }

  MaintenanceApiService._internal() : _baseUrl = HTTPConstants.maintenance;

  Future<Map<String, Object?>?> getRequest() async {
    var url = Uri.parse(_baseUrl);
    final response = await _client.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, Object?>;
    }

    return null;
  }

  void dispose() {
    _client.close();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? token;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConfig.apiBase);
    final resolved = base.resolve(path);
    if (query == null || query.isEmpty) return resolved;
    return resolved.replace(queryParameters: {
      for (final e in query.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    });
  }

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers()).timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _client
        .post(_uri(path), headers: _headers(json: true), body: jsonEncode(body ?? <String, dynamic>{}))
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException('Сервердан нотўғри жавоб келди.', statusCode: response.statusCode);
    }
    if (payload is! Map) {
      throw ApiException('Сервер жавоби нотўғри.', statusCode: response.statusCode);
    }
    final map = Map<String, dynamic>.from(payload as Map);
    if (response.statusCode >= 200 && response.statusCode < 300 && map['ok'] == true) {
      return map['data'];
    }
    final error = map['error'];
    String message = 'Сўров бажарилмади.';
    if (error is Map && error['message'] != null) message = '${error['message']}';
    throw ApiException(message, statusCode: response.statusCode);
  }

  void close() => _client.close();
}

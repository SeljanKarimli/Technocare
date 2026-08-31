import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'secure_session.dart';

class ApiClient {
  final http.Client _http;
  final SecureSession _session;
  final Uri _baseUri;

  ApiClient({
    required SecureSession session,
    http.Client? httpClient,
    String baseUrl = ApiConfig.baseUrl,
  })  : _session = session,
        _http = httpClient ?? http.Client(),
        _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) =>
      _send('GET', path, query: query, authenticated: authenticated, abortTrigger: abortTrigger);

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated, abortTrigger: abortTrigger);

  Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) =>
      _send('PATCH', path, body: body, authenticated: authenticated, abortTrigger: abortTrigger);

  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) =>
      _send('PUT', path, body: body, authenticated: authenticated, abortTrigger: abortTrigger);

  Future<dynamic> delete(
    String path, {
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) =>
      _send('DELETE', path, authenticated: authenticated, abortTrigger: abortTrigger);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    required bool authenticated,
    Future<void>? abortTrigger,
  }) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    var uri = _baseUri.resolve(cleanPath);
    if (query != null) {
      uri = uri.replace(
        queryParameters: query.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        )..removeWhere((_, value) => value.isEmpty),
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await _session.readToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(401, 'Davam etmək üçün daxil olun.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final encodedBody = body == null ? null : jsonEncode(body);
    late http.Response response;
    try {
      final request = http.AbortableRequest(method, uri, abortTrigger: abortTrigger)
        ..headers.addAll(headers);
      if (encodedBody != null) {
        request.body = encodedBody;
      }
      final streamed = await _http.send(request).timeout(ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(ApiConfig.requestTimeout);
    } on http.RequestAbortedException {
      throw const ApiException(499, 'Sorğu dayandırıldı.');
    } on TimeoutException {
      throw const ApiException(408, 'Sorğu vaxtı bitdi. Yenidən cəhd edin.');
    } on http.ClientException {
      throw const ApiException(0, 'Şəbəkə bağlantısını yoxlayın.');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(response.statusCode, 'Server etibarsız cavab qaytardı.');
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['detail'] ?? decoded['message'] ?? decoded['title'])?.toString()
          : null;
      throw ApiException(response.statusCode, message ?? 'Sorğu tamamlanmadı.');
    }
    return decoded ?? <String, dynamic>{};
  }

  void close() => _http.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

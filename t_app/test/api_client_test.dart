import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';

class _FakeSession extends SecureSession {
  final String? token;

  _FakeSession(this.token);

  @override
  Future<String?> readToken() async => token;
}

void main() {
  test('authenticated requests use one HTTPS base and attach the bearer token', () async {
    late http.Request captured;
    final client = ApiClient(
      session: _FakeSession('signed.jwt'),
      baseUrl: 'https://api.technocare.az/api',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'items': []}), 200, headers: {'content-type': 'application/json'});
      }),
    );

    await client.get(
      'v1/shop/products',
      authenticated: true,
      query: {'q': 'ölçü cihazı', 'page': 2},
    );

    expect(captured.url.scheme, 'https');
    expect(captured.url.path, '/api/v1/shop/products');
    expect(captured.url.queryParameters['q'], 'ölçü cihazı');
    expect(captured.headers['authorization'], 'Bearer signed.jwt');
  });

  test('guest-only protected calls fail before reaching the network', () async {
    var called = false;
    final client = ApiClient(
      session: _FakeSession(null),
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.get('v1/shop/cart', authenticated: true),
      throwsA(isA<ApiException>().having((error) => error.statusCode, 'statusCode', 401)),
    );
    expect(called, isFalse);
  });

  test('problem details become normalized Azerbaijani API errors', () async {
    final client = ApiClient(
      session: _FakeSession(null),
      httpClient: MockClient((request) async => http.Response(
            utf8.decode(utf8.encode(jsonEncode({'detail': 'Məhsul artıq mövcud deyil.'}))),
            409,
            headers: {'content-type': 'application/problem+json; charset=utf-8'},
          )),
    );

    await expectLater(
      client.get('v1/shop/products/404'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.message, 'message', 'Məhsul artıq mövcud deyil.'),
      ),
    );
  });
}

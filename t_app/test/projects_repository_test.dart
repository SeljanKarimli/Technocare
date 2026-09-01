import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';
import 'package:technocare/repositories/projects_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('projects use last-known-good page while offline', () async {
    SharedPreferences.setMockInitialValues({});
    var online = true;
    final api = ApiClient(
      session: SecureSession(),
      baseUrl: 'https://api.technocare.az/api',
      httpClient: MockClient((request) async {
        if (!online) return http.Response('{}', 503);
        expect(request.url.queryParameters['q'], 'kran');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'name': 'STS Kran',
                'imageUrl': 'https://technocare.az/sts.webp',
              },
            ],
            'page': 1,
            'pageSize': 12,
            'total': 1,
            'totalPages': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ProjectsRepository(api);
    final live = await repository.getProjects(query: 'kran');
    expect(live.items.single.name, 'STS Kran');
    expect(live.isStale, isFalse);

    online = false;
    final cached = await repository.getProjects(
      query: 'kran',
      forceRefresh: true,
    );
    expect(cached.items.single.primaryImage, endsWith('sts.webp'));
    expect(cached.isStale, isTrue);
  });
}

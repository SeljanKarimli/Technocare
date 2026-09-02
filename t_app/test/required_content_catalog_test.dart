import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';
import 'package:technocare/models/content_defaults.dart';
import 'package:technocare/repositories/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Azerbaijani service headings map to stable catalog keys', () {
    expect(
      RequiredContentCatalog.canonicalKey('services', 'Avtomatika xidmətləri'),
      'automation',
    );
  });

  test(
    'missing service categories are completed around live website data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ContentRepository(
        ApiClient(
          session: SecureSession(),
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'schemaVersion': 1,
                'sourceUrl': 'https://technocare.az/xidmetler',
                'items': [
                  {
                    'id': 41,
                    'title': 'Avtomatika xidmətləri',
                    'summary': 'Saytdan gələn avtomatika xülasəsi',
                    'body': 'Saytdan gələn avtomatika mətni',
                    'imageUrl': 'https://technocare.az/automation.jpg',
                    'url': 'https://technocare.az/xidmetler/avtomatika',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      );

      final content = await repository.getCollection('services');
      expect(content.items.take(3).map((item) => item.title), [
        'Avtomatika xidmətləri',
        'Elektronika xidmətləri',
        'Energetika xidmətləri',
      ]);
      expect(content.items.first.body, contains('PLC proqramlaşdırılması'));
      expect(content.items[1].body, contains('PCB'));
      expect(content.items[2].body, contains('enerji səmərəliliyi'));
      expect(
        content.items.take(3).every((item) => item.imageUrl.isNotEmpty),
        isTrue,
      );
    },
  );

  test(
    'all education fields remain available while the API is offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ContentRepository(
        ApiClient(
          session: SecureSession(),
          httpClient: MockClient((_) async => http.Response('{}', 503)),
        ),
      );

      final content = await repository.getCollection('education');
      expect(content.items.map((item) => item.title), [
        'Avtomatika mühəndisliyi',
        'Elektronika mühəndisliyi',
        'Elektrik mühəndisliyi',
      ]);
      expect(content.items.every((item) => item.body.length > 200), isTrue);
      expect(content.items.every((item) => item.imageUrl.isNotEmpty), isTrue);
    },
  );

  test('application forms receive the selected canonical field', () {
    expect(
      RequiredContentCatalog.applicationField(
        'services',
        'Elektronika xidmətləri',
      ),
      'Elektronika Xidməti',
    );
    expect(
      RequiredContentCatalog.applicationField(
        'education',
        'Elektrik Mühəndisliyi Kursu',
      ),
      'Elektrik Mühəndisliyi',
    );
  });
}

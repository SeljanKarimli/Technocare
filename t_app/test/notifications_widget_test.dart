import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';
import 'package:technocare/screens/notifications_page.dart';

class _FakeApiClient extends ApiClient {
  final dynamic response;
  final List<String> requestedPaths = [];

  _FakeApiClient({this.response = const <dynamic>[]})
    : super(session: SecureSession());

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) async {
    requestedPaths.add(path);
    return response;
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) async => <String, dynamic>{};
}

void main() {
  test('website notification payload is recognized as a broadcast', () {
    final item = NotificationItem.fromJson({
      'id': 'abc123',
      'title': 'Technocare yeniləndi',
      'message': 'Yeni layihə əlavə edildi.',
      'timestamp': '2026-09-02T10:00:00Z',
      'url': 'https://technocare.az/layiheler',
    });

    expect(item.isBroadcast, isTrue);
    expect(item.url, 'https://technocare.az/layiheler');
  });

  testWidgets('notifications exposes a guest-safe empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: _FakeApiClient(),
        child: const MaterialApp(home: NotificationsPage(guest: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bildirişlər'), findsOneWidget);
    expect(find.text('Hələ bildirişiniz yoxdur.'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('guest sees website updates and read state stays on device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeApiClient(
      response: [
        {
          'id': 'update-1',
          'title': 'Technocare-da yenilik',
          'message': 'Yeni layihə əlavə edildi.',
          'timestamp': '2026-09-02T10:00:00Z',
          'isBroadcast': true,
        },
      ],
    );
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: const MaterialApp(home: NotificationsPage(guest: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.requestedPaths, ['notifications/public']);
    expect(find.text('Technocare-da yenilik'), findsOneWidget);
    expect(find.text('Bildirişlər (1)'), findsOneWidget);

    await tester.tap(find.text('Technocare-da yenilik'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('readBroadcastNotifications'), [
      'update-1',
    ]);
    expect(find.text('Bildirişlər'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';
import 'package:technocare/screens/notifications_page.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(session: SecureSession());

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) async => <dynamic>[];

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = false,
    Future<void>? abortTrigger,
  }) async => <String, dynamic>{};
}

void main() {
  testWidgets('notifications exposes a guest-safe empty state', (tester) async {
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: _FakeApiClient(),
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bildirişlər'), findsOneWidget);
    expect(find.text('Hələ bildirişiniz yoxdur.'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });
}

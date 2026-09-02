import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/widgets/auth_flow_info_card.dart';

void main() {
  testWidgets('account flow explains verification and guest access', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AuthFlowInfoCard())),
      ),
    );

    expect(find.text('Hesab necə işləyir?'), findsOneWidget);
    expect(find.textContaining('6 rəqəmli kodu'), findsOneWidget);
    expect(find.textContaining('hesab məcburi deyil'), findsOneWidget);
  });
}

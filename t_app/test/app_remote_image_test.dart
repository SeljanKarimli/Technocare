import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/core/app_remote_image.dart';

void main() {
  testWidgets('bundled image uses the asset image provider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppRemoteImage(
          source: 'assets/images/projects/ady-stadler.webp',
          semanticLabel: 'Layihə şəkli',
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Layihə şəkli'), findsWidgets);
  });

  testWidgets('empty image source exposes an Azerbaijani retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppRemoteImage(
          source: '',
          placeholderVariant: AppImagePlaceholderVariant.product,
        ),
      ),
    );

    expect(find.byTooltip('Yenidən cəhd et'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Yenidən cəhd et'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

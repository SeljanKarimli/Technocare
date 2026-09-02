import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/models/site_project.dart';
import 'package:technocare/screens/project_detail_page.dart';

void main() {
  testWidgets('project gallery opens full screen and pages between images', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const project = SiteProject(
      id: 'test',
      name: 'Test layihəsi',
      description: 'Qısa məlumat',
      imageUrl: 'assets/images/projects/ady-stadler.webp',
      content: 'Ətraflı məlumat',
      images: [
        'assets/images/projects/norm-sement.webp',
        'assets/images/projects/baku-steel.webp',
      ],
      url: '',
    );

    await tester.pumpWidget(
      const MaterialApp(home: ProjectDetailPage(project: project)),
    );
    await tester.pumpAndSettle();
    final firstThumbnail = find.byKey(
      const ValueKey<String>('project-gallery-thumbnail-0'),
    );
    await tester.scrollUntilVisible(
      firstThumbnail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(firstThumbnail);
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

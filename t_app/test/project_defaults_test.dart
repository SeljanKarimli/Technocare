import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/models/project_defaults.dart';

void main() {
  test(
    'static project catalogue contains every legacy project with an image',
    () {
      expect(ProjectDefaults.items, hasLength(26));
      for (final project in ProjectDefaults.items) {
        expect(project.name, isNotEmpty);
        expect(project.content.length, greaterThan(300));
        expect(project.primaryImage, startsWith('assets/images/projects/'));
        expect(
          File(project.primaryImage).existsSync(),
          isTrue,
          reason: '${project.id} üçün əsas asset mövcud deyil',
        );
        expect(
          project.images.length,
          greaterThanOrEqualTo(5),
          reason: '${project.id} qalereyası natamamdır',
        );
        expect(
          project.images.every((image) {
            final uri = Uri.tryParse(image);
            return uri?.scheme == 'https' &&
                uri?.host == 'technocare.az' &&
                RegExp(
                  r'\.(avif|gif|jpe?g|png|webp)$',
                  caseSensitive: false,
                ).hasMatch(uri!.path);
          }),
          isTrue,
        );
      }

      final galleryUrls = ProjectDefaults.items
          .expand((project) => project.images)
          .toList(growable: false);
      expect(galleryUrls, hasLength(239));
      expect(galleryUrls.toSet(), hasLength(galleryUrls.length));
    },
  );

  test('static project search handles Azerbaijani characters', () {
    expect(ProjectDefaults.search('Şabran').single.id, 'sabran-agro');
    expect(ProjectDefaults.search('AzerGold').single.id, 'azergold');
  });
}

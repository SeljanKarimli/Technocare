import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/models/project_defaults.dart';

void main() {
  test(
    'static project catalogue contains every legacy project with an image',
    () {
      expect(ProjectDefaults.items, hasLength(26));
      expect(
        ProjectDefaults.items.every(
          (project) =>
              project.name.isNotEmpty &&
              Uri.tryParse(project.primaryImage)?.hasAbsolutePath == true &&
              project.content.length > 300,
        ),
        isTrue,
      );
    },
  );

  test('static project search handles Azerbaijani characters', () {
    expect(ProjectDefaults.search('Şabran').single.id, 'sabran-agro');
    expect(ProjectDefaults.search('AzerGold').single.id, 'azergold');
  });
}

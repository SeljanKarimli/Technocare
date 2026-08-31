import 'package:flutter/material.dart';

import '../models/content_defaults.dart';
import 'ApplicationFormSPage.dart';
import 'RemoteContentCollection.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) => RemoteContentCollection(
    kind: 'services',
    title: 'Xidmətlər',
    emptyMessage: 'Hazırda xidmət məlumatı yoxdur.',
    fallbackIcon: Icons.engineering_outlined,
    applyPage: (_, item) => ApplicationFormSPage(
      initialSelectedField: RequiredContentCatalog.applicationField(
        'services',
        item.title,
      ),
    ),
  );
}

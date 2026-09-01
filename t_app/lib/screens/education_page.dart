import 'package:flutter/material.dart';

import '../models/content_defaults.dart';
import 'application_form_e_page.dart';
import 'remote_content_collection.dart';

class EducationPage extends StatelessWidget {
  const EducationPage({super.key});

  @override
  Widget build(BuildContext context) => RemoteContentCollection(
    kind: 'education',
    title: 'Təhsil',
    emptyMessage: 'Hazırda təhsil proqramı yoxdur.',
    fallbackIcon: Icons.school_outlined,
    applyPage: (_, item) => ApplicationFormEPage(
      initialSelectedField: RequiredContentCatalog.applicationField(
        'education',
        item.title,
      ),
    ),
  );
}

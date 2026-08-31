import 'package:flutter/material.dart';

import 'ApplicationFormEPage.dart';
import 'RemoteContentCollection.dart';

class EducationPage extends StatelessWidget {
  const EducationPage({super.key});

  @override
  Widget build(BuildContext context) => RemoteContentCollection(
        kind: 'education',
        title: 'Təhsil',
        emptyMessage: 'Hazırda təhsil proqramı yoxdur.',
        fallbackIcon: Icons.school_outlined,
        applyPage: (_, __) => const ApplicationFormEPage(),
      );
}

import 'package:flutter/material.dart';

class AuthFlowInfoCard extends StatelessWidget {
  const AuthFlowInfoCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF7E5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFC7E4C0)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF24631C)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hesab necə işləyir?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          '1. Məlumatlarınızı daxil edib hesab yaradın.\n'
          '2. E-poçta gələn 6 rəqəmli kodu təsdiqləyin.\n'
          '3. E-poçt və şifrə ilə daxil olun.',
        ),
        SizedBox(height: 8),
        Text(
          'Mağaza, səbət, WhatsApp sifarişi və müraciətlər üçün hesab məcburi deyil.',
          style: TextStyle(color: Color(0xFF36513A)),
        ),
      ],
    ),
  );
}

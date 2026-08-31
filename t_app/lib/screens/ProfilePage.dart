import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import 'AboutUsScreen.dart';
import 'HelpSupportScreen.dart';
import 'HomePage.dart';
import 'ShopOrdersPage.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hesabı silmək?'),
        content: const Text('Bu əməliyyat geri qaytarıla bilməz. Hesabınız və aktiv səbətiniz silinəcək.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv et')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('Hesabı sil')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ApiClient>().delete('Auth/delete-my-account', authenticated: true);
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 120),
        children: [
          const CircleAvatar(radius: 45, backgroundColor: Color(0xFFEAF7E5), child: Icon(Icons.person_rounded, size: 48, color: Color(0xFF3E8F2E))),
          const SizedBox(height: 14),
          Text(auth.userName?.isNotEmpty == true ? auth.userName! : 'Technocare istifadəçisi', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(auth.userEmail ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 28),
          _ProfileTile(icon: Icons.shopping_bag_outlined, title: 'Sifarişlərim', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopOrdersPage()))),
          _ProfileTile(icon: Icons.help_outline_rounded, title: 'Yardım və dəstək', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
          _ProfileTile(icon: Icons.info_outline_rounded, title: 'Haqqımızda', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()))),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Çıxış'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(onPressed: () => _deleteAccount(context), icon: const Icon(Icons.delete_forever_outlined), label: const Text('Hesabı sil'), style: TextButton.styleFrom(foregroundColor: Colors.red.shade700)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 11),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: CircleAvatar(backgroundColor: const Color(0xFFEAF7E5), child: Icon(icon, color: const Color(0xFF3E8F2E))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

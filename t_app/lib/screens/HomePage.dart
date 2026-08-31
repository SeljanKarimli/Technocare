import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/shop_cart_provider.dart';
import 'CategoriesPage.dart';
import 'EducationPage.dart';
import 'LiveHomeScreen.dart';
import 'LoginScreen.dart';
import 'NotificationsPage.dart';
import 'ProfilePage.dart';
import 'ProjectsPage.dart';
import 'RegisterScreen.dart';
import 'ShopCartPage.dart';
import 'ShopPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  StreamSubscription<Uri>? _linkSubscription;

  late final List<Widget> _screens = [
    LiveHomeScreen(onOpenShop: () => setState(() => _selectedIndex = 1)),
    const ShopPage(),
    const CategoriesPage(),
    const EducationPage(),
    const ProjectsPage(),
    const _ProfileGate(),
  ];

  @override
  void initState() {
    super.initState();
    final links = AppLinks();
    _linkSubscription = links.uriLinkStream.listen(_handleAppLink);
    links.getInitialLink().then((link) {
      if (link != null) _handleAppLink(link);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _handleAppLink(Uri link) {
    if (link.scheme != 'technocare' || link.host != 'checkout' || !mounted) {
      return;
    }
    if (link.pathSegments.contains('success')) {
      context.read<ShopCartProvider>().clear().catchError((_) {});
      setState(() => _selectedIndex = 5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sifarişiniz qəbul edildi.')),
      );
    } else if (link.pathSegments.contains('cancel')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödəniş tamamlanmadı. Səbətiniz saxlanıldı.')),
      );
    }
  }

  Future<bool> _requireLogin() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) return true;
    return await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen(returnToPrevious: true))) == true;
  }

  Future<void> _openCart() async {
    if (!await _requireLogin() || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopCartPage()));
  }

  Future<void> _openNotifications() async {
    if (!await _requireLogin() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Image.asset(
          'assets/images/technocare.png',
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('TECHNOCARE', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E8F2E))),
        ),
        centerTitle: false,
        actions: [
          IconButton(tooltip: 'Bildirişlər', onPressed: _openNotifications, icon: const Icon(Icons.notifications_none_rounded)),
          Consumer<ShopCartProvider>(builder: (_, cart, __) => IconButton(
            tooltip: 'Səbət',
            onPressed: _openCart,
            icon: Badge(isLabelVisible: cart.cart.itemCount > 0, label: Text('${cart.cart.itemCount}'), child: const Icon(Icons.shopping_bag_outlined)),
          )),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => launchUrl(Uri.parse('https://wa.me/994102307097'), mode: LaunchMode.externalApplication),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_outlined),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 18, color: Color(0x16000000), offset: Offset(0, -4))]),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: (index) => setState(() => _selectedIndex = index),
              gap: 4,
              color: const Color(0xFF7A847D),
              activeColor: const Color(0xFF3E8F2E),
              tabBackgroundColor: const Color(0xFFEAF7E5),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              iconSize: 22,
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3E8F2E)),
              tabs: const [
                GButton(icon: Icons.home_outlined, text: 'Ana səhifə'),
                GButton(icon: Icons.storefront_outlined, text: 'Mağaza'),
                GButton(icon: Icons.engineering_outlined, text: 'Xidmətlər'),
                GButton(icon: Icons.school_outlined, text: 'Təhsil'),
                GButton(icon: Icons.factory_outlined, text: 'Layihələr'),
                GButton(icon: Icons.person_outline_rounded, text: 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (_, auth, __) {
      if (auth.isAuthenticated) return const ProfilePage();
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(color: Color(0xFFEAF7E5), shape: BoxShape.circle),
              child: const Icon(Icons.person_outline_rounded, size: 48, color: Color(0xFF3E8F2E)),
            ),
            const SizedBox(height: 22),
            const Text('Hesabınıza daxil olun', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            const Text('Səbət, sifarişlər və bildirişlər üçün hesabınızdan istifadə edin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.45)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen(returnToPrevious: true))), child: const Text('Daxil ol'))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Qeydiyyatdan keç'))),
          ]),
        ),
      );
    });
  }
}

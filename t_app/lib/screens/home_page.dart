import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/shop_cart_provider.dart';
import '../services/whatsapp_order_service.dart';
import 'categories_page.dart';
import 'education_page.dart';
import 'live_home_screen.dart';
import 'login_screen.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'projects_page.dart';
import 'register_screen.dart';
import 'shop_cart_page.dart';
import 'shop_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  late final List<Widget> _screens = [
    LiveHomeScreen(
      onOpenShop: () => _selectTab(1),
      onOpenServices: () => _selectTab(2),
      onOpenEducation: () => _selectTab(3),
      onOpenProjects: () => _selectTab(4),
    ),
    const ShopPage(),
    const CategoriesPage(),
    const EducationPage(),
    const ProjectsPage(),
    const _ProfileGate(),
  ];

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopCartPage()),
    );
  }

  Future<void> _openNotifications() async {
    final isGuest = !context.read<AuthProvider>().isAuthenticated;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsPage(guest: isGuest)),
    );
  }

  Future<void> _openWhatsAppChat() async {
    final service = context.read<WhatsAppOrderService>();
    final uri = await service.createChatUri();
    var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (!opened && mounted) {
      final phone = await service.resolveTechnocarePhone();
      await Clipboard.setData(ClipboardData(text: '+$phone'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp açılmadı. Əlaqə nömrəsi kopyalandı.'),
        ),
      );
    }
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
          errorBuilder: (_, __, ___) => const Text(
            'TECHNOCARE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF2F7623),
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Bildirişlər',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Consumer<ShopCartProvider>(
            builder: (_, cart, __) => IconButton(
              tooltip: 'Səbət',
              onPressed: _openCart,
              icon: Badge(
                isLabelVisible: cart.cart.itemCount > 0,
                label: Text('${cart.cart.itemCount}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'WhatsApp ilə əlaqə',
        onPressed: _openWhatsAppChat,
        backgroundColor: const Color(0xFF087A32),
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_outlined),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x16000000),
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: _selectTab,
              gap: 4,
              color: const Color(0xFF7A847D),
              activeColor: const Color(0xFF2F7623),
              tabBackgroundColor: const Color(0xFFEAF7E5),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              iconSize: 22,
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2F7623),
              ),
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
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isAuthenticated) return const ProfilePage();
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF7E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 48,
                    color: Color(0xFF2F7623),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Hesabınıza daxil olun',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Mağaza və WhatsApp sifarişi hesab olmadan işləyir. Profil və şəxsi bildirişlər üçün giriş könüllüdür.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.45),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(returnToPrevious: true),
                      ),
                    ),
                    child: const Text('Daxil ol'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Qeydiyyatdan keç'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

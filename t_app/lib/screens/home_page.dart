import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/shop_cart_provider.dart';
import '../services/whatsapp_order_service.dart';
import 'categories_page.dart';
import 'education_page.dart';
import 'live_home_screen.dart';
import 'notifications_page.dart';
import 'projects_page.dart';
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
  ];

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopCartPage()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage(guest: true)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navigation.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Updated list of widgets for the bottom navigation bar
  // Note: ProjectsPage is not const because it might contain dynamic state
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreenContent(),
    const CategoriesPage(),
    const EducationPage(),
    const ProjectsPage(), 
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context); // Access AuthProvider

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/technocare.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'Technocare',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const NotificationsPage(apiBaseUrl: "http://technocareapi.runasp.net/api")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyCartPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final Uri whatsappUrl = Uri.parse(
              "https://wa.me/994102346357?text=Salam+Technocare%2C+M%C9%99n%C9%99+k%C3%B6m%C9%99k+ed%C9%99+bil%C9%99rsiniz?");
          launchUrl(
            whatsappUrl,
            mode: LaunchMode.externalApplication,
          );
        },
        backgroundColor: Colors.green,
        elevation: 4,
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GNav(
              gap: 12,
              selectedIndex: _selectedIndex,
              onTabChange: _onItemTapped,
              backgroundColor: Colors.white,
              color: Colors.grey.shade500,
              activeColor: Colors.green,
              tabBackgroundColor: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              iconSize: 24,
              duration: const Duration(milliseconds: 300),
              tabs: const [
                GButton(icon: Icons.home_outlined, text: 'Ana Səhifə'),
                GButton(icon: Icons.category_outlined, text: 'Xidmət'),
                GButton(icon: Icons.school_outlined, text: 'Təhsil'),
                GButton(icon: Icons.agriculture_outlined, text: 'Layihələr'),
                GButton(icon: Icons.person_outline, text: 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  late Future<List<Product>> _productsFuture;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _displayedProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  /// Helper to bypass CORS using the working wsrv.nl proxy
  String _getSafeImageUrl(String url) {
    String trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return 'https://via.placeholder.com/300?text=No+Image';
    }
    if (trimmedUrl.startsWith('http')) {
      return "https://wsrv.nl/?url=${Uri.encodeComponent(trimmedUrl)}&default=error";
    }
    return trimmedUrl;
  }

  Future<void> _fetchProducts() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _productsFuture = apiService.getProducts().then((data) {
        List<Product> fetchedProducts = [];
        if (data is List) {
          fetchedProducts = data.map((itemJson) => Product.fromJson(itemJson as Map<String, dynamic>)).toList();
        } else if (data is Map && data.containsKey('products') && data['products'] is List) {
          fetchedProducts = (data['products'] as List)
              .map((itemJson) => Product.fromJson(itemJson as Map<String, dynamic>))
              .toList();
        }
        _allProducts = fetchedProducts;
        _applyFilters();
        return _displayedProducts;
      }).catchError((error) {
        _showErrorSnackBar('Məhsullar yüklənərkən xəta: $error');
        return <Product>[];
      });
    });
  }

  void _applyFilters() {
    setState(() {
      _displayedProducts = _allProducts.where((product) {
        bool matchesSearch = _searchController.text.isEmpty ||
            product.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            product.description.toLowerCase().contains(_searchController.text.toLowerCase());
        return matchesSearch;
      }).toList();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Məhsul axtarın...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.grey.shade600),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
                onChanged: (value) => _applyFilters(),
              ),
            ),
            const SizedBox(height: 24.0),

            // Promotional Banner
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade100, Colors.orange.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade200.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Technocare MMC',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Technocare olaraq dünya brendlərinin məhsulları üzrə Azərbaycanda satış və servis xidmətləri təqdim edirik.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),

            const Text(
              'Məhsullar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24.0),

            FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || _displayedProducts.isEmpty) {
                  return const Center(child: Text('Məhsul tapılmadı.'));
                } else {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _displayedProducts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final product = _displayedProducts[index];
                      return ProductCard(
                        product: product,
                        productName: product.name,
                        price: product.price.toStringAsFixed(2),
                        imageUrl: _getSafeImageUrl(product.imageUrl),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailPage(product: product),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
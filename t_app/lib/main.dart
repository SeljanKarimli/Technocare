import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:provider/provider.dart'; // For state management
import 'package:shared_preferences/shared_preferences.dart'; // For storing JWT token
import 'dart:io'; // Import for HttpClient

import 'navigation.dart'; // Import LocationSelectionScreen for navigation


void main() {
  HttpOverrides.global = MyHttpOverrides();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(baseUrl: 'http://technocareapi.runasp.net/api'),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            apiService: Provider.of<ApiService>(context, listen: false),
          ),
        ),
      ],
      child: const TechnocareApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class ApiService {
  final String baseUrl; // Base URL of your backend API

  ApiService({required this.baseUrl});
  Future<List<CategoryDto>> getCategories() async {
  final res = await _get('categories'); // -> /api/categories
  final decoded = (res is String) ? json.decode(res) : res;

  final list = (decoded is List) ? decoded : <dynamic>[];
  return list
      .where((e) => e is Map)
      .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
      .toList();
}

  Future<dynamic> _post(String endpoint, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken');

    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );
    return _handleResponse(response, endpoint: endpoint, method: 'POST');
  }
  Future<dynamic> _get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken'); // Retrieve JWT token

    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token', // Add token if available
      },
    );
    return _handleResponse(response, endpoint: endpoint, method: 'GET');
  }

  Future<dynamic> _put(String endpoint, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken'); // Retrieve JWT token

    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token', // Add token if available
      },
      body: json.encode(data),
    );
    return _handleResponse(response, endpoint: endpoint, method: 'PUT');
  }

  Future<dynamic> _delete(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken'); // Retrieve JWT token

    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token', // Add token if available
      },
    );
    return _handleResponse(response, endpoint: endpoint, method: 'DELETE');
  }

  dynamic _handleResponse(http.Response response, {required String endpoint, required String method}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        print('API Success ($method $endpoint): Status ${response.statusCode}, Empty Body');
        return {}; // Return an empty map for empty successful responses (e.g., 204 No Content)
      }
      try {
        final decodedBody = json.decode(response.body);
        print('API Success ($method $endpoint): Status ${response.statusCode}, Body: $decodedBody');
        return decodedBody; // Returns Map or List based on JSON structure
      } catch (e) {
        print('API Success ($method $endpoint): Status ${response.statusCode}, Body Parsing Error: $e, Raw Body: ${response.body}');
        throw Exception('Failed to parse response from $endpoint: ${response.body}');
      }
    } else {
      String errorMessage = 'Failed to load data';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'];
        } else if (response.body.isNotEmpty) {
          errorMessage = response.body; // Use raw body if not a structured error
        }
      } catch (e) {
        // If parsing fails, stick to generic message
      }
      print('API Error ($method $endpoint): Status ${response.statusCode}, Message: $errorMessage, Raw Body: ${response.body}');
      throw Exception(errorMessage);
    }
  }

 

  // --- Auth Endpoints (Updated for C# backend) ---
  Future<Map<String, dynamic>> register(String name, String email, String password, String phone) async {
    // C# backend register endpoint does not return token or userId directly on success.
    // It returns a message and expects email verification.
    return await _post('Auth/register', {
      'Name': name, // Changed to PascalCase
      'Email': email, // Changed to PascalCase
      'Password': password, // Changed to PascalCase
      'Phone': phone, // Changed to PascalCase
    }) as Map<String, dynamic>; // Cast to Map<String, dynamic>
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    // C# backend login endpoint returns token, userId, and emailVerified status.
    return await _post('auth/login', {
      'Email': email, // Changed to PascalCase
      'Password': password, // Changed to PascalCase
    }) as Map<String, dynamic>; // Cast to Map<String, dynamic>
  }

  // Removed verifyCode as C# backend uses email link verification.
  // If you need an in-app manual code verification, you'd need a separate POST endpoint in C#.

  // New API method for forgot password (matches C# backend)
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    return await _post('auth/forgot-password', {
      'Email': email, // Changed to PascalCase
    }) as Map<String, dynamic>; // Cast to Map<String, dynamic>
  }

  // New API method for reset password (matches C# backend)
  Future<Map<String, dynamic>> resetPassword(String email, String token, String newPassword) async {
    return await _post('auth/reset-password', {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
    return await _post('auth/verify-email', {
      'email': email, // <-- lowercase
      'code': code,   // <-- lowercase
    }) as Map<String, dynamic>;
  }

  // --- Product Endpoints (Remain largely similar, confirm C# ProductController.cs matches) ---
  Future<dynamic> getProducts({String? category, String? search, int limit = 10, int page = 1}) async {
    String query = '';
    if (category != null) query += 'category=$category&';
    if (search != null) query += 'search=$search&';
    query += 'limit=$limit&page=$page';
    return await _get('products?$query');
  }

  Future<Map<String, dynamic>> getProduct(String id) async {
    return await _get('products/$id') as Map<String, dynamic>;
  }

Future<Map<String, dynamic>> getCart() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');

  if (userId == null || userId.isEmpty) {
    throw Exception('UserId missing, login again.');
  }

  final response = await _get('carts?userId=$userId');

  if (response is! Map<String, dynamic>) {
    throw Exception('Invalid cart response type: ${response.runtimeType}');
  }

  return response;
}


Future<Map<String, dynamic>> addToCart({
  required String productId,
  required int quantity,
  required String productName,
  required String imageUrl,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');

  if (userId == null || userId.isEmpty) {
    throw Exception('No userId found in local storage. Please log in again.');
  }

  // Əgər sənin backend bütün cart endpointlərini /api ilə edirsə, burada da elə saxla:
  final path = 'carts?userId=$userId';

  final response = await _post(path, {
    'ProductId': productId,
    'Quantity': quantity,
    'ProductName': productName,
    'ImageUrl': imageUrl,
    // təhlükəsiz olsun deyə userId-ni də göndərək (bəzi DTO-lar tələb edir)
    'UserId': userId,
  }) as Map<String, dynamic>;

  return response;
}

Future<Map<String, dynamic>> updateCartItem(String productId, int quantity) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');

  if (userId == null || userId.isEmpty) {
    throw Exception('No userId found in local storage. Please log in again.');
  }
  final path = 'carts/$productId?userId=$userId';
  return await _put(path, {
    'Quantity': quantity,
    'UserId': userId,
  }) as Map<String, dynamic>;
}

Future<void> removeCartItem(String productId) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');
  final path = 'carts/$productId?userId=$userId';
  await _delete(path);
}

Future<void> clearCart(String userId) async {
  await _delete('carts/clear?userId=$userId');
}

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderDetails) async {
  // Read locally saved identity
  final prefs  = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');
  // you save either userEmail (from AuthProvider) or email (legacy) — try both
  final email  = prefs.getString('userEmail') ?? prefs.getString('email');

  // Inject identity if caller forgot to add it
  final payload = Map<String, dynamic>.from(orderDetails);
  if (!payload.containsKey('userId') && userId != null && userId.isNotEmpty) {
    payload['userId'] = userId;
  }
  if (!payload.containsKey('email') && email != null && email.isNotEmpty) {
    payload['email'] = email;
  }

  // Helpful debug to verify what we send
  // ignore: avoid_print
  print('[ApiService] createOrder payload: $payload');

  return await _post('orders', payload) as Map<String, dynamic>;
}

  Future<dynamic> getOrders() async {
    return await _get('orders/my-orders'); // C# has a specific endpoint for user's orders.
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    return await _get('orders/$id') as Map<String, dynamic>;
  }

  // --- Application Endpoints (Updated to match C# ApplicationController.cs) ---
  // Renamed from applyForCourse as there's no specific course model on backend
  Future<Map<String, dynamic>> applyForApplication(Map<String, dynamic> applicationDetails) async {
    // Changed keys to PascalCase to match C# CreateApplicationRequest DTO
    return await _post('applications', {
      'Name': applicationDetails['name'],
      'Email': applicationDetails['email'],
      'Phone': applicationDetails['phone'],
      'AppliedFor': applicationDetails['appliedFor'],
      'Message': applicationDetails['message'],
    }) as Map<String, dynamic>;
  }

  // --- NEW: Favorites Endpoints ---
  Future<List<Product>> getFavorites() async {
    final response = await _get('favorites');
    if (response is List) {
      return response.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    }
    return []; // Return empty list if no favorites or unexpected response
  }

  Future<void> addFavorite(String productId) async {
    await _post('favorites', {'ProductId': productId}); // Changed to PascalCase
  }

  Future<void> removeFavorite(String productId) async {
    await _delete('favorites/$productId');
  }

  // Note: getCourses and getCourse removed as per backend change.
  // If you want to list static courses on the Flutter side, you'll manage it locally.
}

/// A provider class for managing user authentication state.
/// It uses `ChangeNotifier` to notify widgets about state changes.
/// It interacts with `ApiService` for actual API calls and `SharedPreferences` for token persistence.
class AuthProvider with ChangeNotifier {
  final ApiService apiService;
  String? _token;
  String? _userId;
  bool _isLoading = false; // To show loading indicators
  String? _errorMessage; // To store and display error messages

  // New fields for user profile information
  String? _userName;
  String? _userEmail;
  String? _userPhone;

  AuthProvider({required this.apiService}) {
    _loadUserFromPrefs(); // Load user details on initialization
  }

  // Getters for authentication state
  String? get token => _token;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Getters for user profile information
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;

  /// Loads the JWT token and user ID from SharedPreferences.
  Future<void> _loadUserFromPrefs() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwtToken');
    _userId = prefs.getString('userId');
    // Loading actual user details from prefs, set to null if not found
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    _userPhone = prefs.getString('userPhone');

    _isLoading = false;
    notifyListeners();
  }

  /// Saves the JWT token and user ID to SharedPreferences.
  Future<void> _saveUserToPrefs(String token, String userId, {String? name, String? email, String? phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwtToken', token);
    await prefs.setString('userId', userId);
    if (name != null) await prefs.setString('userName', name);
    if (email != null) await prefs.setString('userEmail', email);
    if (phone != null) await prefs.setString('userPhone', phone);

    _token = token;
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _userPhone = phone;
    notifyListeners();
  }

  /// Clears user data from SharedPreferences (logout).
  Future<void> _clearUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwtToken');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');

    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    notifyListeners();
  }

  /// Handles user login.
  /// Makes an API call, saves token, and updates state.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null; // Clear previous error messages
    notifyListeners();
    try {
      final response = await apiService.login(email, password);
      // C# backend response directly includes emailVerified and possibly a message for unverified
      if (response['emailVerified'] == true && response['token'] != null && response['id'] != null) {
        // Use actual user details from response if available.
        // Provide a default empty string if the key is not present or null to avoid errors.
        final String name = response['name'] ?? '';
        final String emailFromResponse = response['email'] ?? email; // Use email from response or input
        final String phone = response['phone'] ?? ''; // Use phone from response
        await _saveUserToPrefs(response['token'], response['id'], name: name, email: emailFromResponse, phone: phone);
        _isLoading = false;
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login failed due to unknown reason.';
        _isLoading = false;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Remove "Exception: " prefix
      _isLoading = false;
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await apiService.register(name, email, password, phone);
      if (response['message'] != null) { // Check for a success message from C# backend
        _isLoading = false;
        return true; // Indicates registration request was sent successfully
      } else {
        _errorMessage = response['message'] ?? 'Registration failed.';
        _isLoading = false;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      return false;
    }
  }
  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
  return await apiService.verifyEmailCode(email, code);
}
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await apiService.sendPasswordResetEmail(email);
      _isLoading = false;
      return response['message'] != null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      return false;
    }
  }
  

  /// Resets user's password.
  Future<bool> resetPassword(String email, String token, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await apiService.resetPassword(email, token, newPassword);
      _isLoading = false;
      return response['message'] != null; // Check for a success message
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      return false;
    }
  }

  /// Logs out the user by clearing local data and updating state.
  void logout() async {
    await _clearUserFromPrefs();
    notifyListeners();
  }

  /// Clears any currently stored error message.
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }
}


class TechnocareApp extends StatelessWidget {
  const TechnocareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Technocare', // Corrected title
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green,
          secondary: Colors.orange,
          surface: Colors.white,
          error: Colors.red,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.green, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            elevation: 2,
            shadowColor: Colors.green.withOpacity(0.3),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE0E0E0),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
        ),
      ),
      debugShowCheckedModeBanner: false,
      // Start with the WelcomeScreen for the "Get Started" flow
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          // Show a loading indicator while auth status is being determined
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // If authenticated, go to HomePage, otherwise to WelcomeScreen
          return auth.isAuthenticated ? const HomePage() : const WelcomeScreen();
        },
      ),
    );
  }
}
 class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/technocare.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.business,
                        size: 80,
                        color: Colors.green.shade700,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Xoş gəlmişsiniz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Avtomatikadan Technocare ilə xəbərdar olun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 64),
                // Features
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureItem(Icons.school, 'Təhsil'),
                    _buildFeatureItem(Icons.shopping_cart, 'Məhsullar'),
                    _buildFeatureItem(Icons.support_agent, 'Dəstək'),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.green.withOpacity(0.3),
                    ),
                    child: const Text(
                      'Başlayaq',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: Text(
                    'Hesabınız yoxdur? Qeydiyyatdan keçin',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 32,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}


class CategoryDto {
  final String id;
  final String name;

  CategoryDto({required this.id, required this.name});

  factory CategoryDto.fromJson(Map<String, dynamic> j) => CategoryDto(
    id: (j['id'] ?? j['Id'] ?? '').toString(),
    name: (j['name'] ?? j['Name'] ?? '').toString(),
  );
}

// --- Common Widgets ---

class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Icon(icon, size: 40, color: Colors.green.shade700),
            ),
            const SizedBox(height: 12.0),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product; // Added product object
  final String productName;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product, // Required this.product
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\₼$price',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      if (!authProvider.isAuthenticated) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Səbətə məhsul əlavə etmək üçün daxil olmalısınız.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final apiService = Provider.of<ApiService>(context, listen: false);
                      try {
                        await apiService.addToCart(
                            productId: product.id,
                            quantity: 1,
                            productName: product.name,
                            imageUrl: product.imageUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${productName} səbətə əlavə edildi!'),
                            backgroundColor: Colors.green.shade600,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Səbətə əlavə edilərkən xəta: ${e.toString().replaceFirst('Exception: ', '')}'),
                            backgroundColor: Colors.red.shade400,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 40, color: Colors.green.shade700),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NEW: OrderFlutter model (to map to C# Order model)
class OrderFlutter {
  final String id;
  final String userId;
  final DateTime orderDate;
  final double totalAmount;
  final String status;
  final String shippingAddress;
  final String paymentMethod;
  final List<OrderItemFlutter> items;

  OrderFlutter({
    required this.id,
    required this.userId,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.items,
  });

  factory OrderFlutter.fromJson(Map<String, dynamic> json) {
    return OrderFlutter(
      id: json['id'] as String,
      userId: json['userId'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: json['status'] as String,
      shippingAddress: json['shippingAddress'] as String,
      paymentMethod: json['paymentMethod'] as String,
      items: (json['items'] as List)
          .map((itemJson) => OrderItemFlutter.fromJson(itemJson as Map<String, dynamic>)) // Explicit cast here
          .toList(),
    );
  }
}

// NEW: OrderItemFlutter model (to map to C# OrderItem)
class OrderItemFlutter {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String imageUrl;

  OrderItemFlutter({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory OrderItemFlutter.fromJson(Map<String, dynamic> json) {
    return OrderItemFlutter(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] is String) ? int.parse(json['quantity']) : json['quantity'] as int, // Handle potential string quantity
      imageUrl: json['imageUrl'] as String,
    );
  }
}


class Project {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String content;
  final List<String>? images;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.content,
    this.images,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'No Name',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: (json['images'] as List?)
          ?.map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final String subcategory;
  final int stock;
  final List<String>? tags;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.subcategory,
    required this.stock,
    this.tags,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '', // Handle null and convert to string
      name: json['name']?.toString() ?? 'No Name', // Provide default value
      description: json['description']?.toString() ?? 'No description available',
      price: (json['price'] as num?)?.toDouble() ?? 0.0, // Handle null price
      imageUrl: json['imageUrl']?.toString() ?? '', // Default empty string
      category: json['category']?.toString() ?? 'Uncategorized',
      subcategory: json['subcategory']?.toString() ?? 'No Subcategory',
      stock: (json['stock'] as num?)?.toInt() ?? 0, // Handle null stock
      tags: (json['tags'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(),
    );
  }
}
class _ValuePoint extends StatelessWidget {
  final String title;
  final String description;

  _ValuePoint(this.title, this.description, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $title:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
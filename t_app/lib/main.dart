import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/secure_session.dart';
import 'providers/auth_provider.dart';
import 'providers/shop_cart_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/content_repository.dart';
import 'repositories/shop_repository.dart';
import 'screens/HomePage.dart';
import 'services/whatsapp_order_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final secureSession = SecureSession();
  await secureSession.migrateLegacySession();
  final apiClient = ApiClient(session: secureSession);
  final authRepository = AuthRepository(apiClient);
  final contentRepository = ContentRepository(apiClient);
  final shopRepository = ShopRepository(apiClient);
  final whatsAppOrderService = WhatsAppOrderService(shopRepository);

  runApp(
    MultiProvider(
      providers: [
        Provider<SecureSession>.value(value: secureSession),
        Provider<ApiClient>.value(value: apiClient),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<ContentRepository>.value(value: contentRepository),
        Provider<ShopRepository>.value(value: shopRepository),
        Provider<WhatsAppOrderService>.value(value: whatsAppOrderService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            repository: authRepository,
            secureSession: secureSession,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ShopCartProvider(shopRepository);
            provider.load().catchError((_) {});
            return provider;
          },
        ),
      ],
      child: const TechnocareApp(),
    ),
  );
}

class TechnocareApp extends StatelessWidget {
  const TechnocareApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Technocare',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFFF8FAF8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF59BE3F),
        primary: const Color(0xFF3E8F2E),
        secondary: const Color(0xFF59BE3F),
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF101815),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F4F0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF59BE3F), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3E8F2E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    home: Consumer<AuthProvider>(
      builder: (_, auth, __) => auth.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const HomePage(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  /// Helper method to ensure images load on Flutter Web.
  /// Switched to wsrv.nl (WordPress/CloudImage proxy) which is highly 
  /// optimized for delivering images and bypassing CORS/Hotlinking restrictions.
  String _getSafeImageUrl(String url) {
    String trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return 'https://via.placeholder.com/600x400?text=No+Image';
    }
    
    if (trimmedUrl.startsWith('http')) {
      // wsrv.nl is one of the most reliable proxies for images specifically.
      // It handles CORS and also optimizes the image delivery.
      return "https://wsrv.nl/?url=${Uri.encodeComponent(trimmedUrl)}&default=error";
    }
    
    return trimmedUrl;
  }

  @override
  Widget build(BuildContext context) {
    final safeImageUrl = _getSafeImageUrl(product.imageUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, style: const TextStyle(color: Colors.black)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Image.network(
                    safeImageUrl,
                    fit: BoxFit.contain, // Maintain aspect ratio for technical parts
                    height: MediaQuery.of(context).size.height * 0.4,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint("Image Load Error: $error");
                      // Final fallback: try the original URL directly in case the proxy is down
                      if (safeImageUrl.contains('wsrv.nl')) {
                        return Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          height: MediaQuery.of(context).size.height * 0.4,
                          errorBuilder: (c, e, s) => _buildErrorPlaceholder(),
                        );
                      }
                      return _buildErrorPlaceholder();
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₼${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);

                          if (!authProvider.isAuthenticated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Səbətə məhsul əlavə etmək üçün daxil olmalısınız.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final apiService =
                              Provider.of<ApiService>(context, listen: false);

                          try {
                            await apiService.addToCart(
                              productId: product.id,
                              quantity: 1,
                              productName: product.name,
                              imageUrl: safeImageUrl,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} səbətə əlavə edildi!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Səbətə əlavə edilərkən xəta: ${e.toString().replaceFirst('Exception: ', '')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Səbətə əlavə et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey[100],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Məhsul şəkli yüklənmədi",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
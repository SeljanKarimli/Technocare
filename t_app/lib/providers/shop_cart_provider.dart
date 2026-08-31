import 'package:flutter/foundation.dart';

import '../models/shop_models.dart';
import '../repositories/shop_repository.dart';

class ShopCartProvider extends ChangeNotifier {
  final ShopRepository repository;
  ShopCart _cart = const ShopCart.empty();
  bool _loading = false;
  String? _error;

  ShopCartProvider(this.repository);

  ShopCart get cart => _cart;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() => _run(() => repository.getCart());

  Future<void> add(ShopProduct product, {int quantity = 1}) => _run(
    () => repository.addToCart(
      product.id,
      quantity: quantity,
      productSnapshot: product,
    ),
  );

  Future<void> update(int productId, int quantity) =>
      _run(() => repository.updateCartItem(productId, quantity));

  Future<void> remove(int productId) =>
      _run(() => repository.removeCartItem(productId));

  Future<void> clear() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await repository.clearCart();
      _cart = const ShopCart.empty();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<ShopCart> Function() request) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _cart = await request();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

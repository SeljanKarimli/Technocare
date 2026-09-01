import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technocare/core/api_client.dart';
import 'package:technocare/core/secure_session.dart';
import 'package:technocare/models/shop_models.dart';
import 'package:technocare/repositories/shop_repository.dart';
import 'package:technocare/services/whatsapp_order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'guest cart persists locally and refreshes prices without a token',
    () async {
      SharedPreferences.setMockInitialValues({});
      var livePrice = 12.5;
      final requests = <http.Request>[];
      final client = ApiClient(
        session: SecureSession(),
        baseUrl: 'https://api.technocare.az/api',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(_productJson(price: livePrice)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repository = ShopRepository(client);
      final added = await repository.addToCart(77, quantity: 2);
      expect(added.itemCount, 2);
      expect(added.subtotal, 25);

      livePrice = 15;
      final restored = await ShopRepository(client).getCart();
      expect(restored.itemCount, 2);
      expect(restored.subtotal, 30);
      expect(requests, isNotEmpty);
      expect(
        requests.every(
          (request) => !request.headers.containsKey('authorization'),
        ),
        isTrue,
      );
    },
  );

  test('WhatsApp order text contains product identity, quantity and total', () {
    final product = ShopProduct.fromJson(_productJson(price: 12.5));
    final cart = ShopCart(
      items: [
        ShopCartItem(
          productId: 77,
          quantity: 2,
          product: product,
          lineTotal: 25,
        ),
      ],
      itemCount: 2,
      subtotal: 25,
      currencyCode: 'AZN',
      currencySymbol: '₼',
    );
    final service = WhatsAppOrderService(
      ShopRepository(ApiClient(session: SecureSession())),
    );

    final message = service.buildOrderMessage(cart);
    expect(message, contains('Sənaye sensoru'));
    expect(message, contains('SKU: SN-001'));
    expect(message, contains('Miqdar: 2'));
    expect(message, contains('Ümumi məbləğ: ₼25.00'));

    final staleMessage = service.buildOrderMessage(
      cart,
      pricesRequireConfirmation: true,
    );
    expect(
      staleMessage,
      contains('Yekun qiymət Technocare nümayəndəsi tərəfindən təsdiqlənəcək'),
    );
  });

  test('shop pages return marked last-known-good data while offline', () async {
    SharedPreferences.setMockInitialValues({});
    var online = true;
    final repository = ShopRepository(
      ApiClient(
        session: SecureSession(),
        baseUrl: 'https://api.technocare.az/api',
        httpClient: MockClient((_) async {
          if (!online) return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'items': [_productJson(price: 12.5)],
              'page': 1,
              'pageSize': 20,
              'total': 1,
              'totalPages': 1,
              'facets': <String, dynamic>{},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final live = await repository.getProducts(query: 'SN-001');
    expect(live.items.single.id, 77);
    expect(live.isStale, isFalse);
    online = false;
    final stale = await repository.getProducts(
      query: 'SN-001',
      forceRefresh: true,
    );
    expect(stale.items.single.id, 77);
    expect(stale.isStale, isTrue);
    expect(stale.cachedAt, isNotNull);
  });

  test('Technocare WhatsApp number is extracted from common website links', () {
    expect(
      WhatsAppOrderService.phoneFromWhatsAppUrl('https://wa.me/994102307097'),
      '994102307097',
    );
    expect(
      WhatsAppOrderService.phoneFromWhatsAppUrl(
        'https://api.whatsapp.com/send?phone=%2B994102307097&text=Salam',
      ),
      '994102307097',
    );
    expect(
      WhatsAppOrderService.phoneFromWhatsAppUrl(
        'https://technocare.az/contact',
      ),
      isNull,
    );
  });
}

Map<String, dynamic> _productJson({required double price}) => {
  'id': 77,
  'name': 'Sənaye sensoru',
  'slug': 'senaye-sensoru',
  'sku': 'SN-001',
  'brand': 'Siemens',
  'categories': <Map<String, dynamic>>[],
  'shortDescription': 'Sensor',
  'description': 'Sənaye üçün sensor',
  'images': ['https://technocare.az/sensor.jpg'],
  'price': price,
  'regularPrice': price,
  'salePrice': null,
  'currencyCode': 'AZN',
  'currencySymbol': '₼',
  'onSale': false,
  'inStock': true,
  'purchasable': true,
  'permalink': 'https://technocare.az/product/senaye-sensoru',
};

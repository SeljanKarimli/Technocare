import '../core/api_config.dart';
import '../models/shop_models.dart';
import '../repositories/shop_repository.dart';

class WhatsAppOrderService {
  final ShopRepository _shopRepository;

  const WhatsAppOrderService(this._shopRepository);

  Future<Uri> createOrderUri(ShopCart cart) async {
    final phone = await resolveTechnocarePhone();
    return Uri.https('wa.me', '/$phone', {'text': buildOrderMessage(cart)});
  }

  Future<Uri> createChatUri() async {
    final phone = await resolveTechnocarePhone();
    return Uri.https('wa.me', '/$phone');
  }

  Future<String> resolveTechnocarePhone() async {
    try {
      final home = await _shopRepository.getHome();
      for (final section in home.sections) {
        for (final link in section.links) {
          final phone = phoneFromWhatsAppUrl(link.url);
          if (phone != null) return phone;
        }
      }
    } catch (_) {
      // The configured fallback keeps guest ordering available while offline.
    }
    return _digits(ApiConfig.whatsAppPhone);
  }

  String buildOrderMessage(ShopCart cart) {
    final lines = <String>[
      'Salam, Technocare!',
      'Tətbiqdən aşağıdakı məhsulları sifariş vermək istəyirəm:',
      '',
    ];

    for (var index = 0; index < cart.items.length; index++) {
      final item = cart.items[index];
      final product = item.product;
      lines.add('${index + 1}. ${product.name}');
      if (product.sku.isNotEmpty) lines.add('SKU: ${product.sku}');
      if (product.brand.isNotEmpty) lines.add('Brend: ${product.brand}');
      lines.add('Miqdar: ${item.quantity}');
      if (product.price == null) {
        lines.add('Qiymət: dəqiqləşdirilməlidir');
      } else {
        lines.add('Qiymət: ${_money(product.price!, product.currencySymbol)}');
        lines.add('Məbləğ: ${_money(item.lineTotal, product.currencySymbol)}');
      }
      if (product.permalink.isNotEmpty) {
        lines.add('Məhsul: ${product.permalink}');
      }
      lines.add('');
    }

    lines.add('Ümumi məbləğ: ${_money(cart.subtotal, cart.currencySymbol)}');
    lines.add('Zəhmət olmasa mövcudluğu və çatdırılmanı təsdiqləyin.');
    return lines.join('\n');
  }

  static String? phoneFromWhatsAppUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'wa.me' || host.endsWith('.wa.me')) {
      final path = _digits(uri.path);
      return path.length >= 10 ? path : null;
    }
    if (host == 'whatsapp.com' || host.endsWith('.whatsapp.com')) {
      final queryPhone = _digits(uri.queryParameters['phone'] ?? '');
      return queryPhone.length >= 10 ? queryPhone : null;
    }
    if (uri.scheme.toLowerCase() == 'whatsapp') {
      final queryPhone = _digits(uri.queryParameters['phone'] ?? '');
      return queryPhone.length >= 10 ? queryPhone : null;
    }
    return null;
  }

  static String _digits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  String _money(double value, String symbol) =>
      '$symbol${value.toStringAsFixed(2)}';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/models/home_content.dart';
import 'package:technocare/models/shop_models.dart';
import 'package:technocare/models/site_project.dart';

void main() {
  test('homepage blocks preserve remote order and unknown types', () {
    final content = HomeContent.fromJson({
      'schemaVersion': 1,
      'updatedAt': '2026-08-31T10:00:00Z',
      'sections': [
        {'id': 'future', 'type': 'future_block', 'order': 9},
        {
          'id': 'hero',
          'type': 'hero',
          'order': 0,
          'images': ['https://technocare.az/hero.jpg'],
        },
      ],
    });

    expect(content.sections.first.type, 'hero');
    expect(content.sections.last.type, 'future_block');
    expect(content.updatedAt?.isUtc, isTrue);
  });

  test('product envelope decodes WooCommerce facets and sale data', () {
    final page = ProductPage.fromJson({
      'items': [
        {
          'id': 77,
          'name': 'Sənaye sensoru',
          'sku': 'SN-001',
          'brand': 'Siemens',
          'images': ['https://technocare.az/sensor.jpg'],
          'price': 125.5,
          'regularPrice': 150,
          'salePrice': 125.5,
          'currencySymbol': '₼',
          'onSale': true,
          'inStock': true,
          'purchasable': true,
        },
      ],
      'page': 1,
      'pageSize': 20,
      'total': 1,
      'totalPages': 1,
      'facets': {'minPrice': 10, 'maxPrice': 2000, 'inStockCount': 18},
    });

    expect(page.items.single.name, 'Sənaye sensoru');
    expect(page.items.single.onSale, isTrue);
    expect(page.items.single.displayPrice, '₼125.50');
    expect(page.minPrice, 10);
    expect(page.maxPrice, 2000);
    expect(page.inStockCount, 18);
  });

  test('project images are deduplicated and provide a primary fallback', () {
    final project = SiteProject.fromJson({
      'id': 2829,
      'name': 'STS Kran',
      'imageUrl': '',
      'images': [
        'https://technocare.az/sts-main.webp',
        'https://technocare.az/sts-main.webp',
        'https://technocare.az/sts-panel.webp',
      ],
    });

    expect(project.primaryImage, 'https://technocare.az/sts-main.webp');
    expect(project.allImages, [
      'https://technocare.az/sts-main.webp',
      'https://technocare.az/sts-panel.webp',
    ]);
  });
}

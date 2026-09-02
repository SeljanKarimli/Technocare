import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/core/image_url.dart';

void main() {
  test('Technocare uploads use a sized CDN URL then the origin', () {
    expect(
      AppImageUrl.candidates(
        'https://technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
        targetWidth: 640,
      ),
      [
        'https://i0.wp.com/technocare.az/wp-content/uploads/2025/07/pambiq.jpg?w=640&quality=85',
        'https://technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
      ],
    );
  });

  test('local proxy falls back to the CDN and original source', () {
    const origin =
        'https://technocare.az/wp-content/uploads/2025/07/pambiq.jpg';
    final proxy = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: 8765,
      path: '/image',
      queryParameters: {'url': origin},
    ).toString();

    expect(AppImageUrl.candidates(proxy), [
      proxy,
      'https://i0.wp.com/technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
      origin,
    ]);
  });

  test('bundled assets are never rewritten', () {
    const asset = 'assets/images/projects/ady-stadler.webp';
    expect(AppImageUrl.isAsset(asset), isTrue);
    expect(AppImageUrl.candidates(asset), [asset]);
  });

  test('web clients receive the validated API media gateway first', () {
    const origin =
        'https://technocare.az/wp-content/uploads/2024/04/Azərbaycan.png';
    expect(
      AppImageUrl.candidates(origin, useGateway: true).first,
      'https://api.technocare.az/api/v1/media?url=https%3A%2F%2Ftechnocare.az%2Fwp-content%2Fuploads%2F2024%2F04%2FAz%25C9%2599rbaycan.png',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/core/image_url.dart';

void main() {
  test('Technocare uploads use the CORS-enabled image CDN', () {
    expect(
      AppImageUrl.resolve(
        'https://technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
      ),
      'https://i0.wp.com/technocare.az/wp-content/uploads/2025/07/pambiq.jpg',
    );
  });
}

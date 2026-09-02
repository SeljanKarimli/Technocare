import 'package:flutter/foundation.dart';

import 'api_config.dart';

class AppImageUrl {
  AppImageUrl._();

  /// Routes technocare.az images through the local preview server on Flutter
  /// Web. Native builds and production API builds keep the original URL.
  static String resolve(String value) {
    final source = Uri.tryParse(value.trim());
    if (source == null || source.host != 'technocare.az') {
      return value;
    }

    if (source.path.startsWith('/wp-content/uploads/')) {
      return source.replace(
        scheme: 'https',
        host: 'i0.wp.com',
        path: '/technocare.az${source.path}',
      ).toString();
    }

    if (!kIsWeb) return value;

    final api = Uri.tryParse(ApiConfig.baseUrl);
    if (api == null ||
        (api.host != '127.0.0.1' && api.host.toLowerCase() != 'localhost')) {
      return value;
    }

    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: '/image',
      queryParameters: <String, String>{'url': value},
    ).toString();
  }
}

import 'api_config.dart';

class AppImageUrl {
  AppImageUrl._();

  static bool isAsset(String value) => value.trim().startsWith('assets/');

  /// Returns the image sources in retry order.
  ///
  /// Local preview proxies are kept first. Technocare uploads then use the
  /// WordPress image CDN and finally the original website URL.
  static List<String> candidates(
    String value, {
    int? targetWidth,
    bool useGateway = false,
  }) {
    final raw = value.trim();
    if (raw.isEmpty || isAsset(raw)) return <String>[raw];

    final supplied = Uri.tryParse(raw);
    if (supplied == null || !supplied.hasScheme) return <String>[raw];

    final result = <String>[];
    Uri? origin;

    if (_isLocalImageProxy(supplied)) {
      _addUnique(result, supplied.toString());
      origin = Uri.tryParse(supplied.queryParameters['url']?.trim() ?? '');
    } else if (_isTechnocareCdn(supplied)) {
      origin = _originFromCdn(supplied);
    } else if (_isTechnocare(supplied)) {
      origin = supplied;
    } else {
      _addUnique(result, supplied.toString());
    }

    if (origin != null && _isTechnocareUpload(origin)) {
      if (useGateway) {
        final gateway = _gatewayFor(origin);
        if (gateway != null) _addUnique(result, gateway.toString());
      }
      _addUnique(result, _cdnFor(origin, targetWidth: targetWidth).toString());
      _addUnique(result, origin.toString());
    } else if (origin != null) {
      _addUnique(result, origin.toString());
    }

    return result.isEmpty ? <String>[raw] : result;
  }

  /// Compatibility helper for call sites that only need the primary source.
  static String resolve(String value, {int? targetWidth}) =>
      candidates(value, targetWidth: targetWidth).first;

  static bool _isLocalImageProxy(Uri uri) =>
      (uri.host == '127.0.0.1' || uri.host.toLowerCase() == 'localhost') &&
      uri.path == '/image' &&
      uri.queryParameters.containsKey('url');

  static bool _isTechnocare(Uri uri) =>
      uri.host.toLowerCase() == 'technocare.az';

  static bool _isTechnocareCdn(Uri uri) =>
      uri.host.toLowerCase() == 'i0.wp.com' &&
      uri.path.startsWith('/technocare.az/');

  static bool _isTechnocareUpload(Uri uri) =>
      _isTechnocare(uri) && uri.path.startsWith('/wp-content/uploads/');

  static Uri? _originFromCdn(Uri uri) {
    const prefix = '/technocare.az';
    if (!uri.path.startsWith('$prefix/')) return null;
    final query = Map<String, String>.from(uri.queryParameters)
      ..remove('w')
      ..remove('quality');
    return uri.replace(
      scheme: 'https',
      host: 'technocare.az',
      path: uri.path.substring(prefix.length),
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static Uri _cdnFor(Uri origin, {int? targetWidth}) {
    final query = Map<String, String>.from(origin.queryParameters);
    if (targetWidth != null && targetWidth > 0) {
      query['w'] = targetWidth.toString();
      query['quality'] = '85';
    }
    return origin.replace(
      scheme: 'https',
      host: 'i0.wp.com',
      path: '/technocare.az${origin.path}',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static Uri? _gatewayFor(Uri origin) {
    final api = Uri.tryParse(ApiConfig.baseUrl);
    if (api == null || !api.hasScheme || api.host.isEmpty) return null;
    final isLocal =
        api.host == '127.0.0.1' || api.host.toLowerCase() == 'localhost';
    final basePath = api.path.endsWith('/')
        ? api.path.substring(0, api.path.length - 1)
        : api.path;
    return api.replace(
      path: isLocal ? '/image' : '$basePath/v1/media',
      queryParameters: <String, String>{'url': origin.toString()},
    );
  }

  static void _addUnique(List<String> values, String value) {
    if (value.isNotEmpty && !values.contains(value)) values.add(value);
  }
}

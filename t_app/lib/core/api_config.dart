class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.technocare.az/api',
  );

  static const String whatsAppPhone = String.fromEnvironment(
    'WHATSAPP_PHONE',
    defaultValue: '994102307097',
  );

  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration contentFreshness = Duration(minutes: 5);
}

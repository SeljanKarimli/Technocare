class FormValidators {
  FormValidators._();

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Ad və soyadınızı daxil edin.';
    if (text.length < 2) return 'Ad ən azı 2 simvol olmalıdır.';
    if (text.length > 100) return 'Ad 100 simvoldan uzun ola bilməz.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'E-poçt ünvanınızı daxil edin.';
    if (text.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Düzgün e-poçt ünvanı daxil edin.';
    }
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mobil nömrənizi daxil edin.';
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Mobil nömrə 7–15 rəqəmdən ibarət olmalıdır.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Şifrəni daxil edin.';
    if (value.length < 10) return 'Şifrə ən azı 10 simvol olmalıdır.';
    if (value.length > 64) return 'Şifrə 64 simvoldan uzun ola bilməz.';
    return null;
  }
}

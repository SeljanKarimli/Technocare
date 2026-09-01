import 'package:flutter_test/flutter_test.dart';
import 'package:technocare/core/form_validators.dart';

void main() {
  test('shared email validator accepts long TLD and Azerbaijani input name', () {
    expect(FormValidators.email('USER@Example.Technology'), isNull);
    expect(FormValidators.name('Əli Şükürov'), isNull);
    expect(FormValidators.email('wrong@address'), isNotNull);
  });

  test('phone and password validation enforce consistent boundaries', () {
    expect(FormValidators.phone('+994 50 123 45 67'), isNull);
    expect(FormValidators.phone('123'), isNotNull);
    expect(FormValidators.password('1234567890'), isNull);
    expect(FormValidators.password('123456'), isNotNull);
  });
}

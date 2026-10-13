import 'package:flutter_test/flutter_test.dart';
import 'package:country_picker/country_picker.dart';

String extractNationalDigits(String rawText, String countryCode) {
  var digits = rawText.replaceAll(RegExp(r'\D'), '');
  final cc = countryCode.toUpperCase();
  final country = Country.tryParse(cc);
  final phoneCode = country?.phoneCode;
  if (phoneCode != null && digits.startsWith(phoneCode)) {
    final remainder = digits.substring(phoneCode.length);
    // Only strip prefix if digits was longer than a typical national number
    if (remainder.length >= 6) {
      digits = remainder;
    }
  }
  return digits;
}

void main() {
  test('extractNationalDigits strips international prefix when pasted', () {
    expect(extractNationalDigits('+223 70 00 00 90', 'ML'), '70000090');
    expect(extractNationalDigits('22370000090', 'ML'), '70000090');
    expect(extractNationalDigits('70000090', 'ML'), '70000090');
    expect(extractNationalDigits('+225 07 00 00 00 00', 'CI'), '0700000000');
    expect(extractNationalDigits('+33 6 12 34 56 78', 'FR'), '612345678');
  });
}

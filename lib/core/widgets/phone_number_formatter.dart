import 'package:country_picker/country_picker.dart';
import 'package:flutter/services.dart';

/// Formateur de numéro de téléphone national selon le pays d'Afrique de l'Ouest / Diaspora.
class PhoneNumberTextInputFormatter extends TextInputFormatter {
  final String countryCode;

  const PhoneNumberTextInputFormatter(this.countryCode);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = extractNationalDigits(newValue.text, countryCode);
    final formatted = formatNumber(rawDigits, countryCode);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Extrait les chiffres nationaux en retirant le préfixe pays s'il a été collé ou saisi.
  static String extractNationalDigits(String rawText, String countryCode) {
    var digits = rawText.replaceAll(RegExp(r'\D'), '');
    final cc = countryCode.toUpperCase();
    final country = Country.tryParse(cc);
    final phoneCode = country?.phoneCode;
    if (phoneCode != null && digits.startsWith(phoneCode)) {
      final remainder = digits.substring(phoneCode.length);
      // Ne retire l'indicatif que s'il reste au moins 6 chiffres (numéro national complet)
      if (remainder.length >= 6) {
        digits = remainder;
      }
    }
    return digits;
  }

  static String formatNumber(String digits, String countryCode) {
    if (digits.isEmpty) return '';
    final cc = countryCode.toUpperCase();

    // 1. Mali, Burkina Faso, Niger (8 chiffres : 2-2-2-2, ex: 70 00 00 90)
    if (cc == 'ML' || cc == 'BF' || cc == 'NE') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 8; i++) {
        if (i > 0 && i % 2 == 0) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 2. Ghana (10 chiffres ex: 050 706 6762, ou 9 chiffres: 50 706 6762)
    if (cc == 'GH') {
      final buffer = StringBuffer();
      if (digits.startsWith('0')) {
        for (int i = 0; i < digits.length && i < 10; i++) {
          if (i == 3 || i == 6) buffer.write(' ');
          buffer.write(digits[i]);
        }
      } else {
        for (int i = 0; i < digits.length && i < 9; i++) {
          if (i == 2 || i == 5) buffer.write(' ');
          buffer.write(digits[i]);
        }
      }
      return buffer.toString();
    }

    // 3. Côte d'Ivoire & France (10 chiffres : 2-2-2-2-2, ex: 07 00 00 00 00 ou 06 12 34 56 78)
    if (cc == 'CI' || cc == 'FR') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 10; i++) {
        if (i > 0 && i % 2 == 0) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 4. Sénégal (9 chiffres : 2-3-2-2, ex: 77 123 45 67)
    if (cc == 'SN') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 9; i++) {
        if (i == 2 || i == 5 || i == 7) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // 5. Guinée (9 chiffres : 3-2-2-2, ex: 620 00 00 00)
    if (cc == 'GN') {
      final buffer = StringBuffer();
      for (int i = 0; i < digits.length && i < 9; i++) {
        if (i == 3 || i == 5 || i == 7) buffer.write(' ');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }

    // Défaut : groupements de 3 chiffres
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 15; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String getPhoneHint(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'ML':
        return '70 00 00 90';
      case 'GH':
        return '050 706 6762';
      case 'CI':
        return '07 00 00 00 00';
      case 'SN':
        return '77 123 45 67';
      case 'BF':
        return '70 00 00 00';
      case 'GN':
        return '620 00 00 00';
      case 'FR':
        return '06 12 34 56 78';
      default:
        return '65 43 21 00';
    }
  }
}

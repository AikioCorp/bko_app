import 'package:flutter/services.dart';

/// Formateur de saisie premium pour les noms et prénoms.
///
/// Met automatiquement en majuscule :
/// - La première lettre du texte (au début)
/// - La première lettre suivant chaque espace
/// - La première lettre suivant un tiret (ex. Jean-Marc)
/// - La première lettre suivant une apostrophe (ex. N'Diaye, O'Connor)
///
/// Préserve rigoureusement la position du curseur, la sélection active et la
/// composition clavier (IME) sans sauts ni décalages.
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  final bool capitalizeAfterHyphen;
  final bool capitalizeAfterApostrophe;

  const CapitalizeWordsInputFormatter({
    this.capitalizeAfterHyphen = true,
    this.capitalizeAfterApostrophe = true,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formattedText = capitalize(
      newValue.text,
      capitalizeAfterHyphen: capitalizeAfterHyphen,
      capitalizeAfterApostrophe: capitalizeAfterApostrophe,
    );

    // Si aucune transformation n'a eu lieu, retourner la valeur sans allocation
    if (formattedText == newValue.text) {
      return newValue;
    }

    // Préserver la sélection et la composition de façon sécurisée
    final selection = _clampSelection(newValue.selection, formattedText.length);
    final composing = _clampRange(newValue.composing, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: selection,
      composing: composing,
    );
  }

  /// Fonction statique de capitalisation des mots.
  static String capitalize(
    String text, {
    bool capitalizeAfterHyphen = true,
    bool capitalizeAfterApostrophe = true,
  }) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final isSpace = char == ' ' || char == '\t' || char == '\n';
      final isHyphen = capitalizeAfterHyphen && char == '-';
      final isApostrophe =
          capitalizeAfterApostrophe && (char == "'" || char == '’');

      if (isSpace || isHyphen || isApostrophe) {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static TextSelection _clampSelection(TextSelection selection, int maxLength) {
    if (!selection.isValid) return selection;
    final baseOffset = selection.baseOffset.clamp(0, maxLength);
    final extentOffset = selection.extentOffset.clamp(0, maxLength);
    return selection.copyWith(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
    );
  }

  static TextRange _clampRange(TextRange range, int maxLength) {
    if (!range.isValid) return range;
    final start = range.start.clamp(0, maxLength);
    final end = range.end.clamp(0, maxLength);
    return TextRange(start: start, end: end);
  }
}

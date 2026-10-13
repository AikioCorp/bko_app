import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bko_app/core/widgets/capitalize_words_input_formatter.dart';

void main() {
  group('CapitalizeWordsInputFormatter Tests', () {
    const formatter = CapitalizeWordsInputFormatter();

    test('1. Capitalise automatiquement le premier caractère', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('A'));
      expect(result.selection.baseOffset, equals(1));
    });

    test('2. Capitalise après un espace', () {
      const oldValue = TextEditingValue(
        text: 'Awa ',
        selection: TextSelection.collapsed(offset: 4),
      );
      const newValue = TextEditingValue(
        text: 'Awa t',
        selection: TextSelection.collapsed(offset: 5),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Awa T'));
      expect(result.selection.baseOffset, equals(5));
    });

    test('3. Capitalise un texte complet avec plusieurs mots (ex: copier-coller)', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'amadou lamine fofana',
        selection: TextSelection.collapsed(offset: 20),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Amadou Lamine Fofana'));
      expect(result.selection.baseOffset, equals(20));
    });

    test('4. Gère les espaces multiples et espaces de début', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '  awa   traoré  ',
        selection: TextSelection.collapsed(offset: 16),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('  Awa   Traoré  '));
      expect(result.selection.baseOffset, equals(16));
    });

    test('5. Capitalise après un tiret (noms composés)', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'jean-paul traoré',
        selection: TextSelection.collapsed(offset: 16),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Jean-Paul Traoré'));
    });

    test('6. Capitalise après une apostrophe (droite ou typographique)', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: "n'diaye d'almeida",
        selection: TextSelection.collapsed(offset: 17),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals("N'Diaye D'Almeida"));
    });

    test('7. Gère correctement les caractères accentués en début et après espace', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'élise étienne',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Élise Étienne'));
    });

    test('8. Conserve les majuscules intentionnelles au milieu des mots (ex: McDonald)', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'cheick mcDonald',
        selection: TextSelection.collapsed(offset: 15),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Cheick McDonald'));
    });

    test('9. Préserve la position du curseur au milieu du texte sans saut', () {
      // L'utilisateur insère "b" entre "Awa " et "Traoré"
      const oldValue = TextEditingValue(
        text: 'Awa Traoré',
        selection: TextSelection.collapsed(offset: 4),
      );
      const newValue = TextEditingValue(
        text: 'Awa bTraoré',
        selection: TextSelection.collapsed(offset: 5),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Awa BTraoré'));
      expect(result.selection.baseOffset, equals(5));
      expect(result.selection.extentOffset, equals(5));
    });

    test('10. Gère la suppression et le texte vide sans erreur', () {
      const oldValue = TextEditingValue(
        text: 'A',
        selection: TextSelection.collapsed(offset: 1),
      );
      const emptyValue = TextEditingValue.empty;

      final resultEmpty = formatter.formatEditUpdate(oldValue, emptyValue);
      expect(resultEmpty.text, equals(''));
      expect(resultEmpty.selection, equals(emptyValue.selection));

      const deletedValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      final resultDeleted = formatter.formatEditUpdate(oldValue, deletedValue);
      expect(resultDeleted.text, equals(''));
      expect(resultDeleted.selection.baseOffset, equals(0));
    });
  });
}

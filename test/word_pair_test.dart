import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';

/// definition-mode T1: the definition fields on a word row and the
/// mode-independent "filled" rule (spec AC-11, AC-12, AC-13).
void main() {
  group('definition fields', () {
    test('default to empty / null / false', () {
      final pair = WordPair(word: 'claim');
      expect(pair.definition, '');
      expect(pair.definitionOptionsJson, isNull);
      expect(pair.definitionMarkedFilled, isFalse);
    });

    test('survive a JSON round trip', () {
      final pair = WordPair(
        word: 'tenacious',
        translation: 'наполегливий',
        definition: 'persistent in maintaining something valued',
        definitionOptionsJson: '{"senses":["a","b"]}',
        definitionMarkedFilled: true,
      );
      final back = WordPair.fromJson(pair.toJson());
      expect(back.definition, pair.definition);
      expect(back.definitionOptionsJson, pair.definitionOptionsJson);
      expect(back.definitionMarkedFilled, isTrue);
    });

    test('survive copy()', () {
      final pair = WordPair(
        word: 'curse',
        definition: 'a prayer for harm',
        definitionOptionsJson: '{"senses":["x"]}',
        definitionMarkedFilled: true,
      );
      final copy = pair.copy();
      expect(copy.definition, 'a prayer for harm');
      expect(copy.definitionOptionsJson, '{"senses":["x"]}');
      expect(copy.definitionMarkedFilled, isTrue);
    });

    test('a row saved before this feature loads with an empty definition', () {
      final legacy = WordPair.fromJson({
        'word': 'direct',
        'translation': 'прямий',
        'hasTranslationOptions': false,
        'translationOptionsJson': null,
        'wordMarkedFilled': false,
        'translationMarkedFilled': true,
      });
      expect(legacy.definition, '');
      expect(legacy.definitionOptionsJson, isNull);
      expect(legacy.definitionMarkedFilled, isFalse);
      expect(legacy.translation, 'прямий');
    });
  });

  group('isFilled', () {
    test('word + definition without translation counts as filled', () {
      expect(WordPair(word: 'gated', definition: 'having a gate').isFilled,
          isTrue);
    });

    test('word + translation without definition counts as filled', () {
      expect(WordPair(word: 'gated', translation: 'закритий').isFilled, isTrue);
    });

    test('a word alone, or details without a word, is not filled', () {
      expect(WordPair(word: 'gated').isFilled, isFalse);
      expect(WordPair(translation: 'закритий', definition: 'x').isFilled,
          isFalse);
      expect(WordPair(word: '  ', definition: '  ').isFilled, isFalse);
    });

    test('a row with only a definition is not empty', () {
      expect(WordPair(definition: 'only a definition').isEmpty, isFalse);
    });
  });
}

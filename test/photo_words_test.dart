import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// definition-mode T9: a photo word's context description becomes the row's
/// definition in every mode, and never stands in for the translation
/// (spec AC-09, AC-10).
void main() {
  test('translation and description fill both fields', () {
    final pair = wordPairFromPhoto(VocabWord(
      word: 'tenacious',
      translation: 'наполегливий',
      description: 'refusing to give up',
    ));
    expect(pair.word, 'tenacious');
    expect(pair.translation, 'наполегливий');
    expect(pair.definition, 'refusing to give up');
    expect(pair.wordMarkedFilled, isTrue);
    expect(pair.translationMarkedFilled, isTrue);
    expect(pair.definitionMarkedFilled, isTrue);
  });

  test('a description without a translation stays a definition', () {
    final pair = wordPairFromPhoto(
        VocabWord(word: 'gated', description: 'having a gate'));
    expect(pair.translation, '');
    expect(pair.translationMarkedFilled, isFalse);
    expect(pair.definition, 'having a gate');
    expect(pair.definitionMarkedFilled, isTrue);
  });

  test('a word with neither keeps both empty', () {
    final pair = wordPairFromPhoto(VocabWord(word: 'claim'));
    expect(pair.translation, '');
    expect(pair.definition, '');
    expect(pair.definitionMarkedFilled, isFalse);
  });
}

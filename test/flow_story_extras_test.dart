import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_stories.dart';

/// learn-welcome T9 (AC-12): the hints a flow story run sends with its words.
WordPair _row(String word, {String context = '', String translation = 'т', WordOrigin? origin}) =>
    WordPair(word: word, translation: translation, rowId: 'r$word', context: context)
      ..origin = origin ?? WordOrigin();

void main() {
  test('a typed word with nothing else gives only its word', () {
    expect(storyExtras([_row('cat')]), [
      {'word': 'cat'},
    ]);
  });

  test('context is sent when not empty', () {
    expect(storyExtras([_row('cat', context: ' The cat sat. ')]).single, {
      'word': 'cat',
      'context': 'The cat sat.',
    });
  });

  test('source: film with season and episode, film alone, photo, Quizlet set', () {
    WordOrigin o(SourceType t, {String name = '', int? s, int? e}) => WordOrigin()
      ..typeOfSource = t
      ..movieName = name
      ..season = s
      ..episode = e;
    final extras = storyExtras([
      _row('a', origin: o(SourceType.movie, name: 'Friends', s: 2, e: 5)),
      _row('b', origin: o(SourceType.movie, name: 'Up')),
      _row('c', origin: o(SourceType.image)),
      _row('d', origin: o(SourceType.set)),
    ]);
    expect([for (final e in extras) e['source']], ['film Friends S02E05', 'film Up', 'a photo', 'a Quizlet set']);
  });

  test('the translation goes only when the learner edited it', () {
    final edited = WordOrigin()..wasTranslationEditByUser = true;
    final extras = storyExtras([_row('a', translation: 'кіт', origin: edited), _row('b', translation: 'пес')]);
    expect(extras[0]['translation'], 'кіт');
    expect(extras[1].containsKey('translation'), isFalse);
  });

  test('a row without a word is left out', () {
    expect(storyExtras([_row(' ')]), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/gap_question.dart';

/// learn-fill-the-gaps S-43: the gap question builder (AC-02, AC-16 – AC-19, AC-30).
void main() {
  WordPair w(String word, {String translation = 'переклад', String rowId = 'r1'}) =>
      WordPair(word: word, translation: translation, rowId: rowId);

  FilmDialogue d(List<String> lines, {List<String> ids = const ['r1'], bool hidden = false}) => FilmDialogue()
    ..id = 'd'
    ..lines = lines
    ..wordRowIds = ids
    ..hidden = hidden;

  GapQuestion? gap(String word, String text, {String translation = 'переклад'}) =>
      gapFromText(w(word, translation: translation), text, GapSource.dialogue);

  group('gapFromText', () {
    test('a plain sentence: one gap standing for the stored form', () {
      final q = gap('harbour', 'The harbour is closed tonight.')!;
      expect(q.rowId, 'r1');
      expect(q.answer, 'harbour');
      expect(q.sentence, 'The harbour is closed tonight.');
      expect(q.masked, 'The ___ is closed tonight.');
      expect(q.cue, 'переклад');
      expect(q.source, GapSource.dialogue);
    });

    test('AC-16: cut to the one sentence around the word, leading dash dropped', () {
      expect(gap('harbour', '- Wait. The harbour is closed tonight. Go home.')!.masked, 'The ___ is closed tonight.');
      expect(gap('harbour', '— The harbour is closed tonight now!')!.sentence, 'The harbour is closed tonight now!');
      expect(gap('harbour', '– The harbour is closed tonight now?')!.masked, 'The ___ is closed tonight now?');
    });

    test('the answer and the cue come from the trimmed word and translation; any letter case', () {
      final q = gap(' Harbour ', 'The HARBOUR is closed tonight.', translation: ' порт ')!;
      expect(q.answer, 'Harbour');
      expect(q.cue, 'порт');
      expect(q.masked, 'The ___ is closed tonight.');
    });

    test('AC-02: a phrase makes one gap for the whole phrase', () {
      final q = gap('give up', 'You must never give up on your dream.')!;
      expect(q.masked, 'You must never ___ on your dream.');
    });

    test('AC-02: a cue holding the English word shows ___', () {
      final q = gap('harbour', 'The harbour is closed tonight.', translation: 'harbour (порт)')!;
      expect(q.cue, '___ (порт)');
    });

    test('AC-17: the word twice, or twice with another form, is rejected; the next sentence wins', () {
      expect(gap('walk', 'I walk, you walk.'), isNull);
      expect(gap('walk', 'She walks to work every day.'), isNull);
      expect(gap('walk', 'I walk to work and she walks too.'), isNull);
      expect(gap('walk', 'She walks to work every day. Lets walk to the station now.')!.sentence,
          'Lets walk to the station now.');
    });

    test('AC-17: another form of the word is not the stored form: rejected', () {
      expect(gap('walk', 'We walked to the station together.'), isNull);
      expect(gap('walk', 'We were walking to the station.'), isNull);
      expect(gap('give up', 'He gave up the fight there.'), isNull);
      expect(gap('give up', 'She gives up the fight there.'), isNull);
    });

    test('AC-18: fewer than 4 or more than 20 words, or over 160 characters, is rejected', () {
      expect(gap('received', 'Received!'), isNull);
      expect(gap('received', 'He received it.'), isNull);
      expect(gap('received', 'He received it today.'), isNotNull);
      final long = 'He received ${List.filled(18, 'x').join(' ')} too';
      expect(gap('received', long), isNull); // 21 words
      final twenty = 'He received ${List.filled(17, 'x').join(' ')} too';
      expect(gap('received', twenty), isNotNull);
      final wide = 'He received ${List.filled(13, 'abcdefghijkl').join(' ')} end'; // 16 words, > 160 chars
      expect(wide.length, greaterThan(160));
      expect(gap('received', wide), isNull);
    });

    test('AC-18: a phrase counts as one word of the gap sentence', () {
      expect(gap('give up', 'Never give up on it'), isNotNull);
      expect(gap('give up', 'Never give up now'), isNull);
    });

    test('null for an empty word or translation', () {
      expect(gap('', 'The harbour is closed tonight.'), isNull);
      expect(gap('harbour', 'The harbour is closed tonight.', translation: '  '), isNull);
    });

    test('sentence ends: quotes and brackets close the sentence; ellipsis ends it', () {
      expect(gap('harbour', 'He said "The harbour is closed." Then left.')!.sentence, 'He said "The harbour is closed."');
      expect(gap('harbour', 'Well… the harbour is closed again.')!.sentence, 'the harbour is closed again.');
    });

    test('no text without the word gives a question', () {
      expect(gap('harbour', 'Nothing to see here at all.'), isNull);
      expect(gap('harbour', ''), isNull);
    });

    test('AC-30: building twice gives the same question', () {
      final a = gap('harbour', 'The harbour is closed tonight.')!;
      final b = gap('harbour', 'The harbour is closed tonight.')!;
      expect((a.sentence, a.masked, a.cue, a.answer), (b.sentence, b.masked, b.cue, b.answer));
    });

    test('fairness: every question has one gap and shows the word nowhere else', () {
      const lines = [
        'I walk, you walk.',
        'She walks to work every day.',
        'We walked home late tonight.',
        'Let us walk to the station now.',
        'Walk!',
        'Do not walk alone at night, my friend.',
        'Walk with me. Walk with me please.',
      ];
      for (final line in lines) {
        final q = gap('walk', line, translation: 'to walk (ходити)');
        if (q == null) continue;
        expect('___'.allMatches(q.masked).length, 1, reason: line);
        expect(q.masked.toLowerCase(), isNot(contains('walk')), reason: line);
        expect(q.cue.toLowerCase(), isNot(contains('walk')), reason: line);
      }
    });
  });

  group('gapFromDialogues', () {
    test('AC-14: the first qualifying line in dialogue then line order', () {
      final q = gapFromDialogues(w('harbour'), [
        d(['Hello there.', 'The harbour is closed tonight.', 'The harbour is open today again.']),
      ])!;
      expect(q.sentence, 'The harbour is closed tonight.');
      expect(q.source, GapSource.dialogue);
    });

    test('AC-19: hidden, unlinked and other-session dialogues are not used; an empty rowId gives null', () {
      const line = 'The harbour is closed tonight.';
      expect(gapFromDialogues(w('harbour'), [d([line], hidden: true)]), isNull);
      expect(gapFromDialogues(w('harbour'), [d([line], ids: ['r2'])]), isNull);
      expect(gapFromDialogues(w('harbour'), const []), isNull);
      expect(gapFromDialogues(w('harbour', rowId: ''), [d([line], ids: [''])]), isNull);
    });

    test('a line that does not qualify is skipped for the next one, in the next dialogue too', () {
      final q = gapFromDialogues(w('walk'), [
        d(['I walk, you walk.', 'She walks to work every day.']),
        d(['Let us walk to the station now.']),
      ])!;
      expect(q.sentence, 'Let us walk to the station now.');
    });
  });
}

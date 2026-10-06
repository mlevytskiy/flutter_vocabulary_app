import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_cards.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_set_parser.dart';

void main() {
  group('proposeWords', () {
    test(
        'turns a card into a word with empty translation and back as definition',
        () {
      final r = proposeWords(
        [const QuizletCard(term: 'deadline', back: 'a time limit')],
        const [],
        1,
      );
      expect(r.words, hasLength(1));
      expect(r.words.single.word, 'deadline');
      expect(r.words.single.translation, '');
      expect(r.words.single.description, 'a time limit');
      expect(r.skipped, 0);
    });

    test('definition is back, a new line, then the example', () {
      final r = proposeWords(
        [const QuizletCard(term: 'a', back: 'b', example: 'c d')],
        const [],
        null,
      );
      expect(r.words.single.description, 'b\nc d');
    });

    test('card without a back is proposed with an empty definition (AC-09)',
        () {
      final r = proposeWords([const QuizletCard(term: 'a')], const [], null);
      expect(r.words.single.description, '');
    });

    test('image-only card is dropped and counted as skipped (AC-09)', () {
      final r = proposeWords(
        [
          const QuizletCard(term: '', back: 'pic'),
          const QuizletCard(term: '  \n ', back: 'pic'),
          const QuizletCard(term: 'a', back: 'b'),
        ],
        const [],
        3,
      );
      expect(r.words.map((w) => w.word), ['a']);
      expect(r.skipped, 2);
      expect(r.found, 3);
    });

    test('line breaks become "; " in term and back (AC-09)', () {
      final r = proposeWords(
        [const QuizletCard(term: 'a\nb', back: 'x\r\ny\n\nz')],
        const [],
        null,
      );
      expect(r.words.single.word, 'a; b');
      expect(r.words.single.description, 'x; y; z');
    });

    test('600-character multi-line back is cut to 500 ending with "…"', () {
      final back = List.filled(10, 'a' * 59).join('\n'); // 590 + 9 breaks
      final r = proposeWords(
        [QuizletCard(term: 't' * 700, back: back)],
        const [],
        null,
      );
      final w = r.words.single;
      expect(w.word.length, 500);
      expect(w.word.endsWith('…'), isTrue);
      expect(w.description!.length, 500);
      expect(w.description!.endsWith('…'), isTrue);
      expect(w.description!.contains('\n'), isFalse);
      expect(w.description!.startsWith('${'a' * 59}; '), isTrue);
    });

    test('text of exactly 500 characters is kept whole', () {
      final r = proposeWords(
        [QuizletCard(term: 'a' * 500, back: 'b' * 500)],
        const [],
        null,
      );
      expect(r.words.single.word, 'a' * 500);
      expect(r.words.single.description, 'b' * 500);
    });

    test('definition with a long example stays within 500', () {
      final r = proposeWords(
        [QuizletCard(term: 'a', back: 'b' * 400, example: 'e' * 400)],
        const [],
        null,
      );
      expect(r.words.single.description!.length, 500);
      expect(r.words.single.description!.endsWith('…'), isTrue);
    });

    test('"Reluctant." is skipped when the session holds "reluctant" (AC-10)',
        () {
      final r = proposeWords(
        [const QuizletCard(term: 'Reluctant.', back: 'unwilling')],
        const ['reluctant'],
        1,
      );
      expect(r.words, isEmpty);
      expect(r.skipped, 1);
    });

    test('repeated term keeps the first card (AC-10)', () {
      final r = proposeWords(
        [
          const QuizletCard(term: 'deadline', back: 'first'),
          const QuizletCard(term: ' Deadline! ', back: 'second'),
          const QuizletCard(term: 'other', back: 'o'),
        ],
        const [],
        3,
      );
      expect(r.words.map((w) => w.word), ['deadline', 'other']);
      expect(r.words.first.description, 'first');
      expect(r.skipped, 1);
    });

    test('only one closing mark is ignored', () {
      final r = proposeWords(
        [
          const QuizletCard(term: 'what?!'),
          const QuizletCard(term: 'what'),
        ],
        const [],
        null,
      );
      expect(r.words, hasLength(2));
    });

    test(
        'found is counted before skipping and stated is passed through (AC-08)',
        () {
      final r = proposeWords(
        [
          const QuizletCard(term: 'a'),
          const QuizletCard(term: 'a'),
          const QuizletCard(term: ''),
        ],
        const ['x'],
        120,
      );
      expect(r.found, 3);
      expect(r.stated, 120);
      expect(r.skipped, 2);
      expect(r.readLine, 'Read 3 of 120 cards');
    });

    test('no "of" line when found equals stated or the page states none', () {
      final cards = [const QuizletCard(term: 'a')];
      expect(proposeWords(cards, const [], 1).readLine, isNull);
      expect(proposeWords(cards, const [], null).readLine, isNull);
      expect(proposeWords(cards, const [], null).stated, isNull);
    });

    test('every card skipped gives no words (AC-04b)', () {
      final r = proposeWords(
        [const QuizletCard(term: 'a'), const QuizletCard(term: '')],
        const ['A'],
        2,
      );
      expect(r.words, isEmpty);
      expect(r.skipped, 2);
    });
  });
}

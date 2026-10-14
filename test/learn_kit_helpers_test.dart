import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/question_builder.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/split_rounds.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_match.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/word_marks.dart';

/// learn-kit: the pure helpers every exercise shares (S-07, S-09, S-10, S-12).
void main() {
  group('splitRounds (AC-09, S-07)', () {
    List<int> sizes(int n, int min, int max) => [
          for (final r in splitRounds(List.generate(n, (i) => i), min: min, max: max)) r.length,
        ];

    test('the spec examples', () {
      expect(sizes(7, 3, 6), [4, 3]);
      expect(sizes(13, 3, 9), [7, 6]);
      expect(sizes(2, 3, 6), isEmpty);
      expect(sizes(0, 3, 6), isEmpty);
    });

    test('fewest rounds, sizes differ by at most one, larger first, never under min', () {
      for (final (min, max) in [(3, 6), (3, 9), (3, 5)]) {
        for (var n = min; n <= 60; n++) {
          final s = sizes(n, min, max);
          expect(s.length, (n / max).ceil(), reason: '$n at $min-$max');
          expect(s.reduce((a, b) => a + b), n);
          expect(s.every((x) => x >= min && x <= max), isTrue, reason: '$n: $s');
          expect(s.reduce((a, b) => a > b ? a : b) - s.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
          for (var i = 1; i < s.length; i++) {
            expect(s[i], lessThanOrEqualTo(s[i - 1]));
          }
        }
      }
    });

    test('word order is kept and the same input gives the same split', () {
      final items = List.generate(11, (i) => 'w$i');
      final a = splitRounds(items, min: 3, max: 6);
      expect(a.expand((r) => r).toList(), items);
      expect(splitRounds(items, min: 3, max: 6), a);
    });

    test('a max under 2 × min − 1 is a programming error', () {
      expect(() => splitRounds([1, 2, 3], min: 3, max: 4), throwsA(isA<AssertionError>()));
    });
  });

  group('matchTyped (AC-11, AC-12, S-10)', () {
    test('case, spaces and a leading to / a / an / the on either side do not matter', () {
      expect(matchTyped('Cat', 'the cat'), TypedMatch.right);
      expect(matchTyped('run', 'to run'), TypedMatch.right);
      expect(matchTyped('ice  cream ', 'Ice cream'), TypedMatch.right);
      expect(matchTyped('the  Cat', 'cat'), TypedMatch.right);
      expect(matchTyped('an apple', 'apple'), TypedMatch.right);
      expect(matchTyped('to run', 'run'), TypedMatch.right);
    });

    test('one slip on a word of five or more letters is almost', () {
      expect(matchTyped('recieve', 'receive'), TypedMatch.almost, reason: 'swap of neighbours');
      expect(matchTyped('receve', 'receive'), TypedMatch.almost, reason: 'a dropped letter');
      expect(matchTyped('receivve', 'receive'), TypedMatch.almost, reason: 'an added letter');
      expect(matchTyped('recaive', 'receive'), TypedMatch.almost, reason: 'a changed letter');
    });

    test('short words, other forms and two edits are wrong', () {
      expect(matchTyped('cta', 'cat'), TypedMatch.wrong);
      expect(matchTyped('walked', 'walk'), TypedMatch.wrong);
      expect(matchTyped('receives', 'receive'), TypedMatch.wrong, reason: 'another form, not a slip');
      expect(matchTyped('received', 'receive'), TypedMatch.wrong);
      expect(matchTyped('recive', 'receipt'), TypedMatch.wrong);
      expect(matchTyped('', 'cat'), TypedMatch.wrong);
      expect(matchTyped('dog', 'cat'), TypedMatch.wrong);
    });

    test('almost counts as right', () {
      expect(TypedMatch.almost.isRight, isTrue);
      expect(TypedMatch.right.isRight, isTrue);
      expect(TypedMatch.wrong.isRight, isFalse);
    });
  });

  group('maskWord, holdsWordOnce, boldWord (AC-15, AC-16, S-12)', () {
    test('every whole-word place, with -s/-es/-ed/-ing, in any case, becomes ___', () {
      expect(maskWord('The Cat saw two cats.', 'cat'), 'The ___ saw two ___.');
      expect(maskWord('She walked and walks.', 'walk'), 'She ___ and ___.');
      expect(maskWord('A category of things.', 'cat'), 'A category of things.');
      expect(maskWord('I gave up and then gave it up.', 'give up'), 'I gave up and then gave it up.');
      expect(maskWord('We give up now.', 'give up'), 'We ___ now.');
    });

    test('a text must hold the word exactly once', () {
      expect(holdsWordOnce('The cat sat.', 'cat'), isTrue);
      expect(holdsWordOnce('The cat and the cat.', 'cat'), isFalse);
      expect(holdsWordOnce('A category.', 'cat'), isFalse);
    });

    test('boldWord bolds exactly the places and keeps markup as plain characters', () {
      final spans = boldWord('**Cats** like a cat_egory, not <b>cat</b>.', 'cat');
      expect(spans.map((s) => s.text).join(), '**Cats** like a cat_egory, not <b>cat</b>.');
      final bold = [for (final s in spans) if (s.style?.fontWeight == FontWeight.bold) s.text];
      expect(bold, ['Cats', 'cat', 'cat']);
      expect(spans.every((s) => s.children == null), isTrue);
    });

    test('a text without the word is one plain span', () {
      final spans = boldWord('Nothing here.', 'cat');
      expect(spans.length, 1);
      expect(spans.single.style, isNull);
    });
  });

  group('buildQuestion (AC-17 – AC-19, S-09)', () {
    var n = 0;
    WordPair w(String word, String translation, {String definition = ''}) =>
        WordPair(word: word, translation: translation, definition: definition, rowId: 'id${n++}');

    final cat = w('cat', 'кіт', definition: 'A small cat-like pet.');
    final group = [cat, w('dog', 'пес'), w('bird', 'птах'), w('fish', 'риба')];
    final others = [w('horse', 'кінь'), w('cow', 'корова'), w('goat', 'коза')];

    test('word → translations: the word and four distinct translations, one right', () {
      final q = buildQuestion(cat, QuestionPool(group: group, others: others), QuestionKind.wordToTranslation, Random(1))!;
      expect(q.rowId, cat.rowId);
      expect(q.prompt, 'cat');
      expect(q.options.length, 4);
      expect(q.options.toSet().length, 4);
      expect(q.options[q.rightIndex], 'кіт');
      expect(q.options.where((o) => o == 'кіт').length, 1);
    });

    test("meaning → words: the definition with the word masked, four distinct words", () {
      final q = buildQuestion(cat, QuestionPool(group: group, others: others), QuestionKind.meaningToWord, Random(1))!;
      expect(q.prompt, 'A small ___-like pet.');
      expect(q.options.length, 4);
      expect(q.options[q.rightIndex], 'cat');
      final noDef = group[1];
      expect(buildQuestion(noDef, QuestionPool(group: group, others: others), QuestionKind.meaningToWord, Random(1))!.prompt, 'пес');
    });

    test("the group's words come before the session's other words", () {
      for (var seed = 0; seed < 20; seed++) {
        final q = buildQuestion(cat, QuestionPool(group: group, others: others), QuestionKind.wordToTranslation, Random(seed))!;
        expect(q.options.toSet(), {'кіт', 'пес', 'птах', 'риба'}, reason: 'seed $seed');
      }
      final small = [cat, group[1]];
      final q = buildQuestion(cat, QuestionPool(group: small, others: others), QuestionKind.wordToTranslation, Random(3))!;
      expect(q.options, contains('пес'));
    });

    test('no option equals another ignoring case and spaces; no translation, no option', () {
      final clash = [
        cat,
        w('kitty', ' Кіт '),
        w('dog', 'пес'),
        w('hound', 'ПЕС'),
        w('blank', ''),
        w('bird', 'птах'),
      ];
      final q = buildQuestion(cat, QuestionPool(group: clash, others: [w('cow', 'корова')]), QuestionKind.wordToTranslation, Random(2))!;
      final normal = q.options.map((o) => o.trim().toLowerCase()).toSet();
      expect(normal.length, 4);
      expect(normal, isNot(contains('')));
      expect(q.options.where((o) => o.trim().toLowerCase() == 'кіт').length, 1);
    });

    test('a word for which four distinct options cannot be found gets no question', () {
      final tiny = [cat, w('dog', 'пес'), w('dog2', 'пес')];
      expect(buildQuestion(cat, QuestionPool(group: tiny, others: const []), QuestionKind.wordToTranslation, Random(1)), isNull);
      expect(buildQuestion(w('x', ''), QuestionPool(group: group, others: others), QuestionKind.wordToTranslation, Random(1)), isNull);
    });

    // S-26 (learn-pick-the-answer AC-09): no second right answer.
    test('word → translation never offers a row with the same English word (a homograph)', () {
      final bank = w('bank', 'банк');
      final pool = QuestionPool(
          group: [bank, w('Bank ', 'берег'), w('dog', 'пес'), w('bird', 'птах'), w('fish', 'риба')], others: const []);
      for (var seed = 0; seed < 50; seed++) {
        final q = buildQuestion(bank, pool, QuestionKind.wordToTranslation, Random(seed))!;
        expect(q.options, isNot(contains('берег')), reason: 'seed $seed');
        expect(q.options.toSet(), {'банк', 'пес', 'птах', 'риба'});
      }
    });

    test('meaning → word never offers a row with the same meaning', () {
      final kitty = w('kitty', 'кіт');
      final pet = w('cat', 'кіт');
      final pool = QuestionPool(group: [pet, kitty, w('dog', 'пес'), w('bird', 'птах'), w('fish', 'риба')], others: const []);
      for (var seed = 0; seed < 50; seed++) {
        final q = buildQuestion(pet, pool, QuestionKind.meaningToWord, Random(seed))!;
        expect(q.options, isNot(contains('kitty')), reason: 'seed $seed');
      }
      // Same definition, different translations: still the same meaning.
      final a = w('car', 'авто', definition: 'A road vehicle.');
      final b = w('auto', 'машина', definition: ' a road  vehicle. ');
      final p2 = QuestionPool(group: [a, b, w('dog', 'пес'), w('bird', 'птах')], others: const []);
      expect(buildQuestion(a, p2, QuestionKind.meaningToWord, Random(1)), isNull,
          reason: 'only 2 wrong options are left once the same-meaning row is out');
    });

    test('1000 seeds on 30 words with shared meanings and homographs: never two equal or two right options', () {
      final words = <WordPair>[
        for (var i = 0; i < 24; i++) w('word$i', 'слово$i'),
        w('bank', 'банк'), w('bank', 'берег'),
        w('cat', 'кіт'), w('kitty', 'кіт'),
        w('big', 'великий', definition: 'Of large size.'), w('large', 'значний', definition: 'of large size.'),
      ];
      final pool = QuestionPool(group: words.take(15).toList(), others: words.skip(15).toList());
      for (var seed = 0; seed < 1000; seed++) {
        final word = words[seed % words.length];
        for (final kind in QuestionKind.values) {
          final q = buildQuestion(word, pool, kind, Random(seed));
          if (q == null) continue;
          final keys = q.options.map((o) => o.trim().toLowerCase()).toSet();
          expect(keys.length, 4, reason: 'seed $seed');
          final rows = [...pool.group, ...pool.others];
          String meaning(WordPair x) => (x.definition.trim().isNotEmpty ? x.definition : x.translation).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          for (final o in q.options.where((o) => o != q.options[q.rightIndex])) {
            final row = rows.firstWhere((x) => (kind == QuestionKind.wordToTranslation ? x.translation : x.word).trim() == o);
            if (kind == QuestionKind.wordToTranslation) {
              expect(row.word.trim().toLowerCase(), isNot(word.word.trim().toLowerCase()), reason: 'seed $seed');
            } else {
              expect(meaning(row), isNot(meaning(word)), reason: 'seed $seed');
            }
          }
        }
      }
    });

    test('the same word, candidates, kind and seed give the same question', () {
      for (final kind in QuestionKind.values) {
        final a = buildQuestion(cat, QuestionPool(group: group, others: others), kind, Random(42))!;
        final b = buildQuestion(cat, QuestionPool(group: group, others: others), kind, Random(42))!;
        expect(b.prompt, a.prompt);
        expect(b.options, a.options);
        expect(b.rightIndex, a.rightIndex);
        expect(b.rowId, a.rowId);
      }
    });
  });
}

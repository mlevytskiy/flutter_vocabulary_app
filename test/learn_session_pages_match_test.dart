import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/guess_my_word/guess_my_word_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/match_rounds.dart';
import 'package:flutter_vocabulary_app/features/learn/match_definitions/match_definitions_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/match_synonyms/match_synonyms_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';

/// A Worker stand-in answering every kind for every word, or throwing [error].
class FakeLearnApi implements LearnApiService {
  FakeLearnApi({this.error});

  Object? error;
  final kinds = <String>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    kinds.add(kind.wire);
    if (error != null) throw error!;
    Object answer(LearnWord w) => switch (kind.wire) {
          'synonym' => (synonym: 'syn ${w.rowId}'),
          'definition' => (definition: 'meaning of ${w.rowId}'),
          'clues' => (clues: ['first ${w.rowId}', 'second ${w.rowId}', 'third ${w.rowId}']),
          _ => throw StateError('unexpected kind ${kind.wire}'),
        };
    return {for (final w in words) w.rowId: answer(w) as T};
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// learn-redesign T9 (ADR-0003; AC-08, AC-10, AC-11): Match synonyms, Match
/// word and definition and Guess my word as session pages.
void main() {
  WordPair w(int i) => WordPair(word: 'word$i', translation: 'слово$i', rowId: 'r$i');
  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];
  PageInput input(List<WordPair> ws, FakeLearnApi api) =>
      PageInput(words: ws, others: const [], dialogues: const [], api: api, random: Random(1));

  Future<PageAnswer> pump(WidgetTester tester, ExercisePage page) async {
    final answer = PageAnswer();
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: Builder(builder: (c) => page.body(c, answer)))),
    ));
    return answer;
  }

  group('matchBoards', () {
    test('boards of 3–4 words covering every word in order (5 words: one board of 5)', () {
      expect(matchBoards([1, 2]), isEmpty);
      for (var n = 3; n <= 17; n++) {
        final items = [for (var i = 0; i < n; i++) i];
        final boards = matchBoards(items);
        expect(boards.expand((b) => b).toList(), items, reason: 'n=$n');
        expect(boards.length, n == 5 ? 1 : (n / 4).ceil(), reason: 'n=$n');
        for (final b in boards) {
          expect(b.length, n == 5 ? 5 : inInclusiveRange(3, 4), reason: 'n=$n');
        }
      }
    });
  });

  for (final (name, id, source) in [
    ('Match synonyms', 'match-synonyms', matchSynonymsPages),
    ('Match word and definition', 'match-definitions', matchDefinitionsPages),
  ]) {
    group(name, () {
      test('AC-08: one step-1 page per board of 3–4 words, covering every usable word', () async {
        final pages = await source(input(words(10), FakeLearnApi()));
        expect(pages.map((p) => p.rowIds.length), [4, 3, 3]);
        expect(pages.expand((p) => p.rowIds), [for (var i = 0; i < 10; i++) 'r$i']);
        for (final p in pages) {
          expect(p.exerciseId, id);
          expect(p.exerciseName, name);
          expect(p.step, 1);
        }
      });

      test('fewer than 3 words: no page and no call', () async {
        final api = FakeLearnApi();
        expect(await source(input(words(2), api)), isEmpty);
        expect(api.kinds, isEmpty);
      });

      test('AC-11: a data failure throws, never a page', () async {
        final api = FakeLearnApi(error: LearnApiException(LearnApiError.network, 'offline'));
        await expectLater(source(input(words(6), api)), throwsA(isA<LearnApiException>()));
      });

      testWidgets('AC-10: the board reports right-on-first-try per word via done() once complete', (tester) async {
        final pages = await source(input(words(4), FakeLearnApi()));
        expect(pages, hasLength(1));
        final answer = await pump(tester, pages.single);
        Future<void> pair(String l, String r) async {
          await tester.tap(find.byKey(ValueKey('match-left-$l')));
          await tester.tap(find.byKey(ValueKey('match-right-$r')));
          await tester.pumpAndSettle();
        }

        await pair('r0', 'r1'); // a miss on r0
        expect(answer.isDone, isFalse);
        await pair('r0', 'r0');
        await pair('r1', 'r1');
        await pair('r2', 'r2');
        expect(answer.isDone, isFalse);
        expect(answer.isReady, isFalse);
        await pair('r3', 'r3');
        expect(answer.results, {'r0': false, 'r1': true, 'r2': true, 'r3': true});
      });
    });
  }

  group('Guess my word', () {
    test('AC-08: one step-1 page per usable word', () async {
      final pages = await guessMyWordPages(input(words(7), FakeLearnApi()));
      expect(pages, hasLength(7));
      expect(pages.map((p) => p.rowIds.single).toSet(), {for (var i = 0; i < 7; i++) 'r$i'});
      for (final p in pages) {
        expect(p.exerciseId, 'guess-my-word');
        expect(p.exerciseName, 'Guess my word');
        expect(p.step, 1);
      }
    });

    test('fewer than 3 words: no page and no call', () async {
      final api = FakeLearnApi();
      expect(await guessMyWordPages(input(words(2), api)), isEmpty);
      expect(api.kinds, isEmpty);
    });

    test('AC-11: a data failure throws, never a page', () async {
      final api = FakeLearnApi(error: LearnApiException(LearnApiError.timeout, 'slow'));
      await expectLater(guessMyWordPages(input(words(5), api)), throwsA(isA<LearnApiException>()));
    });

    testWidgets('AC-10: found within the three clues reports right via done()', (tester) async {
      final pages = await guessMyWordPages(input(words(4), FakeLearnApi()));
      final page = pages.first;
      final target = page.rowIds.single;
      final answer = await pump(tester, page);
      expect(find.text('first $target'), findsOneWidget);
      final wrong = ['r0', 'r1', 'r2', 'r3'].firstWhere((id) => id != target);
      await tester.tap(find.byKey(ValueKey('guess-word-$wrong')));
      await tester.pump();
      expect(find.text('second $target'), findsOneWidget);
      expect(answer.isDone, isFalse);
      await tester.tap(find.byKey(ValueKey('guess-word-$target')));
      await tester.pump();
      expect(answer.results, {target: true});
    });

    testWidgets('AC-10: three wrong taps show the word and report wrong via done()', (tester) async {
      final pages = await guessMyWordPages(input(words(4), FakeLearnApi()));
      final page = pages.first;
      final target = page.rowIds.single;
      final answer = await pump(tester, page);
      for (final id in ['r0', 'r1', 'r2', 'r3'].where((id) => id != target)) {
        await tester.tap(find.byKey(ValueKey('guess-word-$id')));
        await tester.pump();
      }
      expect(answer.results, {target: false});
      expect(find.text('Next'), findsNothing);
    });
  });
}

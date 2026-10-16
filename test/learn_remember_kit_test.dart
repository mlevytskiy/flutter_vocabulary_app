import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/example_line.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_scaffold.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/result_summary.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-remember-or-not: kit additions S-31 (example lines, dialogues provider)
/// and S-33 (summary heading); AC-06, AC-14.
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

FilmDialogue _d(List<String> lines, List<String> ids, {bool hidden = false}) => FilmDialogue()
  ..id = 'd${lines.hashCode}'
  ..lines = lines
  ..wordRowIds = ids
  ..hidden = hidden;

void main() {
  final bank = WordPair(word: 'bank', translation: 'банк', rowId: 'b');

  group('exampleLineFor (S-31, AC-06)', () {
    test('first line holding the word exactly once', () {
      final d = _d([
        'We walked along the river.',
        'Meet me at the bank, the bank by the bridge.',
        'The bank opens at nine.',
      ], ['b']);
      expect(exampleLineFor(bank, [d]), 'The bank opens at nine.');
    });

    test('dialogue order, then line order', () {
      final d1 = _d(['No match here.', 'A bank here.'], ['b']);
      final d2 = _d(['Another bank.'], ['b']);
      expect(exampleLineFor(bank, [d1, d2]), 'A bank here.');
      expect(exampleLineFor(bank, [d2, d1]), 'Another bank.');
    });

    test('null when hidden, not linked, or no line holds it once', () {
      expect(exampleLineFor(bank, [_d(['The bank opens.'], ['b'], hidden: true)]), isNull);
      expect(exampleLineFor(bank, [_d(['The bank opens.'], ['other'])]), isNull);
      expect(exampleLineFor(bank, [_d(['bank bank', 'river'], ['b'])]), isNull);
      expect(exampleLineFor(bank, const []), isNull);
      expect(exampleLineFor(WordPair(word: 'bank', translation: 'x'), [_d(['The bank.'], [''])]), isNull);
    });
  });

  group('exerciseDialoguesProvider (S-31)', () {
    test('current session when id is null, History session by id', () async {
      final cur = WordCollection.create()..dialogues = [_d(['cur'], ['b'])];
      final hist = WordCollection.create()..dialogues = [_d(['hist'], ['b'])];
      final c = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(cur)),
        collectionByIdProvider('h').overrideWith((ref) async => hist),
      ]);
      addTearDown(c.dispose);
      expect((await c.read(exerciseDialoguesProvider(null).future)).single.lines, ['cur']);
      expect((await c.read(exerciseDialoguesProvider('h').future)).single.lines, ['hist']);
    });

    test('a missing History session gives no dialogues', () async {
      final c = ProviderContainer(overrides: [
        collectionByIdProvider('h').overrideWith((ref) async => null),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(exerciseDialoguesProvider('h').future), isEmpty);
    });
  });

  group('summary heading (S-33, AC-14)', () {
    const outcomes = [WordOutcome(rowId: 'a', word: 'a', result: 'Right')];
    Future<void> pump(Widget w, WidgetTester t) =>
        t.pumpWidget(MaterialApp(home: Scaffold(body: w)));

    testWidgets('ResultSummary shows the heading above the list; null shows nothing', (t) async {
      await pump(
          ResultSummary(outcomes: outcomes, hasNextRound: false, onNextRound: () {}, onDone: () {}, heading: '1 remembered'),
          t);
      expect(find.text('1 remembered'), findsOneWidget);
      await pump(ResultSummary(outcomes: outcomes, hasNextRound: false, onNextRound: () {}, onDone: () {}), t);
      expect(find.text('1 remembered'), findsNothing);
    });

    testWidgets('ExerciseSummary carries the heading through the scaffold', (t) async {
      await pump(
          ExerciseScaffold(
            title: 'T',
            phase: const ExerciseSummary(outcomes, hasNextRound: false, heading: '1 remembered'),
            onRetry: () {},
            onNextRound: () {},
            roundBuilder: (c, r) => const SizedBox(),
          ),
          t);
      expect(find.text('1 remembered'), findsOneWidget);
    });
  });
}

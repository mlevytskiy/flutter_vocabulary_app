import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-match-synonyms: the screen (AC-01, AC-03 – AC-08, AC-13 – AC-22).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

/// Counts every call; answers "like <rowId>" unless told otherwise.
class _Api implements LearnApiService {
  Object? error;
  Completer<void>? gate;
  Map<String, String?> overrides = {};
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (overrides.containsKey(w.word) ? overrides[w.word] : 'like ${w.rowId}') == null
            ? null
            : (synonym: overrides.containsKey(w.word) ? overrides[w.word]! : 'like ${w.rowId}') as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

WordCollection _collection(int count, {String prefix = 'word'}) {
  final words = [
    for (var i = 0; i < count; i++) WordPair(word: '$prefix$i', translation: 'слово$i', rowId: 'r$i'),
  ];
  return WordCollection.create()
    ..words = words
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (var i = 0; i < count; i++) 'r$i'],
    ];
}

void main() {
  late _Api api;

  Future<ProviderContainer> pump(WidgetTester tester, WordCollection collection,
      {String? collectionId, Size size = const Size(800, 1600), bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(3)),
      learnApiServiceProvider.overrideWithValue(api),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(collection)),
      collectionByIdProvider('hist').overrideWith((ref) async => collection),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('match-synonyms', collectionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    return container;
  }

  Finder left(String id) => find.byKey(ValueKey('match-left-$id'));
  Finder right(String id) => find.byKey(ValueKey('match-right-$id'));

  Future<void> link(WidgetTester tester, String leftId, String rightId) async {
    await tester.ensureVisible(left(leftId));
    await tester.tap(left(leftId));
    await tester.pump();
    await tester.ensureVisible(right(rightId));
    await tester.tap(right(rightId));
    await tester.pump();
  }

  setUp(() => api = _Api());

  testWidgets('AC-01: title, loading, then the line, 6 words in group order and 6 synonyms, no counter', (tester) async {
    api.gate = Completer<void>();
    await pump(tester, _collection(6), settle: false);
    expect(find.text('Match synonyms'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tap a word, then its synonym'), findsOneWidget);
    expect(find.textContaining('Round '), findsNothing);
    final ys = [for (var i = 0; i < 6; i++) tester.getTopLeft(left('r$i')).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    for (var i = 0; i < 6; i++) {
      expect(find.descendant(of: left('r$i'), matching: find.text('word$i')), findsOneWidget);
      expect(find.descendant(of: right('r$i'), matching: find.text('like r$i')), findsOneWidget);
    }
  });

  testWidgets('AC-04 – AC-08, AC-20: pairs lock, misses count, the summary opens by itself; Done returns', (tester) async {
    await pump(tester, _collection(4));
    await link(tester, 'r0', 'r1'); // wrong
    await tester.pumpAndSettle();
    await link(tester, 'r0', 'r2'); // wrong again
    await tester.pumpAndSettle();
    await link(tester, 'r0', 'r0');
    expect(find.descendant(of: left('r0'), matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: right('r0'), matching: find.text('1')), findsOneWidget);
    await tester.tap(right('r1')); // AC-05: synonym first
    await tester.pump();
    await tester.tap(left('r1'));
    await tester.pump();
    expect(find.descendant(of: left('r1'), matching: find.text('2')), findsOneWidget);
    await link(tester, 'r2', 'r3'); // wrong, a miss on word2
    await tester.pumpAndSettle();
    await link(tester, 'r2', 'r2');
    await link(tester, 'r3', 'r3');
    expect(find.descendant(of: left('r3'), matching: find.text('4')), findsOneWidget, reason: 'the last lock shows');
    expect(find.text('Done'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Done'), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('2 misses'), findsOneWidget);
    expect(find.text('1 miss'), findsOneWidget);
    expect(find.text('no misses'), findsNWidgets(2));
    final ys = [for (var i = 0; i < 4; i++) tester.getTopLeft(find.byKey(ValueKey('outcome-r$i'))).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(api.calls.length, 1);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-15, AC-20: 8 words show "Round 1 of 2"; Next round opens a fresh board', (tester) async {
    await pump(tester, _collection(8));
    expect(find.text('Round 1 of 2'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await link(tester, 'r$i', 'r$i');
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next round'));
    await tester.pumpAndSettle();
    expect(find.text('Round 2 of 2'), findsOneWidget);
    expect(left('r4'), findsOneWidget);
    expect(find.descendant(of: left('r4'), matching: find.text('1')), findsNothing);
    expect(api.calls.length, 1, reason: 'no call for Next round');
  });

  testWidgets('AC-14: a long press on a word shows its translation and counts nothing', (tester) async {
    await pump(tester, _collection(3));
    await tester.longPress(left('r1'));
    await tester.pump();
    expect(find.text('слово1'), findsOneWidget);
    await tester.longPress(right('r1'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('слово1'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await link(tester, 'r$i', 'r$i');
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('no misses'), findsNWidgets(3));
  });

  testWidgets('AC-13: long synonyms wrap on a phone and the board scrolls without overflow', (tester) async {
    const long = 'a rather long phrase that keeps going for a while';
    api.overrides = {for (var i = 0; i < 6; i++) 'word$i': '$long $i'};
    await pump(tester, _collection(6), size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    await link(tester, 'r5', 'r5');
    expect(find.descendant(of: left('r5'), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('AC-16: too few usable after the answers shows the synonym line and Back', (tester) async {
    api.overrides = {'word0': null, 'word1': null};
    await pump(tester, _collection(4));
    expect(find.text('Not enough words with synonyms for this group'), findsOneWidget);
    expect(find.text('Tap a word, then its synonym'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-17: fewer than 3 words to learn shows the default line and asks no one', (tester) async {
    await pump(tester, _collection(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('AC-18: offline shows the failed line and Retry; Retry asks again and starts round 1', (tester) async {
    api.error = LearnApiException(LearnApiError.network, 'offline');
    await pump(tester, _collection(4));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Tap a word, then its synonym'), findsNothing);
    api.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a word, then its synonym'), findsOneWidget);
    expect(api.calls.length, 2);
  });

  testWidgets('AC-18: no exercise storage on the Worker shows the same line', (tester) async {
    api.error = LearnApiException(LearnApiError.unavailable, 'no storage');
    await pump(tester, _collection(4));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-19: the day limit shows its line and Back; too many requests shows its line and Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, 'cap');
    await pump(tester, _collection(4));
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    api.error = LearnApiException(LearnApiError.rateLimited, 'slow down');
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-21, AC-22: a History session is used and unchanged; Back keeps nothing', (tester) async {
    final hist = _collection(4, prefix: 'old');
    final before = hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList();
    final groups = hist.groups.map((g) => '${g.id}|${g.rowIds}').toList();
    final updated = hist.updatedAt;
    await pump(tester, hist, collectionId: 'hist');
    expect(api.calls.single.map((w) => (w.word, w.translation)), [
      for (var i = 0; i < 4; i++) ('old$i', 'слово$i'),
    ]);
    await link(tester, 'r0', 'r1');
    await tester.pumpAndSettle();
    await link(tester, 'r0', 'r0');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: left('r0'), matching: find.text('1')), findsNothing);
    for (var i = 0; i < 4; i++) {
      await link(tester, 'r$i', 'r$i');
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('no misses'), findsNWidgets(4), reason: 'the earlier miss was not kept');
    expect(hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList(), before);
    expect(hist.groups.map((g) => '${g.id}|${g.rowIds}').toList(), groups);
    expect(hist.updatedAt, updated);
  });
}

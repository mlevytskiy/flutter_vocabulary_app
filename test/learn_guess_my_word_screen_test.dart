import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/guess_my_word/guess_my_word_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-guess-my-word: the screen (AC-01, AC-03 – AC-08, AC-13, AC-17 – AC-24).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

/// Counts every call; answers three clues per word unless told otherwise.
class _Api implements LearnApiService {
  Object? error;
  Completer<void>? gate;
  Map<String, List<String>?> overrides = {};
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (overrides.containsKey(w.word)
                ? overrides[w.word]
                : ['first ${w.rowId}', 'second ${w.rowId}', 'third ${w.rowId}']) ==
            null
            ? null
            : (clues: overrides.containsKey(w.word)
                ? overrides[w.word]!
                : ['first ${w.rowId}', 'second ${w.rowId}', 'third ${w.rowId}']) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

Session _session(int count, {String prefix = 'word'}) {
  final words = [
    for (var i = 0; i < count; i++) WordPair(word: '$prefix$i', translation: 'слово$i', rowId: 'r$i'),
  ];
  return Session.create()
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
  late ProviderContainer container;
  String? sid;

  Future<void> pump(WidgetTester tester, Session session,
      {String? sessionId, Size size = const Size(800, 1600), bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    sid = sessionId;
    container = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(3)),
      learnApiServiceProvider.overrideWithValue(api),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      sessionByIdProvider('hist').overrideWith((ref) async => session),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('guess-my-word', sessionId, 'g'),
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
  }

  GuessState state() => container.read(guessMyWordProvider(sid, 'g')).requireValue;
  Finder tile(String id) => find.byKey(ValueKey('guess-word-$id'));
  String wrongId() {
    final s = state();
    return s.grid.firstWhere((x) => x.rowId != s.target!.rowId && !s.greyed.contains(x.rowId) && !s.points.containsKey(x.rowId)).rowId;
  }

  Future<void> tapTile(WidgetTester tester, String id) async {
    await tester.ensureVisible(tile(id));
    await tester.tap(tile(id));
    await tester.pump();
  }

  setUp(() => api = _Api());

  testWidgets('AC-01: title, counter, line, clue 1 only, 6 words three per row', (tester) async {
    await pump(tester, _session(6));
    expect(find.text('Guess my word'), findsOneWidget);
    expect(find.text('Word 1 of 6'), findsOneWidget);
    expect(find.text('Tap the word the clues describe.'), findsOneWidget);
    final t = state().target!;
    expect(find.text('Clue 1'), findsOneWidget);
    expect(find.text(t.clues[0]), findsOneWidget);
    expect(find.text('Clue 2'), findsNothing);
    expect(find.text('Clue 3'), findsNothing);
    for (var i = 0; i < 6; i++) {
      expect(find.descendant(of: tile('r$i'), matching: find.text('word$i')), findsOneWidget);
    }
    final ys = {for (var i = 0; i < 6; i++) tester.getTopLeft(tile('r$i')).dy};
    expect(ys.length, 2, reason: 'three per row');
    expect(find.text('слово0'), findsNothing);
    expect(api.calls.length, 1);
  });

  testWidgets('AC-03: a right tap shows the points, locks 600 ms, then the next clue 1', (tester) async {
    await pump(tester, _session(6));
    final t = state().target!;
    await tapTile(tester, t.rowId);
    expect(find.text('Right: 3 points'), findsOneWidget);
    await tester.tap(tile(wrongId()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Word 1 of 6'), findsOneWidget);
    expect(find.text('Clue 2'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Word 2 of 6'), findsOneWidget);
    expect(find.text(state().target!.clues[0]), findsOneWidget);
    expect(find.text('Right: 3 points'), findsNothing);
  });

  testWidgets('AC-04, AC-05: a wrong tap greys the word and adds clue 2; right then says 2 points', (tester) async {
    await pump(tester, _session(6));
    final t = state().target!;
    final bad = wrongId();
    await tapTile(tester, bad);
    expect(find.text('Clue 2'), findsOneWidget);
    expect(find.text(t.clues[0]), findsOneWidget);
    expect(find.text(t.clues[1]), findsOneWidget);
    expect(state().greyed, {bad});
    await tapTile(tester, bad);
    expect(find.text('Clue 3'), findsNothing);
    await tapTile(tester, t.rowId);
    expect(find.text('Right: 2 points'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tapTile(tester, wrongId());
    await tapTile(tester, wrongId());
    expect(find.text('Clue 3'), findsOneWidget);
    await tapTile(tester, state().target!.rowId);
    expect(find.text('Right: 1 point'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('AC-06: a wrong tap on clue 3 shows the answer and Next; Next opens the next clue 1', (tester) async {
    await pump(tester, _session(6));
    final t = state().target!;
    for (var i = 0; i < 3; i++) {
      await tapTile(tester, wrongId());
    }
    expect(find.text('The word was “${t.word}”.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(tile(t.rowId));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Word 1 of 6'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Word 2 of 6'), findsOneWidget);
    expect(find.text('Clue 2'), findsNothing);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('AC-08: a long press shows the translation and changes nothing', (tester) async {
    await pump(tester, _session(6));
    await tester.longPress(tile('r2'));
    await tester.pumpAndSettle();
    expect(find.text('слово2'), findsOneWidget);
    expect(state().greyed, isEmpty);
    expect(state().level, 1);
    await tester.longPress(find.text(state().target!.clues[0]));
    await tester.pumpAndSettle();
    expect(find.text('слово2'), findsNothing);
  });

  testWidgets('AC-13: clues are plain text and wrap on a phone', (tester) async {
    api.overrides = {for (var i = 0; i < 4; i++) 'word$i': ['**bold** a very long clue that keeps on going and going', 'b', 'c']};
    await pump(tester, _session(4), size: const Size(360, 640));
    expect(find.textContaining('**bold**'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-21, AC-22: summary with the score; Next round is fresh; Done returns', (tester) async {
    await pump(tester, _session(12));
    expect(find.text('Round 1 of 2 · Word 1 of 6'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tapTile(tester, state().target!.rowId);
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpAndSettle();
    expect(find.text('Score: 18 of 18'), findsOneWidget);
    expect(find.text('3 points'), findsNWidgets(6));
    await tester.tap(find.text('Next round'));
    await tester.pumpAndSettle();
    expect(find.text('Round 2 of 2 · Word 1 of 6'), findsOneWidget);
    expect(tile('r6'), findsOneWidget);
    expect(tile('r0'), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tapTile(tester, state().target!.rowId);
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-14: a spinner shows while the clues load', (tester) async {
    api.gate = Completer<void>();
    await pump(tester, _session(4), settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Clue 1'), findsOneWidget);
  });

  testWidgets('AC-17: fewer than 3 words: the default line, Back, no Worker call', (tester) async {
    await pump(tester, _session(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-18: too few usable clues: its line and Back', (tester) async {
    api.overrides = {'word0': null, 'word1': null};
    await pump(tester, _session(4));
    expect(find.text('Not enough words with clues for this group'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('AC-19: offline shows the failed line and Retry; Retry starts the first target', (tester) async {
    api.error = LearnApiException(LearnApiError.network, 'offline');
    await pump(tester, _session(4));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    api.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Clue 1'), findsOneWidget);
    expect(api.calls.length, 2);
  });

  testWidgets('AC-20: the day limit shows its line and Back; too many requests its line and Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, 'cap');
    await pump(tester, _session(4));
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    api.error = LearnApiException(LearnApiError.rateLimited, 'slow');
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-23, AC-24: a History session is used and unchanged; Back keeps nothing', (tester) async {
    final hist = _session(4, prefix: 'old');
    final before = hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList();
    final updated = hist.updatedAt;
    await pump(tester, hist, sessionId: 'hist');
    expect(api.calls.single.map((w) => (w.word, w.translation)), [for (var i = 0; i < 4; i++) ('old$i', 'слово$i')]);
    await tapTile(tester, state().target!.rowId);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList(), before);
    expect(hist.updatedAt, updated);
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 4'), findsOneWidget);
    expect(find.textContaining('Right:'), findsNothing);
  });
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_presets.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/ladder_queue.dart';
import 'package:flutter_vocabulary_app/features/learn/session/learning_session_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/session/learning_session_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_registry.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// learn-redesign T12 (ADR-0004; AC-02, AC-08, AC-09, AC-11, AC-16): the
/// LearningSession notifier, the session screen and LearningSessionRoute,
/// played with fake page sources.

class _FakeInput extends WordsNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

/// Records every store call: leaving a session must not reach it (AC-16).
class _Store implements CollectionStore {
  final calls = <Symbol>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName);
    return super.noSuchMethod(i);
  }
}

class _NoNetwork implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('the session asked the server: ${i.memberName}');
}

WordCollection _collection(int count) => WordCollection.create()
  ..collectionId = 'c1'
  ..words = [
    for (var i = 0; i < count; i++) WordPair(word: 'word$i', translation: 'слово$i', definition: '', rowId: 'r$i'),
  ];

/// A fake page source: one page per word ([board]: one page for up to four
/// words), recording each call's words.
class _Fakes {
  final calls = <String, List<List<String>>>{};
  final throwing = <String>{};
  final gates = <int, Completer<void>>{};
  final boards = <String>{};

  PageSource source(String id) => (PageInput input) async {
        (calls[id] ??= []).add([for (final w in input.words) w.rowId]);
        final step = stepOf(id);
        final gate = gates[step];
        if (gate != null) await gate.future;
        if (throwing.contains(id)) throw LearnApiException(LearnApiError.network, 'offline');
        if (boards.contains(id)) {
          return [
            for (var i = 0; i < input.words.length; i += 4)
              _page(id, step, [for (final w in input.words.skip(i).take(4)) w.rowId]),
          ];
        }
        return [for (final w in input.words) _page(id, step, [w.rowId])];
      };

  Map<String, PageSource> get map => {for (final id in pageExerciseIds) id: source(id)};

  Set<String> calledOfStep(int step) => {for (final id in calls.keys) if (stepOf(id) == step) id};
}

ExercisePage _page(String id, int step, List<String> rowIds) => ExercisePage(
      exerciseId: id,
      exerciseName: id,
      step: step,
      rowIds: rowIds,
      body: (context, answer) => TextButton(
        onPressed: () => answer.done({for (final r in rowIds) r: true}),
        child: Text('$id ${rowIds.join(',')}'),
      ),
    );

ProviderContainer _container(WordCollection collection, _Fakes fakes, {int seed = 1}) {
  final c = ProviderContainer(overrides: [
    exerciseRandomProvider.overrideWithValue(Random(seed)),
    learnApiServiceProvider.overrideWithValue(_NoNetwork()),
    wordsNotifierProvider.overrideWith(() => _FakeInput(collection)),
    pageSourcesProvider.overrideWithValue(fakes.map),
  ]);
  addTearDown(c.dispose);
  // Keep the auto-dispose session alive for the test.
  c.listen(learningSessionProvider(null), (_, __) {});
  return c;
}

LearningSession _session(ProviderContainer c) => c.read(learningSessionProvider(null).notifier);
LearningSessionState _state(ProviderContainer c) => c.read(learningSessionProvider(null));

/// Answers the current page with [right] for each of its words, then Continue.
Future<void> _answer(ProviderContainer c, {required bool right}) async {
  final page = _state(c).page!;
  _session(c).answer({for (final r in page.rowIds) r: right});
  await _session(c).next();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('drawing exercise types (AC-08)', () {
    test('each step draws min(3, switched on) types; Mnemonic story and Dialogs from movie never', () async {
      expect(pageSources.keys.toSet(), pageExerciseIds.toSet());
      expect(pageSources.containsKey('mnemonic-story'), isFalse);
      expect(pageSources.containsKey('dialogs-from-movie'), isFalse);

      // Deep: 4 / 3 / 4 switched on → 3 / 3 / 3 drawn.
      SharedPreferences.setMockInitialValues({'learn.enabled': presetExercises(LearnPreset.deep).toList()});
      var fakes = _Fakes();
      var c = _container(_collection(5), fakes);
      await _session(c).start(split: true);
      await _session(c).pagesLoaded;
      expect([for (final s in [1, 2, 3]) fakes.calledOfStep(s).length], [3, 3, 3]);

      // Quick: 3 / 2 / 1 switched on → all drawn.
      SharedPreferences.setMockInitialValues({'learn.enabled': presetExercises(LearnPreset.quick).toList()});
      fakes = _Fakes();
      c = _container(_collection(5), fakes);
      await _session(c).start(split: true);
      await _session(c).pagesLoaded;
      expect(fakes.calledOfStep(1), {'match-synonyms', 'match-definitions', 'pick-the-answer'});
      expect(fakes.calledOfStep(2), {'remember-or-not', 'fill-the-gaps'});
      expect(fakes.calledOfStep(3), {'quiz'});
    });
  });

  group('building pages (AC-02, AC-08)', () {
    test('the first page shows from step-1 pages while steps 2 and 3 still load', () async {
      final fakes = _Fakes()
        ..gates[2] = Completer<void>()
        ..gates[3] = Completer<void>();
      final c = _container(_collection(5), fakes);
      await _session(c).start(split: true);
      final s = _state(c);
      expect(s.status, SessionStatus.playing);
      expect(s.page!.step, 1);
      expect(s.step, 1);
      expect(s.pageNumber, 1);
      expect(s.pageTotal, 15);
      // Steps 2 and 3 started loading right away.
      expect(fakes.calledOfStep(2), isNotEmpty);
      expect(fakes.calledOfStep(3), isNotEmpty);
      fakes.gates[2]!.complete();
      fakes.gates[3]!.complete();
    });

    test('AI data goes in batches of at most 19 words', () async {
      final fakes = _Fakes();
      final c = _container(_collection(25), fakes);
      await _session(c).start(split: false);
      await _session(c).pagesLoaded;
      for (final entry in fakes.calls.entries) {
        expect(entry.value.length, 2, reason: entry.key);
        for (final words in entry.value) {
          expect(words.length, lessThanOrEqualTo(19), reason: entry.key);
        }
        expect({for (final words in entry.value) ...words}.length, 25, reason: entry.key);
      }
    });
  });

  group('the ladder (AC-08, AC-09)', () {
    test('a missed word comes back 3 pages later, every word climbs Meet → Practise → Use', () async {
      final fakes = _Fakes();
      final c = _container(_collection(5), fakes);
      await _session(c).start(split: true);
      final missed = _state(c).page!.rowIds.single;
      await _answer(c, right: false);
      final shown = <String>[];
      final steps = <String, List<int>>{};
      while (_state(c).status == SessionStatus.playing) {
        final page = _state(c).page!;
        shown.add(page.rowIds.single);
        (steps[page.rowIds.single] ??= []).add(page.step);
        await _answer(c, right: true);
      }
      expect(shown[0], isNot(missed));
      expect(shown[1], isNot(missed));
      expect(shown[2], missed);
      for (final s in steps.values) {
        expect(s, [1, 2, 3]);
      }
      expect(_state(c).status, SessionStatus.finished);
    });

    test('a board page records all its words and its verdict counts them', () async {
      final fakes = _Fakes()..boards.addAll(pageExerciseIds.where((id) => stepOf(id) == 1));
      final c = _container(_collection(4), fakes);
      await _session(c).start(split: true);
      final page = _state(c).page!;
      expect(page.rowIds, hasLength(4));
      _session(c).answer({'r0': true, 'r1': false, 'r2': true, 'r3': true});
      final s = _state(c);
      expect(s.verdict!.right, isFalse);
      expect(s.verdict!.word, '3 of 4 right');
      expect(s.queue!.rungOf('r1'), Rung.meet);
      expect(s.queue!.rungOf('r0'), Rung.practise);
      expect(s.queue!.rungOf('r3'), Rung.practise);
    });

    test('the verdict names the page word and its translation', () async {
      final fakes = _Fakes();
      final c = _container(_collection(3), fakes);
      await _session(c).start(split: true);
      final id = _state(c).page!.rowIds.single;
      _session(c).answer({id: true});
      final v = _state(c).verdict!;
      expect(v.right, isTrue);
      expect(v.word, 'word${id.substring(1)}');
      expect(v.translation, 'слово${id.substring(1)}');
    });
  });

  group('errors (AC-11)', () {
    test('a source that cannot load sets the error line while the other pages play; Retry reloads it', () async {
      SharedPreferences.setMockInitialValues({'learn.enabled': presetExercises(LearnPreset.quick).toList()});
      final fakes = _Fakes()..throwing.addAll(['match-synonyms', 'match-definitions']);
      final c = _container(_collection(5), fakes);
      await _session(c).start(split: true);
      var s = _state(c);
      expect(s.status, SessionStatus.playing);
      expect(s.loadFailed, isTrue);
      expect(s.page!.exerciseId, 'pick-the-answer');

      fakes.throwing.clear();
      await _session(c).retry();
      s = _state(c);
      expect(s.loadFailed, isFalse);
      expect(fakes.calls['match-synonyms'], hasLength(2));
    });

    test('a step whose every source failed falls back to other pages of the word, never blocking', () async {
      SharedPreferences.setMockInitialValues({'learn.enabled': presetExercises(LearnPreset.quick).toList()});
      final fakes = _Fakes()..throwing.add('quiz');
      final c = _container(_collection(2), fakes);
      await _session(c).start(split: true);
      var guard = 0;
      while (_state(c).status == SessionStatus.playing && guard++ < 50) {
        await _answer(c, right: true);
      }
      expect(_state(c).status, SessionStatus.finished);
      expect(_state(c).loadFailed, isTrue);
    });

    test('no page at all → not enough words', () async {
      final empty = {for (final id in pageExerciseIds) id: (PageInput _) async => <ExercisePage>[]};
      final c = ProviderContainer(overrides: [
        exerciseRandomProvider.overrideWithValue(Random(1)),
        learnApiServiceProvider.overrideWithValue(_NoNetwork()),
        wordsNotifierProvider.overrideWith(() => _FakeInput(_collection(3))),
        pageSourcesProvider.overrideWithValue(empty),
      ]);
      addTearDown(c.dispose);
      c.listen(learningSessionProvider(null), (_, __) {});
      await _session(c).start(split: true);
      expect(_state(c).status, SessionStatus.notEnough);
    });
  });

  group('finishing', () {
    test('outcomes are keyed by the pick\'s own WordPairs: clean without a miss, missed with one', () async {
      final fakes = _Fakes();
      final c = _container(_collection(3), fakes);
      await _session(c).start(split: true);
      final missed = _state(c).page!.rowIds.single;
      await _answer(c, right: false);
      while (_state(c).status == SessionStatus.playing) {
        await _answer(c, right: true);
      }
      final s = _state(c);
      expect(s.status, SessionStatus.finished);
      expect(s.outcomes, hasLength(3));
      for (final w in s.pick!.words) {
        expect(s.outcomes.keys.any((k) => identical(k, w)), isTrue);
        expect(s.outcomes[w], w.rowId == missed ? WordOutcome.missed : WordOutcome.clean);
      }
    });
  });

  group('session screen', () {
    late _Store store;

    Future<(ProviderContainer, _Fakes, WordCollection)> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final collection = _collection(3);
      final fakes = _Fakes();
      store = _Store();
      final c = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        exerciseRandomProvider.overrideWithValue(Random(1)),
        learnApiServiceProvider.overrideWithValue(_NoNetwork()),
        wordsNotifierProvider.overrideWith(() => _FakeInput(collection)),
        pageSourcesProvider.overrideWithValue(fakes.map),
      ]);
      addTearDown(c.dispose);
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/session'),
              child: const Text('table'),
            ),
          ),
          routes: [
            GoRoute(path: 'session', builder: (_, __) => const LearningSessionScreen()),
          ],
        ),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('table'));
      await tester.pumpAndSettle();
      return (c, fakes, collection);
    }

    testWidgets('AC-02: the session opens on its first page; a page answer shows the verdict', (tester) async {
      final (c, _, _) = await pump(tester);
      expect(find.text('1 / 9'), findsOneWidget);
      final page = c.read(learningSessionProvider(null)).page!;
      await tester.tap(find.text('${page.exerciseId} ${page.rowIds.single}'));
      await tester.pumpAndSettle();
      expect(find.text('✓ Right'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 9'), findsOneWidget);
    });

    testWidgets('AC-16: close asks to leave; Stay keeps the session, Leave pops and writes nothing', (tester) async {
      final (c, _, collection) = await pump(tester);
      final boxesBefore = collection.boxes;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the session? Progress in this session is lost.'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 9'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('table'), findsOneWidget);
      expect(find.byType(LearningSessionScreen), findsNothing);
      expect(identical(collection.boxes, boxesBefore), isTrue);
      expect(collection.boxes, isEmpty);
      expect(store.calls, isEmpty);
    });

    testWidgets('AC-11: the error line with Retry shows above the playing page', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'learn.enabled': presetExercises(LearnPreset.quick).toList()});
      final fakes = _Fakes()..throwing.add('match-synonyms');
      final c = ProviderContainer(overrides: [
        exerciseRandomProvider.overrideWithValue(Random(1)),
        learnApiServiceProvider.overrideWithValue(_NoNetwork()),
        wordsNotifierProvider.overrideWith(() => _FakeInput(_collection(3))),
        pageSourcesProvider.overrideWithValue(fakes.map),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: LearningSessionScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Could not load some exercises'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('1 / 9'), findsOneWidget);
    });
  });

  group('LearningSessionRoute', () {
    test('sits under the words table at session with ids only, as query parameters', () {
      expect(const LearningSessionRoute().location, '/words/table/session');
      expect(const LearningSessionRoute(collectionId: 's1', split: false, rowIds: 'r1,r2').location,
          '/words/table/session?collection-id=s1&split=false&row-ids=r1%2Cr2');
    });

    testWidgets('builds the session screen from its location', (tester) async {
      GoRoute? find0(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute && r.path == 'session') return r;
          final inner = find0(r.routes);
          if (inner != null) return inner;
        }
        return null;
      }

      final route = find0($appRoutes)!;
      final router = GoRouter(
        initialLocation: const LearningSessionRoute(collectionId: 's1', split: false, rowIds: 'r1,r2')
            .location
            .replaceFirst('/words/table/session', '/session'),
        routes: [GoRoute(path: '/session', builder: route.builder, pageBuilder: route.pageBuilder, redirect: route.redirect)],
      );
      final c = ProviderContainer(overrides: [
        collectionByIdProvider('s1').overrideWith((ref) async => _collection(3)),
        pageSourcesProvider.overrideWithValue(_Fakes().map),
        learnApiServiceProvider.overrideWithValue(_NoNetwork()),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      final screen = tester.widget<LearningSessionScreen>(find.byType(LearningSessionScreen));
      expect(screen.collectionId, 's1');
      expect(screen.split, isFalse);
      expect(screen.rowIds, ['r1', 'r2']);
    });
  });
}

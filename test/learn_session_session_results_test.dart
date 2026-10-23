import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_presets.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart';
import 'package:flutter_vocabulary_app/features/learn/session/learning_session_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_registry.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_result.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_results_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

/// learn-redesign T13 (ADR-0002; AC-07, AC-12, AC-13, AC-16): finishing writes
/// the boxes in one store update; the results screen and its buttons.

/// An in-memory store: [collection] null is an erased collection.
class _Store implements CollectionStore {
  _Store(this.collection);
  WordCollection? collection;
  int updates = 0;

  @override
  Future<String?> currentCollectionId() async => collection?.collectionId;

  @override
  Future<WordCollection?> byId(String collectionId) async => collection;

  @override
  Future<bool> update(String collectionId, void Function(WordCollection) change) async {
    updates++;
    final c = collection;
    if (c == null) return false;
    change(c);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _FakeInput extends WordsNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  @override
  Future<WordCollection> build() async => collection;
}

class _NoNetwork implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('asked the server');
}

WordCollection _collection(int count) => WordCollection.create()
  ..collectionId = 'c1'
  ..words = [
    for (var i = 0; i < count; i++) WordPair(word: 'word$i', translation: 'слово$i', definition: '', rowId: 'r$i'),
  ];

Map<String, PageSource> _sources() => {
      for (final id in pageExerciseIds)
        id: (PageInput input) async => [
              for (final w in input.words)
                ExercisePage(
                  exerciseId: id,
                  exerciseName: id,
                  step: stepOf(id),
                  rowIds: [w.rowId],
                  body: (context, answer) => const SizedBox(),
                ),
            ],
    };

ProviderContainer _container(WordCollection collection, _Store store) {
  final c = ProviderContainer(overrides: [
    collectionStoreProvider.overrideWith((ref) async => store),
    exerciseRandomProvider.overrideWithValue(Random(1)),
    learnApiServiceProvider.overrideWithValue(_NoNetwork()),
    wordsProvider.overrideWith(() => _FakeInput(collection)),
    pageSourcesProvider.overrideWithValue(_sources()),
  ]);
  addTearDown(c.dispose);
  c.listen(learningSessionProvider(null), (_, __) {});
  return c;
}

Future<void> _play(ProviderContainer c, {bool missFirst = false}) async {
  final s = c.read(learningSessionProvider(null).notifier);
  await s.start(split: true);
  var first = true;
  while (c.read(learningSessionProvider(null)).status == SessionStatus.playing) {
    final page = c.read(learningSessionProvider(null)).page!;
    s.answer({for (final r in page.rowIds) r: !(missFirst && first)});
    first = false;
    await s.next();
  }
}

WordBox _box(String id, int box, DateTime due) => WordBox()
  ..rowId = id
  ..word = id
  ..box = box
  ..dueAt = due;

SessionMove _move(String id, WordState state, {int? inDays}) => SessionMove(
      rowId: id,
      word: 'w$id',
      state: state,
      after: inDays == null ? null : _box(id, 2, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + inDays, 12)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('finishing (AC-13, AC-16)', () {
    test('one store update moves the boxes; the result is held', () async {
      final collection = _collection(3);
      final store = _Store(collection);
      final c = _container(collection, store);
      await _play(c);
      expect(c.read(learningSessionProvider(null)).status, SessionStatus.finished);
      expect(store.updates, 1);
      expect(collection.boxes, hasLength(3));
      expect(collection.boxes.every((b) => b.box == 1), isTrue);
      final r = c.read(lastSessionResultProvider)!;
      expect(r.written, isTrue);
      expect(r.kind, SessionKind.exercises);
      expect(r.moves, hasLength(3));
      expect(r.pages, greaterThan(0));
      expect(r.groupCount, 0);
    });

    test('an erased collection: result still held, nothing written', () async {
      final collection = _collection(3);
      final store = _Store(collection);
      final c = _container(collection, store);
      final session = c.read(learningSessionProvider(null).notifier);
      await session.start(split: true);
      store.collection = null;
      while (c.read(learningSessionProvider(null)).status == SessionStatus.playing) {
        final page = c.read(learningSessionProvider(null)).page!;
        session.answer({for (final r in page.rowIds) r: true});
        await session.next();
      }
      final r = c.read(lastSessionResultProvider)!;
      expect(r.written, isFalse);
      expect(r.moves, hasLength(3));
      expect(collection.boxes, isEmpty);
    });
  });

  group('results screen (AC-12)', () {
    Future<List<String>> pump(WidgetTester tester, SessionResult result, {_Store? store}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final visited = <String>[];
      final c = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store ?? _Store(_collection(1))),
      ]);
      addTearDown(c.dispose);
      c.read(lastSessionResultProvider.notifier).set(result);
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(onPressed: () => context.push('/results'), child: const Text('table')),
        ),
        GoRoute(path: '/results', builder: (_, __) => const SessionResultsScreen()),
        GoRoute(
          path: '/words/table/session',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Text('session');
          },
        ),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('table'));
      await tester.pumpAndSettle();
      return visited;
    }

    SessionResult result({
      SessionKind kind = SessionKind.exercises,
      bool written = true,
      int groupCount = 0,
      int unused = 0,
    }) =>
        SessionResult(
          kind: kind,
          collectionId: 'c1',
          moves: [
            _move('a', WordState.knownWell, inDays: 4),
            _move('b', WordState.shaky, inDays: 1),
            _move('c', WordState.shaky, inDays: 0),
            _move('d', WordState.isNew, inDays: 2),
            _move('e', WordState.unused),
          ],
          unusedCount: unused,
          written: written,
          groupIndex: groupCount > 0 ? 1 : null,
          groupCount: groupCount,
          pages: 32,
        );

    testWidgets('counts, pages and next-review rows', (tester) async {
      await pump(tester, result());
      expect(find.text('Session done'), findsOneWidget);
      expect(find.text('32 pages'), findsOneWidget);
      expect(find.text('1 know well'), findsOneWidget);
      expect(find.text('2 shaky'), findsOneWidget);
      expect(find.text('1 new'), findsOneWidget);
      expect(find.text('wa'), findsOneWidget);
      expect(find.text('in 4 days'), findsOneWidget);
      expect(find.text('tomorrow'), findsOneWidget);
      expect(find.text('today'), findsOneWidget);
      expect(find.text('we'), findsNothing);
      expect(find.text('Next group'), findsNothing);
      expect(find.textContaining('not saved'), findsNothing);
    });

    testWidgets('not written: the recycle-bin line, or the neutral one when erased', (tester) async {
      await pump(tester, result(written: false));
      expect(find.text(SessionResultsScreen.binnedText), findsOneWidget);
    });

    testWidgets('erased collection shows the neutral line', (tester) async {
      await pump(tester, result(written: false), store: _Store(null));
      expect(find.text('Results not saved'), findsOneWidget);
    });

    testWidgets('Practise N shaky starts a session on those rows', (tester) async {
      final visited = await pump(tester, result());
      await tester.tap(find.text('Practise 2 shaky words'));
      await tester.pumpAndSettle();
      expect(visited.single, contains('row-ids=b%2Cc'));
      expect(visited.single, contains('split=false'));
    });

    testWidgets('Next group only when split; it skips the played group', (tester) async {
      final visited = await pump(tester, result(groupCount: 3));
      await tester.tap(find.text('Next group'));
      await tester.pumpAndSettle();
      expect(visited.single, contains('skip-group=1'));
    });

    testWidgets('talk shows the unused line; none when 0', (tester) async {
      await pump(tester, result(kind: SessionKind.talk, unused: 4));
      expect(find.text('4 words not used — unchanged'), findsOneWidget);
      expect(find.textContaining('pages'), findsNothing);
    });

    testWidgets('Done pops back', (tester) async {
      await pump(tester, result());
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('table'), findsOneWidget);
    });
  });
}

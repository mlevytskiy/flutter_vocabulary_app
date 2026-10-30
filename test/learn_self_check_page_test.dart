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
import 'package:flutter_vocabulary_app/features/learn/session/learning_session_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/session/learning_session_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_registry.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

/// self-check-cards T6 (AC-03, AC-04): the session screen shows a missed
/// word's self-check card as a page in the learn frame, 3 pages later; its
/// rating moves on and reaches the box when the session ends.

class _Input extends WordsNotifier {
  _Input(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

class _Store implements CollectionStore {
  _Store(this.collection);
  final WordCollection collection;

  @override
  Future<String?> currentCollectionId() async => collection.collectionId;

  @override
  Future<WordCollection?> byId(String collectionId) async => collection;

  @override
  Future<bool> update(String collectionId, void Function(WordCollection) change) async {
    change(collection);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _NoNetwork implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('the session asked the server');
}

PageSource _source(String id) => (PageInput input) async => [
      for (final w in input.words)
        ExercisePage(
          exerciseId: id,
          exerciseName: id,
          step: stepOf(id),
          rowIds: [w.rowId],
          body: (context, answer) => Text('$id ${w.rowId}'),
        ),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a missed word gets a card page, no Check or verdict bar; the rating reaches the box', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final collection = WordCollection.create()
      ..collectionId = 'c1'
      ..words = [for (var i = 0; i < 6; i++) WordPair(word: 'word$i', translation: 'слово$i', definition: '', rowId: 'r$i')];
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => _Store(collection)),
      exerciseRandomProvider.overrideWithValue(Random(1)),
      learnApiServiceProvider.overrideWithValue(_NoNetwork()),
      wordsProvider.overrideWith(() => _Input(collection)),
      pageSourcesProvider.overrideWithValue({for (final id in pageExerciseIds) id: _source(id)}),
    ]);
    addTearDown(c.dispose);
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(body: TextButton(onPressed: () => context.push('/words/table/session'), child: const Text('table'))),
        routes: [
          GoRoute(
            path: 'words/table/session',
            builder: (_, __) => const LearningSessionScreen(),
            routes: [GoRoute(path: 'results', builder: (_, __) => const Scaffold(body: Text('results')))],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('table'));
    await tester.pumpAndSettle();

    final provider = learningSessionProvider(null);
    c.listen(provider, (_, __) {});
    final session = c.read(provider.notifier);
    LearningSessionState state() => c.read(provider);

    final missed = state().page!.rowIds.single;
    session.answer({missed: false});
    await tester.pump();
    await session.next();
    await tester.pumpAndSettle();

    var shown = 0;
    while (state().checkCard == null && state().status == SessionStatus.playing) {
      final id = state().page!.rowIds.single;
      session.answer({id: true});
      await session.next();
      await tester.pumpAndSettle();
      shown++;
    }
    expect(state().checkCard, missed);
    expect(shown, greaterThanOrEqualTo(3), reason: 'the card comes 3 pages after the miss');
    expect(find.byKey(const ValueKey('self-check-card')), findsOneWidget);
    expect(find.text('Check'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('${state().pageNumber} / ${state().pageTotal}'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('self-check-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rate-hard')));
    await tester.pumpAndSettle();
    expect(state().checkCard, isNull);

    while (state().status == SessionStatus.playing) {
      final id = state().page!.rowIds.single;
      session.answer({id: true});
      await session.next();
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    expect(state().status, SessionStatus.finished);
    final box = collection.boxes.firstWhere((b) => b.rowId == missed);
    expect(box.lastCheckSide, 'uk', reason: 'the side shown is stored');
    expect(box.box, 1, reason: 'Hard on a new word leads to box 1');
  });
}

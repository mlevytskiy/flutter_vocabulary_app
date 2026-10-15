import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/quiz/quiz_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/anki_export.dart';

/// Translate sentences data: one fair card per word.
class _TranslateApi implements LearnApiService {
  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async => {
        for (final w in words) w.rowId: (source: 'Ми бачили ${w.translation}.', cue: w.translation, model: 'We saw ${w.word}.') as T,
      };

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

/// No gap sentences: the Quiz runs choice only (learn-quiz AC-08).
class _OfflineApi implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw LearnApiException(LearnApiError.network, 'offline');
}

/// learn-kit S-22: the Step 3 word results on a session (AC-35 – AC-38).
/// One Isar store for the whole file (docs/testing.md rule 4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SessionStore store;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('word_result_test');
    store = await SessionStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final t0 = DateTime.utc(2026, 10, 14, 12);

  Session session(String id) => Session.create()
    ..sessionId = id
    ..updatedAt = t0
    ..lastLocalModifiedAt = t0
    ..words = [WordPair(word: 'walk', translation: 'гуляти', rowId: 'r1')];

  WordResult result(String rowId, WordResultLabel label, DateTime at,
          {String exercise = 'quiz'}) =>
      WordResult()
        ..rowId = rowId
        ..exerciseId = exercise
        ..label = label
        ..at = at;

  test('the label keeps its stored order: known first, then repeat', () {
    expect(WordResultLabel.values, [WordResultLabel.known, WordResultLabel.repeat]);
  });

  test('AC-38: a session has no results until one is written; JSON round-trips them', () {
    final s = session('json');
    expect(s.results, isEmpty);
    s.results = [result('r1', WordResultLabel.repeat, t0)];
    final back = Session.fromJson(s.toJson());
    expect(back.results.single.rowId, 'r1');
    expect(back.results.single.exerciseId, 'quiz');
    expect(back.results.single.label, WordResultLabel.repeat);
    expect(back.results.single.at, t0);
    // JSON from before learn-kit has no results.
    final old = s.toJson()..remove('results');
    expect(Session.fromJson(old).results, isEmpty);
  });

  test('AC-35, AC-37: appendResult saves at once and moves neither time', () async {
    await store.put(session('append'));
    expect(await store.appendResult('append', result('r1', WordResultLabel.known, t0)), isTrue);
    await store.appendResult('append', result('r1', WordResultLabel.repeat, t0.add(const Duration(minutes: 1))));
    final read = (await store.byId('append'))!;
    expect(read.results.map((r) => r.label), [WordResultLabel.known, WordResultLabel.repeat]);
    expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
    expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
  });

  test('appendResult on an unknown session writes nothing and says so', () async {
    expect(await store.appendResult('nope', result('r1', WordResultLabel.known, t0)), isFalse);
    expect(await store.byId('nope'), isNull);
  });

  test('a later put of a stale session object keeps the stored results', () async {
    final s = session('stale');
    await store.put(s);
    await store.appendResult('stale', result('r1', WordResultLabel.known, t0));
    // The words notifier still holds `s`, which never saw the result.
    s.words.add(WordPair(word: 'run', translation: 'бігти', rowId: 'r2'));
    await store.put(s);
    final read = (await store.byId('stale'))!;
    expect(read.words.length, 2);
    expect(read.results.single.rowId, 'r1');
  });

  test('AC-38: the 2001st result drops the oldest', () async {
    final s = session('cap')
      ..results = [
        for (var i = 0; i < Session.maxResults; i++)
          result('r$i', WordResultLabel.known, t0.add(Duration(seconds: i))),
      ];
    await store.put(s);
    expect((await store.byId('cap'))!.results.length, Session.maxResults);
    await store.appendResult('cap', result('new', WordResultLabel.repeat, t0.add(const Duration(days: 1))));
    final read = (await store.byId('cap'))!;
    expect(read.results.length, Session.maxResults);
    expect(read.results.first.rowId, 'r1');
    expect(read.results.last.rowId, 'new');
  });

  test('AC-37: results never reach a word row', () {
    final s = session('rows')..results = [result('r1', WordResultLabel.repeat, t0)];
    expect(s.words.single.toJson().toString(), isNot(contains('repeat')));
  });

  group('ExamResultSink (S-23)', () {
    late DateTime now;
    late ExamResultSink sink;

    setUp(() {
      now = t0;
      sink = StoreExamResultSink(() async => store, clock: () => now);
    });

    test('AC-35: record saves the word, the exercise and the time on that session at once', () async {
      await store.put(session('sink'));
      await sink.record(sessionId: 'sink', rowId: 'r1', exerciseId: 'own-sentences', label: WordResultLabel.repeat);
      final r = (await store.byId('sink'))!.results.single;
      expect((r.rowId, r.exerciseId, r.label), ('r1', 'own-sentences', WordResultLabel.repeat));
      expect(r.at.isAtSameMomentAs(t0), isTrue);
    });

    test('no session id means the current session', () async {
      await store.put(session('current'));
      await store.setCurrentSessionId('current');
      await sink.record(sessionId: null, rowId: 'r1', exerciseId: 'quiz', label: WordResultLabel.known);
      expect((await store.byId('current'))!.results.single.label, WordResultLabel.known);
    });

    test('an empty rowId is not written', () async {
      await store.put(session('empty'));
      await sink.record(sessionId: 'empty', rowId: '', exerciseId: 'quiz', label: WordResultLabel.known);
      expect((await store.byId('empty'))!.results, isEmpty);
    });

    test("AC-35: a word's current result is its most recent one from any exam", () async {
      await store.put(session('latest')..words.add(WordPair(word: 'run', translation: 'бігти', rowId: 'r2')));
      await sink.record(sessionId: 'latest', rowId: 'r1', exerciseId: 'quiz', label: WordResultLabel.repeat);
      now = t0.add(const Duration(minutes: 5));
      await sink.record(sessionId: 'latest', rowId: 'r1', exerciseId: 'translate-sentences', label: WordResultLabel.known);
      await sink.record(sessionId: 'latest', rowId: 'r2', exerciseId: 'quiz', label: WordResultLabel.repeat);
      final latest = sink.latest((await store.byId('latest'))!);
      expect(latest['r1']!.label, WordResultLabel.known);
      expect(latest['r1']!.exerciseId, 'translate-sentences');
      expect(latest['r2']!.label, WordResultLabel.repeat);
    });

    test('AC-36, AC-37: a word never examined has no result; a deleted row is ignored', () async {
      final s = session('ignored')
        ..results = [result('deleted-row', WordResultLabel.repeat, t0)];
      expect(sink.latest(s), isEmpty);
    });

    test('learn-quiz AC-19, AC-22: a Quiz answer saves one result and moves no time, row or export', () async {
      final words = [
        for (var i = 0; i < 5; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 'q$i'),
      ];
      final s = session('quiz')..words = words;
      await store.put(s);
      final anki = generateAnkiFile((await store.byId('quiz'))!.words);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        learnApiServiceProvider.overrideWithValue(_OfflineApi()),
        exerciseWordsProvider('quiz', 'g').overrideWith((ref) async => (group: words, others: const <WordPair>[])),
        exerciseDialoguesProvider('quiz').overrideWith((ref) async => const []),
      ]);
      addTearDown(container.dispose);
      final quiz = await container.read(quizProvider('quiz', 'g').future);
      final asked = quiz.question!;
      container.read(quizProvider('quiz', 'g').notifier).pick(asked.choice!.rightIndex);
      // The quiz does not wait for the save; wait here until it lands.
      var read = (await store.byId('quiz'))!;
      for (var i = 0; i < 100 && read.results.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        read = (await store.byId('quiz'))!;
      }
      final r = read.results.single;
      expect((r.rowId, r.exerciseId, r.label), (asked.rowId, 'quiz', WordResultLabel.known));
      expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
      expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
      expect(generateAnkiFile(read.words), anki);
      expect(read.words.map((w) => w.toJson().toString()).join(), isNot(contains('known')));
    });

    test('learn-translate-sentences AC-22, AC-26: a final word saves one result and moves no time, row or export', () async {
      final words = [
        for (var i = 0; i < 3; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 't$i'),
      ];
      final s = session('trans')..words = words;
      await store.put(s);
      final anki = generateAnkiFile((await store.byId('trans'))!.words);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        learnApiServiceProvider.overrideWithValue(_TranslateApi()),
        exerciseWordsProvider('trans', 'g').overrideWith((ref) async => (group: words, others: const <WordPair>[])),
      ]);
      addTearDown(container.dispose);
      final state = await container.read(translateSentencesProvider('trans', 'g').future);
      final asked = state.card!;
      container
          .read(translateSentencesProvider('trans', 'g').notifier)
          .done(SentenceResult.checked('We saw it.', const CheckRight()));
      var read = (await store.byId('trans'))!;
      for (var i = 0; i < 100 && read.results.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        read = (await store.byId('trans'))!;
      }
      final r = read.results.single;
      expect((r.rowId, r.exerciseId, r.label), (asked.rowId, 'translate-sentences', WordResultLabel.known));
      expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
      expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
      expect(generateAnkiFile(read.words), anki);
    });

    test('learn-own-sentences AC-24, AC-28: a final word saves one result and moves no time, row or export', () async {
      final words = [
        for (var i = 0; i < 3; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 'o$i'),
      ];
      final s = session('own')..words = words;
      await store.put(s);
      final anki = generateAnkiFile((await store.byId('own'))!.words);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        exerciseWordsProvider('own', 'g').overrideWith((ref) async => (group: words, others: const <WordPair>[])),
      ]);
      addTearDown(container.dispose);
      final state = await container.read(ownSentencesProvider('own', 'g').future);
      final asked = state.card!;
      container
          .read(ownSentencesProvider('own', 'g').notifier)
          .done(SentenceResult.checked('We saw it.', const CheckFixed(fixed: 'We saw it!', note: 'n')));
      var read = (await store.byId('own'))!;
      for (var i = 0; i < 100 && read.results.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        read = (await store.byId('own'))!;
      }
      final r = read.results.single;
      expect((r.rowId, r.exerciseId, r.label), (asked.rowId, 'own-sentences', WordResultLabel.repeat));
      expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
      expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
      expect(generateAnkiFile(read.words), anki);
    });

    test('learn-explain-to-friend AC-31, AC-35: a timed-out Type word saves one repeat and moves no time, row or export',
        () async {
      final words = [
        for (var i = 0; i < 3; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 'e$i'),
      ];
      final s = session('explain')..words = words;
      await store.put(s);
      final anki = generateAnkiFile((await store.byId('explain'))!.words);
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        exerciseWordsProvider('explain', 'g').overrideWith((ref) async => (group: words, others: const <WordPair>[])),
      ]);
      addTearDown(container.dispose);
      await container.read(explainToFriendProvider('explain', 'g').future);
      final n = container.read(explainToFriendProvider('explain', 'g').notifier)..chooseMode(ExplainMode.type);
      final asked = container.read(explainToFriendProvider('explain', 'g')).requireValue.card!;
      n.done(const SentenceResult(outcome: SentenceOutcome.skipped, sentence: '', timedOut: true));
      var read = (await store.byId('explain'))!;
      for (var i = 0; i < 100 && read.results.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        read = (await store.byId('explain'))!;
      }
      final r = read.results.single;
      expect((r.rowId, r.exerciseId, r.label), (asked.rowId, 'explain-to-friend', WordResultLabel.repeat));
      expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
      expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
      expect(generateAnkiFile(read.words), anki);
    });

    test('the provider gives a sink over the session store', () {
      final container = ProviderContainer(overrides: [sessionStoreProvider.overrideWith((ref) async => store)]);
      addTearDown(container.dispose);
      expect(container.read(examResultSinkProvider), isA<StoreExamResultSink>());
    });
  });
}

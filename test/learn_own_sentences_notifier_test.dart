import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_notifier.dart';

/// learn-own-sentences: usable words, rounds, word results, summary
/// (AC-02 – AC-05, AC-06, AC-24 – AC-26, AC-29).


class _Api implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('no Worker call expected: ${i.memberName}');
}

typedef _Record = ({String? sessionId, String rowId, String exerciseId, WordResultLabel label});

class _Sink implements ExamResultSink {
  final records = <_Record>[];

  @override
  Future<void> record({
    required String? sessionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    records.add((sessionId: sessionId, rowId: rowId, exerciseId: exerciseId, label: label));
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(Session session) => const {};
}

SentenceResult _checked(String s, {bool right = true, String fixed = 'x'}) =>
    SentenceResult.checked(s, right ? const CheckRight() : CheckFixed(fixed: fixed, note: 'n'));

void main() {
  late _Sink sink;

  WordPair w(int i, {String? word, String? translation, String? rowId}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: rowId ?? 'r$i');
  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  ProviderContainer open(List<WordPair> group, {String? sessionId, int seed = 1}) {
    sink = _Sink();
    final c = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(_Api()),
      examResultSinkProvider.overrideWithValue(sink),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseWordsProvider(sessionId, 'g').overrideWith((ref) async => (group: group, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<OwnState> load(ProviderContainer c, {String? sessionId}) => c.read(ownSentencesProvider(sessionId, 'g').future);
  OwnSentences notifier(ProviderContainer c, {String? sessionId}) => c.read(ownSentencesProvider(sessionId, 'g').notifier);
  OwnState now(ProviderContainer c, {String? sessionId}) => c.read(ownSentencesProvider(sessionId, 'g')).requireValue;

  group('rounds (AC-02, AC-03)', () {
    for (final (n, sizes) in [
      (3, [3]),
      (5, [5]),
      (6, [3, 3]),
      (9, [5, 4]),
      (11, [4, 4, 3]),
      (19, [5, 5, 5, 4]),
    ]) {
      test('$n words: $sizes in group order, shuffled inside', () async {
        final s = await load(open(words(n)));
        expect([for (final r in s.rounds) r.length], sizes);
        var at = 0;
        for (final r in s.rounds) {
          expect({for (final x in r) x.rowId}, {for (var i = at; i < at + r.length; i++) 'r$i'});
          at += r.length;
        }
      });
    }

    test('same seed, same order; another seed changes only the order inside rounds', () async {
      final a = await load(open(words(9), seed: 5));
      final b = await load(open(words(9), seed: 5));
      expect([for (final r in a.rounds) [for (final x in r) x.rowId]], [for (final r in b.rounds) [for (final x in r) x.rowId]]);
      final d = await load(open(words(9), seed: 6));
      for (var i = 0; i < 2; i++) {
        expect({for (final x in d.rounds[i]) x.rowId}, {for (final x in a.rounds[i]) x.rowId});
      }
    });
  });

  group('usable words (AC-04 – AC-06)', () {
    test('fewer than 3 usable words: not enough', () async {
      final s = await load(open([w(0), w(1), w(2, translation: '  ')]));
      expect(s.phase, isA<ExerciseNotEnough>());
    });

    test('a word without translation, word or row id is never asked (AC-05)', () async {
      final s = await load(open([...words(3), w(3, translation: ''), w(4, word: ' '), w(5, rowId: '')]));
      expect({for (final r in s.rounds) for (final x in r) x.rowId}, {'r0', 'r1', 'r2'});
    });

    test('two rows with the same word are both asked', () async {
      final s = await load(open([w(0, word: 'bank'), w(1, word: 'bank'), w(2)]));
      expect(s.rounds.single, hasLength(3));
    });

    test('a failed read is an error and Retry reads again (AC-06)', () async {
      var fail = true;
      final c = ProviderContainer(overrides: [
        learnApiServiceProvider.overrideWithValue(_Api()),
        examResultSinkProvider.overrideWithValue(_Sink()),
        exerciseWordsProvider(null, 'g').overrideWith((ref) async {
          if (fail) throw StateError('x');
          return (group: words(3), others: const <WordPair>[]);
        }),
      ]);
      addTearDown(c.dispose);
      await expectLater(c.read(ownSentencesProvider(null, 'g').future), throwsA(isA<StateError>()));
      fail = false;
      c.read(ownSentencesProvider(null, 'g').notifier).retry();
      expect((await c.read(ownSentencesProvider(null, 'g').future)).rounds, hasLength(1));
    });
  });

  group('word results (AC-24 – AC-26)', () {
    test('a final word records exactly once with the session id and exercise id; none for not checked', () async {
      final c = open(words(4), sessionId: 's1');
      await load(c, sessionId: 's1');
      final n = notifier(c, sessionId: 's1');
      n.done(_checked('A b.'));
      n.done(_checked('A b.', right: false)); // second call ignored
      expect(sink.records, hasLength(1));
      expect(sink.records.single.sessionId, 's1');
      expect(sink.records.single.exerciseId, 'own-sentences');
      expect(sink.records.single.label, WordResultLabel.known);
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.skipped, sentence: ''));
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'x y'));
      expect(sink.records.map((r) => r.label), [WordResultLabel.known, WordResultLabel.repeat]);
      n.next();
      n.done(_checked('c d', right: false));
      n.next();
      expect(sink.records, hasLength(3));
      expect(now(c, sessionId: 's1').inSummary, isTrue);
    });

    test('Next, Next round and the summary record nothing; next needs a final word', () async {
      final c = open(words(6));
      await load(c);
      final n = notifier(c);
      n.next();
      expect(now(c).index, 0);
      for (var i = 0; i < 3; i++) {
        n.done(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'a b'));
        n.next();
      }
      n.nextRound();
      expect(now(c).round, 1);
      expect(now(c).index, 0);
      expect(sink.records, isEmpty);
    });
  });

  group('summary (AC-29, AC-30)', () {
    test('ownDetail by outcome', () {
      expect(ownDetail(_checked('We sat on the shore.')), 'Yours: We sat on the shore.');
      expect(ownDetail(_checked('I borrow a book yesterday.', right: false, fixed: 'I borrowed a book.')),
          'Answer: I borrowed a book. · Yours: I borrow a book yesterday.');
      expect(ownDetail(_checked('I sat.', right: false, fixed: '')), 'Yours: I sat.');
      expect(ownDetail(const SentenceResult(outcome: SentenceOutcome.skipped, sentence: '')), 'Skipped');
      expect(ownDetail(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'They allow us.')), 'Yours: They allow us.');
    });

    test('known/repeat/skipped/not checked with details in asked order', () async {
      final c = open(words(4));
      await load(c);
      final n = notifier(c);
      final order = now(c).cards.map((x) => x.word).toList();
      n.done(_checked('We sat on the shore.'));
      n.next();
      n.done(_checked('I borrow a book yesterday.', right: false, fixed: 'I borrowed a book.'));
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.skipped, sentence: ''));
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'They allow us to go.'));
      n.next();
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.heading, '1 of 4 known');
      expect(phase.hasNextRound, isFalse);
      expect(phase.againLabel, isNull);
      expect([for (final o in phase.outcomes) o.word], order);
      expect([for (final o in phase.outcomes) o.result], ['Known', 'Repeat', 'Repeat', 'Not checked']);
      expect([for (final o in phase.outcomes) o.detail], [
        'Yours: We sat on the shore.',
        'Answer: I borrowed a book. · Yours: I borrow a book yesterday.',
        'Skipped',
        'Yours: They allow us to go.',
      ]);
    });

    test('Next round shows when a round follows; the round counter restarts', () async {
      final c = open(words(6));
      await load(c);
      final n = notifier(c);
      expect((now(c).phase as ExerciseRound).count, 2);
      for (var i = 0; i < 3; i++) {
        n.done(_checked('a b'));
        n.next();
      }
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.hasNextRound, isTrue);
      expect(phase.heading, '3 of 3 known');
      n.nextRound();
      expect(now(c).phase, isA<ExerciseRound>());
      expect(now(c).index, 0);
    });
  });
}

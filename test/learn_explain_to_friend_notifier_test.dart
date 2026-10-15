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
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';

/// learn-explain-to-friend: usable words, mode, rounds, word results, friend
/// answers and summary (AC-02 – AC-06, AC-27 – AC-33, AC-36 – AC-38; §6).
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

SentenceResult _checked(String s, {bool right = true}) =>
    SentenceResult.checked(s, right ? const CheckRight() : const CheckFixed(fixed: '', note: 'n'));
const _skipped = SentenceResult(outcome: SentenceOutcome.skipped, sentence: '');
const _timedOut = SentenceResult(outcome: SentenceOutcome.skipped, sentence: '', timedOut: true);

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

  Future<ExplainState> load(ProviderContainer c, {String? sessionId}) => c.read(explainToFriendProvider(sessionId, 'g').future);
  ExplainToFriend notifier(ProviderContainer c, {String? sessionId}) => c.read(explainToFriendProvider(sessionId, 'g').notifier);
  ExplainState now(ProviderContainer c, {String? sessionId}) => c.read(explainToFriendProvider(sessionId, 'g')).requireValue;

  group('rounds and mode (AC-02, AC-03)', () {
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

    test('same seed, same order, in both modes', () async {
      final a = open(words(9), seed: 5);
      await load(a);
      notifier(a).chooseMode(ExplainMode.type);
      final b = open(words(9), seed: 5);
      await load(b);
      notifier(b).chooseMode(ExplainMode.friend);
      List<List<String>> ids(ExplainState s) => [for (final r in s.rounds) [for (final x in r) x.rowId]];
      expect(ids(now(a)), ids(now(b)));
    });

    test('the mode is asked first and once; the round shows only after it', () async {
      final c = open(words(8));
      final s = await load(c);
      expect(s.mode, isNull);
      expect(s.card, isNull);
      expect(s.phase, isA<ExerciseRound>());
      notifier(c).chooseMode(ExplainMode.friend);
      expect(now(c).mode, ExplainMode.friend);
      expect(now(c).card, isNotNull);
      notifier(c).chooseMode(ExplainMode.type); // ignored
      expect(now(c).mode, ExplainMode.friend);
      final n = notifier(c);
      for (var i = 0; i < 4; i++) {
        n.friendReady();
        n.friendAnswer(FriendAnswer.understood);
        n.next();
      }
      n.nextRound();
      expect(now(c).round, 1);
      expect(now(c).mode, ExplainMode.friend);
      expect(now(c).cards, hasLength(4));
    });
  });

  group('usable words (AC-04 – AC-06)', () {
    test('fewer than 3 usable words: not enough, before any mode', () async {
      final s = await load(open([w(0), w(1), w(2, translation: '  ')]));
      expect(s.phase, isA<ExerciseNotEnough>());
      expect((await load(open(const []))).phase, isA<ExerciseNotEnough>());
    });

    test('a word without translation, word or row id is never asked (AC-05)', () async {
      final s = await load(open([...words(3), w(3, translation: ''), w(4, word: ' '), w(5, rowId: '')]));
      expect({for (final r in s.rounds) for (final x in r) x.rowId}, {'r0', 'r1', 'r2'});
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
      await expectLater(c.read(explainToFriendProvider(null, 'g').future), throwsA(isA<StateError>()));
      fail = false;
      c.read(explainToFriendProvider(null, 'g').notifier).retry();
      final s = await c.read(explainToFriendProvider(null, 'g').future);
      expect(s.rounds, hasLength(1));
      expect(s.mode, isNull);
    });
  });

  group('Type word results (AC-31 – AC-33)', () {
    test('a final word records exactly once with the session id and exercise id; time-out is repeat; none for not checked',
        () async {
      final c = open(words(4), sessionId: 's1');
      await load(c, sessionId: 's1');
      final n = notifier(c, sessionId: 's1');
      n.chooseMode(ExplainMode.type);
      n.done(_checked('Land by the sea.'));
      n.done(_checked('Land by the sea.', right: false)); // second call ignored
      expect(sink.records, hasLength(1));
      expect(sink.records.single.sessionId, 's1');
      expect(sink.records.single.exerciseId, 'explain-to-friend');
      expect(sink.records.single.rowId, now(c, sessionId: 's1').card!.rowId);
      expect(sink.records.single.label, WordResultLabel.known);
      n.next();
      n.done(_timedOut);
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'x y'));
      n.next();
      n.done(_checked('c d', right: false));
      expect(sink.records.map((r) => r.label), [WordResultLabel.known, WordResultLabel.repeat, WordResultLabel.repeat]);
      n.next();
      expect(now(c, sessionId: 's1').inSummary, isTrue);
      expect(sink.records, hasLength(3));
    });

    test('Next, Next round and the summary record nothing; next needs a final word; unreached rounds record nothing', () async {
      final c = open(words(6));
      await load(c);
      final n = notifier(c);
      n.done(_checked('a b')); // before a mode: ignored
      expect(sink.records, isEmpty);
      n.chooseMode(ExplainMode.type);
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

    test('friend calls do nothing in Type mode', () async {
      final c = open(words(3));
      await load(c);
      final n = notifier(c)..chooseMode(ExplainMode.type);
      n.friendReady();
      n.friendAnswer(FriendAnswer.understood);
      expect(now(c).result, isNull);
      expect(now(c).asking, isFalse);
    });
  });

  group('With a friend (AC-27 – AC-30)', () {
    test('Done or zero asks; a tap is final once; Skip only before the question; nothing is recorded', () async {
      final c = open(words(3));
      await load(c);
      final n = notifier(c)..chooseMode(ExplainMode.friend);
      n.friendAnswer(FriendAnswer.understood); // before the question: ignored
      expect(now(c).result, isNull);
      n.friendReady();
      expect(now(c).asking, isTrue);
      n.friendReady();
      n.friendAnswer(FriendAnswer.skipped); // Skip is gone once asked
      expect(now(c).result, isNull);
      n.friendAnswer(FriendAnswer.notYet);
      n.friendAnswer(FriendAnswer.understood); // second tap ignored
      expect(now(c).result!.friend, FriendAnswer.notYet);
      n.done(_checked('a b')); // a typed result does nothing in friend mode
      expect(now(c).result!.friend, FriendAnswer.notYet);
      n.next();
      expect(now(c).asking, isFalse);
      n.friendAnswer(FriendAnswer.skipped);
      expect(now(c).result!.friend, FriendAnswer.skipped);
      n.next();
      n.friendReady();
      n.friendAnswer(FriendAnswer.understood);
      n.next();
      expect(now(c).inSummary, isTrue);
      expect(sink.records, isEmpty);
    });
  });

  group('summary (AC-36 – AC-38)', () {
    test('explainDetail by result', () {
      expect(explainDetail(ExplainResult.typed(_checked('Land by the sea.'))), 'Yours: Land by the sea.');
      expect(explainDetail(ExplainResult.typed(_checked('To borrow money.', right: false))), 'Yours: To borrow money.');
      expect(explainDetail(const ExplainResult.typed(_skipped)), 'Skipped');
      expect(explainDetail(const ExplainResult.typed(_timedOut)), 'Time up');
      expect(explainDetail(const ExplainResult.typed(SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'Take it fast.'))),
          'Yours: Take it fast.');
      expect(explainDetail(const ExplainResult.friend(FriendAnswer.understood)), 'Understood');
      expect(explainDetail(const ExplainResult.friend(FriendAnswer.notYet)), 'Not yet');
      expect(explainDetail(const ExplainResult.friend(FriendAnswer.skipped)), 'Skipped');
    });

    test('AC-36: a Type round of 5 in asked order', () async {
      final c = open(words(5));
      await load(c);
      final n = notifier(c)..chooseMode(ExplainMode.type);
      final order = now(c).cards.map((x) => x.word).toList();
      for (final r in [
        _checked('Land by the sea.'),
        _checked('To borrow money.', right: false),
        _skipped,
        _timedOut,
        const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'Take it fast.'),
      ]) {
        n.done(r);
        n.next();
      }
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.heading, '1 of 5 known');
      expect(phase.hasNextRound, isFalse);
      expect(phase.againLabel, isNull);
      expect([for (final o in phase.outcomes) o.word], order);
      expect([for (final o in phase.outcomes) o.result], ['Known', 'Repeat', 'Repeat', 'Repeat', 'Not checked']);
      expect([for (final o in phase.outcomes) o.detail],
          ['Yours: Land by the sea.', 'Yours: To borrow money.', 'Skipped', 'Time up', 'Yours: Take it fast.']);
    });

    test('AC-37, AC-38: a friend round of 3, then Next round in the same mode', () async {
      final c = open(words(6));
      await load(c);
      final n = notifier(c)..chooseMode(ExplainMode.friend);
      n.friendReady();
      n.friendAnswer(FriendAnswer.understood);
      n.next();
      n.friendReady();
      n.friendAnswer(FriendAnswer.notYet);
      n.next();
      n.friendAnswer(FriendAnswer.skipped);
      n.next();
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.heading, '1 of 3 known');
      expect(phase.hasNextRound, isTrue);
      expect([for (final o in phase.outcomes) o.result], ['Known', 'Repeat', 'Repeat']);
      expect([for (final o in phase.outcomes) o.detail], ['Understood', 'Not yet', 'Skipped']);
      n.nextRound();
      expect(now(c).phase, isA<ExerciseRound>());
      expect(now(c).index, 0);
      expect(now(c).mode, ExplainMode.friend);
    });
  });
}

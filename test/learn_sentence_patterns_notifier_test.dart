import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';
import 'package:flutter_vocabulary_app/features/learn/sentence_patterns/sentence_patterns_notifier.dart';

/// learn-sentence-patterns: usable words, rounds, results and the summary
/// (AC-19 – AC-24, AC-26, AC-27; S-48, S-50).
class _Api implements LearnApiService {
  Object? error;
  final calls = <List<LearnWord>>[];
  final kinds = <String>[];

  /// Per word: a value to return instead of the default (null = "none").
  final answers = <String, PatternData?>{};

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    kinds.add(kind.wire);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (answers.containsKey(w.word)
            ? answers[w.word]
            : (sentence: 'The main ${w.word} was that we were late.', pattern: 'The main + [noun] + was that + [sentence]', usage: 'explain a reason')) as T?,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

const _right = SentenceResult(outcome: SentenceOutcome.right, sentence: 'a b', verdict: CheckRight());
const _fixed = SentenceResult(outcome: SentenceOutcome.fixed, sentence: 'a b', verdict: CheckFixed(fixed: 'A b.', note: 'n'));
const _skipped = SentenceResult(outcome: SentenceOutcome.skipped, sentence: '');
const _notChecked = SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'a b');

void main() {
  late _Api api;

  WordPair w(int i, {String? word, String? translation, String? rowId}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: rowId ?? 'r$i');

  ProviderContainer open(List<WordPair> g, {void Function(_Api api)? setup}) {
    api = _Api();
    setup?.call(api);
    final c = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: g, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<PatternsState> load(ProviderContainer c) => c.read(sentencePatternsProvider(null, 'g').future);
  SentencePatterns notifier(ProviderContainer c) => c.read(sentencePatternsProvider(null, 'g').notifier);
  PatternsState now(ProviderContainer c) => c.read(sentencePatternsProvider(null, 'g')).requireValue;

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  void finish(ProviderContainer c, SentenceResult r) {
    notifier(c).startWriting();
    notifier(c).done(r);
    notifier(c).next();
  }

  group('opening', () {
    test('AC-19: one data call of kind pattern for exactly the words, trimmed, with translations', () async {
      final c = open([for (var i = 0; i < 6; i++) w(i, word: ' word$i ', translation: ' слово$i ')]);
      final s = await load(c);
      expect(api.calls, hasLength(1));
      expect(api.kinds, ['pattern']);
      expect(api.calls.single, [for (var i = 0; i < 6; i++) (rowId: 'r$i', word: 'word$i', translation: 'слово$i')]);
      final card = s.card!;
      expect((card.rowId, card.word, card.translation), ('r0', 'word0', 'слово0'));
      expect(card.sentence, 'The main word0 was that we were late.');
      expect(card.pattern, 'The main + [noun] + was that + [sentence]');
      expect(card.usage, 'explain a reason');
      expect(s.writing, isFalse);
    });

    test('AC-21: rounds of 3 to 9 in group order', () async {
      Future<List<int>> sizes(int n) async => [for (final r in (await load(open(words(n)))).rounds) r.length];
      expect(await sizes(12), [6, 6]);
      expect(await sizes(19), [7, 6, 6]);
      expect(await sizes(9), [9]);
      expect(await sizes(3), [3]);
      final s = await load(open(words(12)));
      expect(s.rounds.first.map((q) => q.rowId), [for (var i = 0; i < 6; i++) 'r$i']);
      expect(s.phase, isA<ExerciseRound>());
    });

    test('AC-22: under 3 words to learn with a translation: not enough and no call', () async {
      for (final g in [<WordPair>[], words(2), [w(0), w(1), w(2, translation: ' ')]]) {
        final c = open(g);
        final phase = (await load(c)).phase;
        expect(phase, isA<ExerciseNotEnough>());
        expect((phase as ExerciseNotEnough).message, isNull);
        expect(api.calls, isEmpty);
      }
    });

    test('AC-20: a word with no translation is never sent; a "none" answer or a sentence without the word once is left out', () async {
      final c = open(
        [w(0), w(1, word: 'none'), w(2, word: 'twice'), w(3, word: 'missing'), w(4, translation: ''), w(5), w(6, word: 'walk')],
        setup: (api) => api.answers
          ..['none'] = null
          ..['twice'] = (sentence: 'Twice and twice again.', pattern: '[noun]', usage: 'u')
          ..['missing'] = (sentence: 'Nothing here at all.', pattern: '[noun]', usage: 'u')
          ..['walk'] = (sentence: 'In the end, we walked home.', pattern: 'In the end, + we + [verb in Past Simple]', usage: 'u'),
      );
      final s = await load(c);
      expect(api.calls.single.map((x) => x.rowId), ['r0', 'r1', 'r2', 'r3', 'r5', 'r6']);
      expect(s.rounds.expand((r) => r).map((q) => q.rowId), ['r0', 'r5', 'r6']);
    });

    test('AC-23: 3 or more candidates but under 3 usable: not enough', () async {
      final c = open(words(4), setup: (api) => api.answers..['word0'] = null..['word1'] = null);
      expect((await load(c)).phase, isA<ExerciseNotEnough>());
      expect(api.calls, hasLength(1));
    });

    test('AC-24: a failed load is an error; Retry asks again', () async {
      final c = open(words(3), setup: (api) => api.error = LearnApiException(LearnApiError.network, 'x'));
      await expectLater(load(c), throwsA(isA<LearnApiException>()));
      expect(failureOf(c.read(sentencePatternsProvider(null, 'g')).error!), ExerciseFailure.network);
      api.error = null;
      notifier(c).retry();
      final s = await load(c);
      expect(s.card!.rowId, 'r0');
      expect(api.calls, hasLength(2));
    });
  });

  group('playing', () {
    test('AC-05, AC-13: My turn, a final result, then Next shows the next card without the field', () async {
      final c = open(words(5));
      await load(c);
      notifier(c).next(); // no result yet: nothing happens
      expect(now(c).index, 0);
      notifier(c).done(_right); // before My turn: ignored
      expect(now(c).result, isNull);
      notifier(c).startWriting();
      expect(now(c).writing, isTrue);
      notifier(c).done(_right);
      notifier(c).done(_fixed); // a second result for the same word is ignored
      expect(now(c).result!.outcome, SentenceOutcome.right);
      notifier(c).next();
      expect(now(c).index, 1);
      expect(now(c).writing, isFalse);
      expect(now(c).result, isNull);
    });

    test('AC-26: the summary lists the words in group order with practice labels, no heading', () async {
      final c = open(words(5));
      await load(c);
      final rs = [_right, _fixed, _skipped, _notChecked, _right];
      for (final r in rs) {
        finish(c, r);
      }
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.outcomes.map((o) => o.rowId), ['r0', 'r1', 'r2', 'r3', 'r4']);
      expect(phase.outcomes.map((o) => o.word), ['word0', 'word1', 'word2', 'word3', 'word4']);
      expect(phase.outcomes.map((o) => o.result), ['Right', 'Fixed', 'Skipped', 'Skipped', 'Right']);
      expect(phase.heading, isNull);
      expect(phase.hasNextRound, isFalse);
    });

    test('AC-21, AC-26: Next round starts the next round at its first card', () async {
      final c = open(words(12));
      await load(c);
      for (var i = 0; i < 6; i++) {
        finish(c, _right);
      }
      expect((now(c).phase as ExerciseSummary).hasNextRound, isTrue);
      notifier(c).nextRound();
      final s = now(c);
      expect((s.round, s.index, s.card!.rowId), (1, 0, 'r6'));
      expect(s.phase, isA<ExerciseRound>());
    });

    test('AC-27: playing never writes the words', () async {
      final g = words(3);
      final before = [for (final x in g) (x.word, x.translation, x.rowId)];
      final c = open(g);
      await load(c);
      for (var i = 0; i < 3; i++) {
        finish(c, _fixed);
      }
      expect([for (final x in g) (x.word, x.translation, x.rowId)], before);
    });
  });
}

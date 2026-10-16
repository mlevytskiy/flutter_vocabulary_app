import 'dart:async';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
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
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_notifier.dart';

/// learn-translate-sentences: usable words, rounds, word results, summary
/// (AC-02 – AC-08, AC-21 – AC-24, AC-27, AC-28).

class _Api implements LearnApiService {
  Object? error;
  final noSentence = <String>{};
  final unfair = <String, TranslateData>{};
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    expect(kind, LearnDataKind.translate);
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: noSentence.contains(w.word)
            ? null
            : (unfair[w.word] ?? (source: 'Ми бачили ${w.translation} там.', cue: w.translation, model: 'We saw ${w.word} there.')) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

typedef _Record = ({String? collectionId, String rowId, String exerciseId, WordResultLabel label});

class _Sink implements ExamResultSink {
  final records = <_Record>[];

  @override
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    records.add((collectionId: collectionId, rowId: rowId, exerciseId: exerciseId, label: label));
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(WordCollection collection) => const {};
}

SentenceResult _checked(String s, {bool right = true}) =>
    SentenceResult.checked(s, right ? const CheckRight() : const CheckFixed(fixed: 'x', note: 'n'));

void main() {
  late _Api api;
  late _Sink sink;

  WordPair w(int i, {String? word, String? translation, String? rowId}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: rowId ?? 'r$i');
  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  ProviderContainer open(List<WordPair> group, {String? collectionId, int seed = 1}) {
    api = _Api();
    sink = _Sink();
    final c = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      examResultSinkProvider.overrideWithValue(sink),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseWordsProvider(collectionId, 'g').overrideWith((ref) async => (group: group, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<TranslateState> load(ProviderContainer c, {String? collectionId}) =>
      c.read(translateSentencesProvider(collectionId, 'g').future);
  TranslateSentences notifier(ProviderContainer c, {String? collectionId}) =>
      c.read(translateSentencesProvider(collectionId, 'g').notifier);
  TranslateState now(ProviderContainer c, {String? collectionId}) =>
      c.read(translateSentencesProvider(collectionId, 'g')).requireValue;

  group('cueSpans', () {
    test('only the first occurrence of the cue is bold', () {
      final spans = cueSpans('Ми на березі і на березі.', 'березі');
      expect([for (final s in spans) s.text], ['Ми на ', 'березі', ' і на березі.']);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[0].style, isNull);
    });
    test('a missing cue leaves the sentence plain', () {
      expect([for (final s in cueSpans('Ми тут.', 'берег')) s.text], ['Ми тут.']);
    });
  });

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
        final c = open(words(n));
        final s = await load(c);
        expect([for (final r in s.rounds) r.length], sizes);
        var at = 0;
        for (final r in s.rounds) {
          final expected = {for (var i = at; i < at + r.length; i++) 'r$i'};
          expect({for (final x in r) x.rowId}, expected);
          at += r.length;
        }
        expect(api.calls, hasLength(1));
        expect(api.calls.single.map((x) => x.rowId), [for (var i = 0; i < n; i++) 'r$i']);
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

  group('usable words (AC-04 – AC-08)', () {
    test('fewer than 3 candidates: not enough, no Worker call', () async {
      final c = open([w(0), w(1), w(2, translation: '  ')]);
      final s = await load(c);
      expect(s.phase, isA<ExerciseNotEnough>());
      expect(api.calls, isEmpty);
    });

    test('words without a translation, word or row id are not sent; the rest once with translations', () async {
      final c = open([...words(5), w(5, translation: ''), w(6, rowId: '')]);
      await load(c);
      expect(api.calls.single.map((x) => x.rowId), ['r0', 'r1', 'r2', 'r3', 'r4']);
      expect(api.calls.single.first.translation, 'слово0');
    });

    test('unfair data drops the word; fewer than 3 left is not enough', () async {
      final c = open(words(5));
      api.noSentence.add('word0');
      api.unfair['word1'] = (source: 'Ми бачили word1 там.', cue: 'word1', model: 'We saw word1 there.');
      api.unfair['word2'] = (source: 'Ми бачили слово2.', cue: 'нема', model: 'We saw word2.');
      final s = await load(c);
      expect(s.phase, isA<ExerciseNotEnough>());
    });

    test('each drop rule leaves only the fair words', () async {
      final c = open(words(9));
      api.noSentence.add('word0');
      api.unfair['word1'] = (source: 'We have word1.', cue: 'word1', model: 'We saw word1.'); // English word
      api.unfair['word2'] = (source: 'Ми бачили слово2.', cue: 'нема', model: 'We saw word2.'); // cue not in source
      api.unfair['word3'] = (source: 'Ми бачили слово3.', cue: '', model: 'We saw word3.'); // empty cue
      api.unfair['word4'] = (source: 'Ми бачили слово4.', cue: 'слово4', model: 'We saw it.'); // model lacks word
      api.unfair['word5'] = (source: 'Ми бачили слово5.', cue: 'слово5', model: 'word5 and word5.'); // twice
      final s = await load(c);
      expect({for (final r in s.rounds) for (final x in r) x.rowId}, {'r6', 'r7', 'r8'});
    });

    test('another word of the group in the source drops the word', () async {
      final c = open(words(4));
      api.unfair['word0'] = (source: 'Ми бачили слово0 і word2.', cue: 'слово0', model: 'We saw word0.');
      final s = await load(c);
      expect({for (final r in s.rounds) for (final x in r) x.rowId}, {'r1', 'r2', 'r3'});
    });

    test('a failed load is an error, not a partial round', () async {
      final c = open(words(4));
      api.error = LearnApiException(LearnApiError.network, 'x');
      await expectLater(load(c), throwsA(isA<LearnApiException>()));
      expect(c.read(translateSentencesProvider(null, 'g')).hasError, isTrue);
    });
  });

  group('word results (AC-22 – AC-24)', () {
    test('a final word records exactly once with the session id and exercise id; none for not checked', () async {
      final c = open(words(4), collectionId: 's1');
      await load(c, collectionId: 's1');
      final n = notifier(c, collectionId: 's1');
      n.done(_checked('A b.'));
      n.done(_checked('A b.', right: false)); // second call ignored
      expect(sink.records, hasLength(1));
      expect(sink.records.single.collectionId, 's1');
      expect(sink.records.single.exerciseId, 'translate-sentences');
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
      expect(now(c, collectionId: 's1').inSummary, isTrue);
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

  group('summary (AC-27, AC-28)', () {
    test('known/repeat/skipped/not checked with details in asked order', () async {
      final c = open(words(4));
      await load(c);
      final n = notifier(c);
      final order = now(c).cards.map((x) => x.word).toList();
      n.done(_checked('We sat on the shore.'));
      n.next();
      n.done(_checked('I took a book.', right: false));
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.skipped, sentence: ''));
      n.next();
      n.done(const SentenceResult(outcome: SentenceOutcome.notChecked, sentence: 'They let us go.'));
      n.next();
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.heading, '1 of 4 known');
      expect(phase.hasNextRound, isFalse);
      expect(phase.againLabel, isNull);
      expect([for (final o in phase.outcomes) o.word], order);
      expect([for (final o in phase.outcomes) o.result], ['Known', 'Repeat', 'Repeat', 'Not checked']);
      String model(String word) => 'We saw $word there.';
      expect(phase.outcomes[0].detail, 'Yours: We sat on the shore.');
      expect(phase.outcomes[1].detail, 'Answer: ${model(order[1])} · Yours: I took a book.');
      expect(phase.outcomes[2].detail, 'Answer: ${model(order[2])} · Skipped');
      expect(phase.outcomes[3].detail, 'Answer: ${model(order[3])} · Yours: They let us go.');
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

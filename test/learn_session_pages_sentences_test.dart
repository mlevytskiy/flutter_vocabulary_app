import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_pages.dart';

/// learn-redesign T11: the page sources and page bodies of Make your own
/// sentences, Translate sentences and Explain it to a friend (AC-08, AC-10,
/// AC-15; sad §5.1 ExercisePage, ADR-0003).
class _Api implements LearnApiService {
  final fetches = <List<LearnWord>>[];
  final checks = <LearnCheckRequest>[];
  CheckReply reply = (usesWord: true, usesTask: true, ok: true, fixed: '', note: '');

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    expect(kind, LearnDataKind.translate);
    fetches.add(words);
    return {
      for (final w in words)
        // r2 gets an unusable reply: its model does not hold the word.
        w.rowId: (
          source: 'Ми довго сиділи на ${w.translation}і.',
          cue: '${w.translation}і',
          model: w.rowId == 'r2' ? 'We sat there for a long time.' : 'We sat by the ${w.word} for a long time.',
        ) as T,
    };
  }

  @override
  Future<CheckReply> check(LearnCheckRequest request) async {
    checks.add(request);
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

class _Sink implements ExamResultSink {
  final records = <String>[];

  @override
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    records.add('$exerciseId:$rowId:${label.name}');
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(WordCollection collection) => const {};
}

WordPair _w(int i, {String? translation}) => WordPair(word: 'word$i', translation: translation ?? 'берег$i', rowId: 'r$i');

void main() {
  late _Api api;
  late _Sink sink;

  setUp(() {
    api = _Api();
    sink = _Sink();
  });

  // r3 has no translation: no exercise can ask about it.
  final words = [_w(0), _w(1), _w(2), _w(3, translation: ' ')];
  PageInput input([List<WordPair>? ws]) =>
      PageInput(words: ws ?? words, others: const [], dialogues: const [], api: api, random: Random(1));

  group('page sources: one step-3 page per usable word', () {
    test('Make your own sentences', () async {
      final pages = await ownSentencesPages(input());
      expect([for (final p in pages) p.rowIds], [['r0'], ['r1'], ['r2']]);
      expect(pages.every((p) => p.step == 3 && p.exerciseId == ownExerciseId), isTrue);
      expect(pages.first.exerciseName, 'Make your own sentences');
    });

    test('Translate sentences: one fetch for the usable words, no page for an unusable reply', () async {
      final pages = await translateSentencesPages(input());
      expect(api.fetches.single.map((w) => w.rowId), ['r0', 'r1', 'r2']);
      expect([for (final p in pages) p.rowIds], [['r0'], ['r1']]);
      expect(pages.every((p) => p.step == 3 && p.exerciseId == translateExerciseId), isTrue);
      expect(pages.first.exerciseName, 'Translate sentences');
    });

    test('Translate sentences: no usable word, no fetch and no page', () async {
      final pages = await translateSentencesPages(input([_w(3, translation: '')]));
      expect(pages, isEmpty);
      expect(api.fetches, isEmpty);
    });

    test('Explain it to a friend', () async {
      final pages = await explainToFriendPages(input());
      expect([for (final p in pages) p.rowIds], [['r0'], ['r1'], ['r2']]);
      expect(pages.every((p) => p.step == 3 && p.exerciseId == explainExerciseId), isTrue);
      expect(pages.first.exerciseName, 'Explain it to a friend');
    });

    test('fewer than 3 words still give their pages (a session asks one word per page)', () async {
      expect(await ownSentencesPages(input([_w(0)])), hasLength(1));
      expect(await explainToFriendPages(input([_w(0)])), hasLength(1));
    });
  });

  Future<PageAnswer> pumpPage(WidgetTester tester, ExercisePage page) async {
    final answer = PageAnswer();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnApiServiceProvider.overrideWithValue(api),
        examResultSinkProvider.overrideWithValue(sink),
      ],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => page.body(context, answer)))),
    ));
    await tester.pump();
    return answer;
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  group('page bodies: the sentence check reports through done() (AC-10)', () {
    testWidgets('own sentence: a right check is done({rowId: true}), no exam result is written (AC-15)', (tester) async {
      final page = (await ownSentencesPages(input())).first;
      final answer = await pumpPage(tester, page);
      expect(find.text('word0'), findsOneWidget);
      expect(answer.isDone, isFalse);
      await send(tester, 'I walked to the word0 today.');
      expect(api.checks.single.task, LearnCheckTask.own);
      expect(answer.isDone, isTrue);
      expect(answer.results, {'r0': true});
      expect(sink.records, isEmpty);
    });

    testWidgets('own sentence: a fixed check is done({rowId: false})', (tester) async {
      api.reply = (usesWord: true, usesTask: true, ok: false, fixed: 'I walked to the word0.', note: 'n');
      final answer = await pumpPage(tester, (await ownSentencesPages(input())).first);
      await send(tester, 'I walk to the word0 yesterday.');
      expect(answer.results, {'r0': false});
      expect(sink.records, isEmpty);
    });

    testWidgets('own sentence: Skip is done({rowId: false}) without a check', (tester) async {
      final answer = await pumpPage(tester, (await ownSentencesPages(input())).first);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(api.checks, isEmpty);
      expect(answer.results, {'r0': false});
    });

    testWidgets('translate: shows the source, reports right, then shows the model; no exam result', (tester) async {
      final answer = await pumpPage(tester, (await translateSentencesPages(input())).first);
      expect(find.byKey(const ValueKey('translate-source')), findsOneWidget);
      expect(find.byKey(const ValueKey('translate-model')), findsNothing);
      await send(tester, 'We sat by the word0 for a long time.');
      expect(api.checks.single.task, LearnCheckTask.translate);
      expect(api.checks.single.extra, 'Ми довго сиділи на берег0і.');
      expect(answer.results, {'r0': true});
      expect(find.byKey(const ValueKey('translate-model')), findsOneWidget);
      expect(sink.records, isEmpty);
    });

    testWidgets('explain: starts in typed mode with no mode prompt and reports right; no exam result', (tester) async {
      final answer = await pumpPage(tester, (await explainToFriendPages(input())).first);
      expect(find.text('How will you explain the words?'), findsNothing);
      expect(find.text('With a friend'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('word0'), findsOneWidget);
      await send(tester, 'The land at the edge of a river.');
      expect(api.checks.single.task, LearnCheckTask.explain);
      expect(answer.results, {'r0': true});
      expect(sink.records, isEmpty);
      // The 90 s countdown is gone once the word is final.
      await tester.pump(const Duration(seconds: 91));
    });
  });

  group('the old exams still record their word results (AC-15)', () {
    ProviderContainer open([List<WordPair>? group]) {
      final c = ProviderContainer(overrides: [
        learnApiServiceProvider.overrideWithValue(api),
        examResultSinkProvider.overrideWithValue(sink),
        exerciseRandomProvider.overrideWithValue(Random(1)),
        exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: group ?? words, others: const <WordPair>[])),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    final right = SentenceResult.checked('s', const CheckRight());

    test('Make your own sentences', () async {
      final c = open();
      final s = await c.read(ownSentencesProvider(null, 'g').future);
      c.read(ownSentencesProvider(null, 'g').notifier).done(right);
      expect(sink.records, ['own-sentences:${s.card!.rowId}:known']);
    });

    test('Translate sentences', () async {
      // r2's reply is unusable and r3 has no translation: four usable words.
      final c = open([...words, _w(4), _w(5)]);
      final s = await c.read(translateSentencesProvider(null, 'g').future);
      c.read(translateSentencesProvider(null, 'g').notifier).done(right);
      expect(sink.records, ['translate-sentences:${s.card!.rowId}:known']);
    });

    test('Explain it to a friend (typed)', () async {
      final c = open();
      final s = await c.read(explainToFriendProvider(null, 'g').future);
      final n = c.read(explainToFriendProvider(null, 'g').notifier)..chooseMode(ExplainMode.type);
      n.done(right);
      expect(sink.records, ['explain-to-friend:${s.cards.first.rowId}:known']);
    });
  });
}

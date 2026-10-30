import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz_card.dart';

/// The quick check inside a talk (owner, 2026-10-24): when it opens, what it
/// asks, and how its answers are judged.
void main() {
  WordPair w(String word, String row) => WordPair(word: word, translation: 'т-$word', rowId: row);
  final words = [w('shore', 'a'), w('tide', 'b'), w('fog', 'c'), w('gale', 'd'), w('harbour', 'e'), w('rope', 'f')];

  test('a quiz is due once 5 words came up in any line, and never twice for a word', () {
    expect(quizBatch(['The fog came in.', 'Near the shore?', 'The tide rose', 'A gale!'], words, {}), isNull);
    final batch =
        quizBatch(['The fog came in.', 'Near the shore?', 'The tide rose', 'A gale! The harbour.'], words, {});
    expect([for (final x in batch!) x.word], ['shore', 'tide', 'fog', 'gale', 'harbour']);
    expect(quizBatch(['shore tide fog gale harbour rope'], words, {'a', 'b', 'c', 'd', 'e'}), isNull);
  });

  test('the quiz: Translate, Fill the gap, Pick the answer, then Match definitions on the rest', () {
    final batch = words.take(5).toList();
    final items = buildTalkQuiz(
      batch,
      sentences: {for (final x in batch) x.rowId: 'We saw the ${x.word} today.'},
      definitions: {for (final x in batch) x.rowId: 'Meaning of ${x.word}.'},
    );
    expect([
      for (final i in items) i.kind
    ], [
      TalkQuizKind.translate,
      TalkQuizKind.fillGap,
      TalkQuizKind.pickAnswer,
      TalkQuizKind.matchDefinitions,
    ]);
    expect(items[0].prompt, 'т-shore');
    expect(items[1].prompt, 'We saw the $talkQuizBlank today.');
    expect(items[2].options, contains('fog'));
    expect(items[2].options.length, 4);
    expect([for (final x in items[3].words) x.word], ['gale', 'harbour', 'shore', 'tide']);
    expect(items[3].definitions['d'], 'Meaning of gale.');
  });

  test('without sentences or definitions every step is Translate', () {
    final items = buildTalkQuiz(words.take(5).toList());
    expect(items.map((i) => i.kind).toSet(), {TalkQuizKind.translate});
    expect(items.length, 5);
  });

  test('a said answer counts in any form of the word; blanks cut the first place only', () {
    expect(quizAnswerRight('Tides', 'tide'), isTrue);
    expect(quizAnswerRight('I think it is the tide', 'tide'), isTrue);
    expect(quizAnswerRight('wave', 'tide'), isFalse);
    expect(blankOut('The tide and the tide', 'tide'), 'The $talkQuizBlank and the tide');
    expect(blankOut('Nothing here', 'tide'), isNull);
  });

  test('right and wrong rows: a match with a wrong try counts as wrong', () {
    final quiz = TalkQuiz(items: [
      TalkQuizItem(kind: TalkQuizKind.translate, words: [words[0]], correct: true),
      TalkQuizItem(kind: TalkQuizKind.fillGap, words: [words[1]], correct: false),
      TalkQuizItem(
          kind: TalkQuizKind.matchDefinitions, words: words.sublist(2, 5), matched: {'c', 'd', 'e'}, wrongRows: {'d'}),
    ]);
    expect(quiz.rightRows, {'a', 'c', 'e'});
    expect(quiz.wrongRows, {'b', 'd'});
    expect(quiz.rightCount, 3);
    expect(quiz.wordCount, 5);
    expect(quiz.finished, isTrue);
  });

  group('self-check steps (self-check-cards AC-11)', () {
    WordBox box(String row, String word, int n, {String side = ''}) => WordBox()
      ..rowId = row
      ..word = word
      ..box = n
      ..dueAt = DateTime(2026, 10, 30)
      ..lastUpDay = ''
      ..lastCheckSide = side;

    test('one card per flagged word: side by nextSide, after a mistake for a missed word', () {
      final boxes = {'b': box('b', 'tide', 3, side: 'uk')};
      final steps = selfCheckSteps([words[1], words[5]], boxes: boxes, missedRows: {'b'});
      expect([for (final s in steps) s.kind], [TalkQuizKind.selfCheck, TalkQuizKind.selfCheck]);
      expect([for (final s in steps) s.word.word], ['tide', 'rope']);
      expect(steps[0].side, 'en', reason: 'last checked on Ukrainian');
      expect(steps[0].box?.box, 3);
      expect(steps[0].afterMistake, isTrue);
      expect(steps[1].side, 'uk', reason: 'a new word starts on Ukrainian');
      expect(steps[1].box, isNull);
      expect(steps[1].afterMistake, isFalse, reason: 'hinted only');
      expect(steps[0].spoken, isFalse);
      expect(steps[0].done, isFalse);
      expect(steps[0].copyWith(rating: SelfRating.hard).done, isTrue);
    });

    test('self-check steps never count as right or wrong answers', () {
      final quiz = TalkQuiz(items: [
        TalkQuizItem(kind: TalkQuizKind.translate, words: [words[0]], correct: true),
        TalkQuizItem(kind: TalkQuizKind.fillGap, words: [words[1]], correct: false),
        ...selfCheckSteps([words[1]], boxes: const {}, missedRows: {'b'}),
      ]);
      expect(quiz.exercisesDone, isTrue);
      expect(quiz.finished, isFalse);
      expect(quiz.checkedRows, {'b'});
      expect(quiz.rightRows, {'a'});
      expect(quiz.wrongRows, {'b'});
      expect(quiz.wordCount, 2);
    });

    testWidgets('the card shows the self-check card; a rating after the flip goes to onRate', (t) async {
      final rated = <SelfRating>[];
      final quiz = TalkQuiz(items: selfCheckSteps([words[1]], boxes: const {}, missedRows: {'b'}));
      await t.pumpWidget(MaterialApp(
        theme: appThemes.first.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TalkQuizCard(quiz: quiz, onPick: (_) {}, onMatch: (_, __) {}, onNext: () {}, onRate: rated.add),
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('talk-self-check-b')), findsOneWidget);
      expect(find.text('т-tide'), findsOneWidget, reason: 'Ukrainian side first');
      expect(find.text('1 / 1'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('self-check-card')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('rate-hard')));
      await t.pump();
      expect(rated, [SelfRating.hard]);
    });
  });
}

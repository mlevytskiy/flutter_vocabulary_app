import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz.dart';

/// The quick check inside a talk (owner, 2026-10-24): when it opens, what it
/// asks, and how its answers are judged.
void main() {
  WordPair w(String word, String row) => WordPair(word: word, translation: 'т-$word', rowId: row);
  final words = [w('shore', 'a'), w('tide', 'b'), w('fog', 'c'), w('gale', 'd'), w('harbour', 'e'), w('rope', 'f')];

  test('a quiz is due once 5 words came up in any line, and never twice for a word', () {
    expect(quizBatch(['The fog came in.', 'Near the shore?', 'The tide rose', 'A gale!'], words, {}), isNull);
    final batch = quizBatch(['The fog came in.', 'Near the shore?', 'The tide rose', 'A gale! The harbour.'], words, {});
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
    expect([for (final i in items) i.kind], [
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
}

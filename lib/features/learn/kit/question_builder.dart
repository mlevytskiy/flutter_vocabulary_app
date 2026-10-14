import 'dart:math';

import '../../../core/models/word_pair.dart';
import 'word_marks.dart';

/// The two choice question kinds (D-14). The caller picks the kind (D-42).
enum QuestionKind {
  /// Kind A: the English word, four translations.
  wordToTranslation,

  /// Kind B: the meaning (stored definition, else translation; the word
  /// masked), four English words.
  meaningToWord,
}

/// Where wrong options come from (S-08, D-15): the group's own words first,
/// then the same session's other words. Never AI.
class QuestionPool {
  const QuestionPool({required this.group, required this.others});

  final List<WordPair> group;
  final List<WordPair> others;
}

/// One choice question: exactly one of the four [options] is right.
class Question {
  const Question({
    required this.rowId,
    required this.prompt,
    required this.options,
    required this.rightIndex,
  });

  final String rowId;
  final String prompt;
  final List<String> options;
  final int rightIndex;
}

/// D-15 equality: lower-case, trimmed, spaces collapsed.
String _key(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// A choice question for [word] (learn-kit AC-17 – AC-19, S-09), or null when
/// four distinct options cannot be made (the word is left out of the round).
/// Pure: the same word, pool, kind and seed give the same question.
Question? buildQuestion(WordPair word, QuestionPool pool, QuestionKind kind, Random random) {
  final String prompt;
  final String right;
  final String Function(WordPair) option;
  switch (kind) {
    case QuestionKind.wordToTranslation:
      prompt = word.word.trim();
      right = word.translation.trim();
      option = (w) => w.translation.trim();
    case QuestionKind.meaningToWord:
      final meaning = word.definition.trim().isNotEmpty ? word.definition.trim() : word.translation.trim();
      prompt = maskWord(meaning, word.word);
      right = word.word.trim();
      option = (w) => w.word.trim();
  }
  if (prompt.isEmpty || right.isEmpty) return null;

  final taken = {_key(right)};
  final wrong = <String>[];
  for (final source in [pool.group, pool.others]) {
    final candidates = [
      for (final w in source)
        if (w.rowId != word.rowId) option(w),
    ]..shuffle(random);
    for (final text in candidates) {
      if (wrong.length == 3) break;
      // A word without a translation is never a translation option (AC-18).
      if (text.isEmpty || !taken.add(_key(text))) continue;
      wrong.add(text);
    }
  }
  if (wrong.length < 3) return null;

  final options = [right, ...wrong]..shuffle(random);
  return Question(
    rowId: word.rowId,
    prompt: prompt,
    options: options,
    rightIndex: options.indexOf(right),
  );
}

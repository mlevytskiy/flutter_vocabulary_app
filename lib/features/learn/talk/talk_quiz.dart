import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';

/// The quick check inside a talk (owner, 2026-10-24): once [talkQuizBatch]
/// practice words have come up in the talk, a quiz card on those words opens
/// in the chat — the exercise kinds of Learn, drawn as chat cards — and the
/// talk goes on after it. Pure rules; the notifier holds the state.

/// How many words that came up start a quiz.
const int talkQuizBatch = 5;

/// What one quiz step asks.
enum TalkQuizKind {
  /// The Ukrainian translation shown; the learner says or types the word.
  translate,

  /// A sentence with the word blanked; the learner says or types it.
  fillGap,

  /// A sentence with the word blanked; the learner picks it from the batch.
  pickAnswer,

  /// Definitions of 3–4 words; the learner matches word to definition.
  matchDefinitions,
}

/// The blank put in place of the word.
const talkQuizBlank = '_____';

/// One step of a quiz. [words] holds one word, or 3–4 for
/// [TalkQuizKind.matchDefinitions] (with [definitions] by rowId).
class TalkQuizItem {
  const TalkQuizItem({
    required this.kind,
    required this.words,
    this.prompt = '',
    this.options = const [],
    this.definitions = const {},
    this.answer,
    this.correct,
    this.matched = const {},
    this.wrongRows = const {},
  });

  final TalkQuizKind kind;
  final List<WordPair> words;

  /// The translation (translate) or the blanked sentence (fillGap, pickAnswer).
  final String prompt;

  /// The words to pick from (pickAnswer).
  final List<String> options;

  /// rowId → definition (matchDefinitions).
  final Map<String, String> definitions;

  /// What the learner answered, and whether it was right; null until then.
  final String? answer;
  final bool? correct;

  /// matchDefinitions: rowIds matched right so far, and those with a wrong try.
  final Set<String> matched;
  final Set<String> wrongRows;

  WordPair get word => words.first;

  /// Whether the learner answers by voice or typing (the talk's composer).
  bool get spoken => kind == TalkQuizKind.translate || kind == TalkQuizKind.fillGap;

  bool get done => kind == TalkQuizKind.matchDefinitions ? matched.length == words.length : correct != null;

  TalkQuizItem copyWith({String? answer, bool? correct, Set<String>? matched, Set<String>? wrongRows}) => TalkQuizItem(
        kind: kind,
        words: words,
        prompt: prompt,
        options: options,
        definitions: definitions,
        answer: answer ?? this.answer,
        correct: correct ?? this.correct,
        matched: matched ?? this.matched,
        wrongRows: wrongRows ?? this.wrongRows,
      );
}

/// A quiz on one batch of words, and the step the learner is on.
class TalkQuiz {
  const TalkQuiz({required this.items, this.index = 0, this.closed = false});

  final List<TalkQuizItem> items;
  final int index;

  /// Set once the learner went back to the talk.
  final bool closed;

  TalkQuizItem get current => items[index.clamp(0, items.length - 1)];
  bool get finished => items.every((i) => i.done);
  bool get isLast => index >= items.length - 1;

  /// Row ids answered right without a wrong try, and those with one.
  Set<String> get rightRows => {
        for (final i in items)
          if (i.kind == TalkQuizKind.matchDefinitions)
            ...i.matched.difference(i.wrongRows)
          else if (i.correct == true)
            i.word.rowId,
      };
  Set<String> get wrongRows => {
        for (final i in items)
          if (i.kind == TalkQuizKind.matchDefinitions) ...i.wrongRows else if (i.correct == false) i.word.rowId,
      };

  int get rightCount => rightRows.length;
  int get wordCount => {
        for (final i in items)
          for (final w in i.words) w.rowId
      }.length;

  TalkQuiz copyWith({List<TalkQuizItem>? items, int? index, bool? closed}) =>
      TalkQuiz(items: items ?? this.items, index: index ?? this.index, closed: closed ?? this.closed);

  TalkQuiz withCurrent(TalkQuizItem item) => copyWith(items: [
        for (final (i, x) in items.indexed) i == index ? item : x,
      ]);
}

/// The practice words that some line of the talk has used, in [words] order.
List<WordPair> wordsMet(List<String> lines, List<WordPair> words) => [
      for (final w in words)
        if (lines.any((l) => matchPlaces(l, w.word).isNotEmpty)) w,
    ];

/// The next batch to quiz: [talkQuizBatch] words met and not quizzed yet,
/// or null while fewer have come up.
List<WordPair>? quizBatch(List<String> lines, List<WordPair> words, Set<String> quizzedRows) {
  final fresh = [
    for (final w in wordsMet(lines, words))
      if (!quizzedRows.contains(w.rowId)) w
  ];
  return fresh.length >= talkQuizBatch ? fresh.take(talkQuizBatch).toList() : null;
}

/// [sentence] with its first place of [word] blanked, or null when the
/// word is not in it.
String? blankOut(String sentence, String word) {
  final places = matchPlaces(sentence, word);
  if (places.isEmpty) return null;
  final p = places.first;
  return '${sentence.substring(0, p.start)}$talkQuizBlank${sentence.substring(p.end)}';
}

/// The quiz on [batch]: the first word Translate, the second Fill the gap,
/// the third Pick the answer (each needs its sentence, else Translate), then
/// Match definitions on the rest with definitions, borrowing words from the
/// batch to make 3–4 — or Translate for each of the rest when too few have
/// one. [sentences] and [definitions] are by rowId and may miss words.
List<TalkQuizItem> buildTalkQuiz(
  List<WordPair> batch, {
  Map<String, String> sentences = const {},
  Map<String, String> definitions = const {},
}) {
  TalkQuizItem translate(WordPair w) =>
      TalkQuizItem(kind: TalkQuizKind.translate, words: [w], prompt: w.translation.trim());
  final items = <TalkQuizItem>[];
  const firstKinds = [TalkQuizKind.translate, TalkQuizKind.fillGap, TalkQuizKind.pickAnswer];
  final head = batch.take(firstKinds.length).toList();
  for (final (i, w) in head.indexed) {
    final kind = firstKinds[i];
    final sentence = sentences[w.rowId];
    final blanked = sentence == null ? null : blankOut(sentence, w.word);
    if (kind == TalkQuizKind.translate || blanked == null) {
      items.add(translate(w));
    } else if (kind == TalkQuizKind.fillGap) {
      items.add(TalkQuizItem(kind: kind, words: [w], prompt: blanked));
    } else {
      // The answer and up to three more of the batch, in alphabetical order.
      final options = [
        w.word,
        for (final x in batch)
          if (x.rowId != w.rowId) x.word
      ].take(4).toList()
        ..sort();
      items.add(TalkQuizItem(kind: kind, words: [w], prompt: blanked, options: options));
    }
  }
  final rest = batch.skip(firstKinds.length).toList();
  if (rest.isEmpty) return items;
  final withDefinition = [
    for (final w in batch)
      if ((definitions[w.rowId] ?? '').trim().isNotEmpty) w
  ];
  final restDefined = [
    for (final w in rest)
      if (withDefinition.contains(w)) w
  ];
  final borrow = [
    for (final w in withDefinition)
      if (!rest.contains(w)) w
  ];
  final match = [...restDefined, ...borrow].take(4).toList();
  if (restDefined.isNotEmpty && match.length >= 3) {
    items.add(TalkQuizItem(
      kind: TalkQuizKind.matchDefinitions,
      words: match,
      definitions: {for (final w in match) w.rowId: definitions[w.rowId]!.trim()},
    ));
    for (final w in rest) {
      if (!match.contains(w)) items.add(translate(w));
    }
  } else {
    items.addAll(rest.map(translate));
  }
  return items;
}

/// Whether a said or typed [answer] is [word]: the word or a form of it
/// (the talk's whole-word rule), alone or in a short phrase.
bool quizAnswerRight(String answer, String word) => matchPlaces(answer.trim(), word).isNotEmpty;

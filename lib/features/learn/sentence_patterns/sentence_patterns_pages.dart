import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../../../core/services/pronunciation_service.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'sentence_patterns_notifier.dart';
import 'sentence_patterns_page_body.dart';

/// S-50: a word to learn with a row id, a word and a translation is a candidate.
List<WordPair> patternCandidates(List<WordPair> words) => <WordPair>[
      for (final w in words)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];

/// The pattern cards for [PageInput.words] in input order, cut from the
/// sentence-patterns notifier's `build` (learn-redesign ADR-0003): one Worker
/// call (kind `pattern`); a word whose sentence does not hold it once gets no
/// card. A [LearnApiException] propagates.
Future<List<PatternCard>> sentencePatternCards(PageInput input) async {
  final candidates = patternCandidates(input.words);
  final replies = await input.api.fetchData(LearnDataKind.pattern, [
    for (final w in candidates) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
  ]);
  final cards = <PatternCard>[];
  for (final w in candidates) {
    final data = replies[w.rowId];
    final word = w.word.trim();
    if (data == null || !holdsWordOnce(data.sentence, word)) continue;
    cards.add(PatternCard(
      rowId: w.rowId,
      word: word,
      translation: w.translation.trim(),
      sentence: data.sentence,
      pattern: data.pattern,
      usage: data.usage,
    ));
  }
  return cards;
}

/// One step-2 page per word with a pattern card (ADR-0003, AC-08). Check is
/// ready once the sentence is final and counts right only for a sentence
/// checked right (a fixed or skipped one is wrong, AC-10).
Future<List<ExercisePage>> sentencePatternsPages(PageInput input) async => [
      for (final card in await sentencePatternCards(input))
        ExercisePage(
          exerciseId: 'sentence-patterns',
          exerciseName: 'Sentence patterns',
          step: 2,
          rowIds: [card.rowId],
          body: (context, answer) => _PatternPage(card: card, answer: answer),
        ),
    ];

/// A pattern page's own state: "My turn", the result and the listen buttons.
class _PatternPage extends ConsumerStatefulWidget {
  const _PatternPage({required this.card, required this.answer});

  final PatternCard card;
  final PageAnswer answer;

  @override
  ConsumerState<_PatternPage> createState() => _PatternPageState();
}

class _PatternPageState extends ConsumerState<_PatternPage> {
  late final PronunciationService _pronunciation;
  bool _writing = false;
  SentenceResult? _result;

  @override
  void initState() {
    super.initState();
    _pronunciation = ref.read(pronunciationServiceProvider);
  }

  @override
  void dispose() {
    _pronunciation.stop();
    super.dispose();
  }

  Future<void> _speak(String sentence, Accent accent) async {
    try {
      await _pronunciation.speak(sentence, accent: accent);
    } on PronunciationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _done(SentenceResult result) {
    if (_result != null) return;
    setState(() => _result = result);
    final rowId = widget.card.rowId;
    widget.answer.ready(() async => {rowId: result.outcome == SentenceOutcome.right});
  }

  @override
  Widget build(BuildContext context) => SentencePatternsPageBody(
        card: widget.card,
        writing: _writing,
        result: _result,
        onStartWriting: () => setState(() => _writing = true),
        onDone: _done,
        onSpeak: (accent) => _speak(widget.card.sentence, accent),
      );
}

import 'package:flutter/material.dart';

import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';
import 'word_marks.dart';

/// Where a gap sentence came from (S-43).
enum GapSource { dialogue, worker }

/// One fill-the-gap question (S-43): the same for every mode. [answer] is the
/// stored word, [sentence] the full sentence holding it once, [masked] the
/// sentence with exactly one "___", [cue] the masked translation.
class GapQuestion {
  const GapQuestion({
    required this.rowId,
    required this.answer,
    required this.sentence,
    required this.masked,
    required this.cue,
    required this.source,
  });

  final String rowId;
  final String answer;
  final String sentence;
  final String masked;
  final String cue;
  final GapSource source;
}

final _word = RegExp(r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*", unicode: true);
final _sentenceEnd = RegExp('[.!?…]+["\'”’»)\\]]*(?=\\s|\$)');
final _leadingDash = RegExp(r'^[-–—]\s*');
final _spaces = RegExp(r'\s+');

const _minWords = 4;
const _maxWords = 20;
const _maxChars = 160;

List<String> _sentences(String text) {
  final out = <String>[];
  var at = 0;
  void add(String s) {
    final t = s.trim().replaceFirst(_leadingDash, '').trim();
    if (t.isNotEmpty) out.add(t);
  }

  for (final m in _sentenceEnd.allMatches(text)) {
    add(text.substring(at, m.end));
    at = m.end;
  }
  add(text.substring(at));
  return out;
}

List<String> _lowerWords(String text) => [for (final m in _word.allMatches(text)) m[0]!.toLowerCase()];

bool _fair(String sentence, String answer) {
  if (sentence.length > _maxChars || !holdsWordOnce(sentence, answer)) return false;
  final masked = maskWord(sentence, answer);
  final count = masked.split(_spaces).where((t) => t.isNotEmpty).length;
  if (count < _minWords || count > _maxWords) return false;
  // The one place must be the stored form itself, not an inflection of it.
  final start = masked.indexOf('___');
  final place = sentence.substring(start, start + sentence.length - masked.length + 3);
  final got = _lowerWords(place);
  final want = _lowerWords(answer);
  if (got.length != want.length) return false;
  for (var i = 0; i < got.length; i++) {
    if (got[i] != want[i]) return false;
  }
  return true;
}

/// The gap question for [word] from [text] (S-43): the first sentence of
/// [text] that holds the stored word once, in its stored form, with 4 to 20
/// words and at most 160 characters; else null. Pure, no I/O.
GapQuestion? gapFromText(WordPair word, String text, GapSource source) {
  final answer = word.word.trim();
  final translation = word.translation.trim();
  if (answer.isEmpty || translation.isEmpty) return null;
  for (final sentence in _sentences(text)) {
    if (!_fair(sentence, answer)) continue;
    return GapQuestion(
      rowId: word.rowId,
      answer: answer,
      sentence: sentence,
      masked: maskWord(sentence, answer),
      cue: maskWord(translation, answer),
      source: source,
    );
  }
  return null;
}

/// The gap question for [word] from the first qualifying line of a visible
/// dialogue linked to it (S-31 walk, S-43); else null.
GapQuestion? gapFromDialogues(WordPair word, List<FilmDialogue> dialogues) {
  if (word.rowId.isEmpty) return null;
  for (final d in dialogues) {
    if (d.hidden || !d.wordRowIds.contains(word.rowId)) continue;
    for (final line in d.lines) {
      final q = gapFromText(word, line, GapSource.dialogue);
      if (q != null) return q;
    }
  }
  return null;
}

/// Gap questions for [words] (S-44): a dialogue line first, then one Worker
/// call (kind `sentence`) for the words left without one, none when no word
/// is left. Only words with a question are returned, keyed by rowId, in input
/// order. A [LearnApiException] is rethrown unchanged: the caller decides
/// (fill-the-gaps shows the error frame, the Quiz asks choice questions).
Future<Map<String, GapQuestion>> loadGapQuestions(
  List<WordPair> words,
  List<FilmDialogue> dialogues,
  LearnApiService api,
) async {
  final found = <String, GapQuestion>{};
  final missing = <WordPair>[];
  for (final w in words) {
    if (w.rowId.isEmpty || w.word.trim().isEmpty || w.translation.trim().isEmpty) continue;
    final q = gapFromDialogues(w, dialogues);
    if (q != null) {
      found[w.rowId] = q;
    } else {
      missing.add(w);
    }
  }
  final fromWorker = <String, GapQuestion>{};
  if (missing.isNotEmpty) {
    final replies = await api.fetchData(LearnDataKind.sentence, [
      for (final w in missing) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    for (final w in missing) {
      final sentence = replies[w.rowId]?.sentence;
      final q = sentence == null ? null : gapFromText(w, sentence, GapSource.worker);
      if (q != null) fromWorker[w.rowId] = q;
    }
  }
  return {
    for (final w in words)
      if (found[w.rowId] ?? fromWorker[w.rowId] case final q?) w.rowId: q,
  };
}

/// What a gap question shows (S-45): the masked sentence in the headline
/// style and the cue under it; [revealed] shows the full sentence with the
/// word in bold instead. Plain text. The caller puts a keyed
/// `TypedAnswerField` below it.
class GapPrompt extends StatelessWidget {
  const GapPrompt(this.question, {super.key, this.revealed = false});

  final GapQuestion question;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        revealed
            ? Text.rich(
                key: const ValueKey('gap-sentence'),
                TextSpan(children: boldWord(question.sentence, question.answer)),
                style: style.headlineSmall,
              )
            : Text(question.masked, key: const ValueKey('gap-sentence'), style: style.headlineSmall),
        const SizedBox(height: 8),
        Text(question.cue, key: const ValueKey('gap-cue'), style: style.titleMedium),
      ],
    );
  }
}

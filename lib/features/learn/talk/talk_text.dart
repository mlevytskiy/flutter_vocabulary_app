import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';

/// The pure text rules of the Direction B talk screen (talk-screen-b, owner
/// 2026-10-24): which runs of a message are practice words, and how much of
/// the AI's line being spoken is already said (karaoke).

/// One run of a message: plain text or one of the talk's [word]s, said
/// already ([spoken]) or not yet.
class TalkSpan {
  const TalkSpan(this.text, {this.word, this.spoken = true});

  final String text;

  /// The practice word this run is a place of; null for plain text.
  final WordPair? word;

  /// False only for the not-yet-said part of the line being spoken.
  final bool spoken;
}

/// [text] cut into runs: every place of [words] by the app's whole-word rule
/// ([matchPlaces], so "wandered" is a place of "wander"), the rest plain.
/// With [spokenEnd] (karaoke) the runs are also cut there; before it they are
/// [TalkSpan.spoken], after it not. Overlapping places keep the first, then
/// the longer one.
List<TalkSpan> talkSpans(String text, List<WordPair> words, {int? spokenEnd}) {
  final places = <({int start, int end, WordPair word})>[
    for (final w in words)
      for (final p in matchPlaces(text, w.word)) (start: p.start, end: p.end, word: w),
  ]..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  final runs = <({int start, int end, WordPair? word})>[];
  var at = 0;
  for (final p in places) {
    if (p.start < at) continue;
    if (p.start > at) runs.add((start: at, end: p.start, word: null));
    runs.add(p);
    at = p.end;
  }
  if (at < text.length) runs.add((start: at, end: text.length, word: null));
  final split = spokenEnd?.clamp(0, text.length);
  return [
    for (final r in runs)
      if (split == null || split <= r.start || split >= r.end)
        TalkSpan(text.substring(r.start, r.end), word: r.word, spoken: split == null || split >= r.end)
      else ...[
        TalkSpan(text.substring(r.start, split), word: r.word),
        TalkSpan(text.substring(split, r.end), word: r.word, spoken: false),
      ],
  ];
}

final _wordChar = RegExp(r"[\p{L}\p{N}'’]", unicode: true);

/// Where the said part of [text] ends at [progress] (0–1) of its reading:
/// the matching character, moved on to the end of the word it falls in, so
/// whole words colour.
int karaokeSplit(String text, double progress) {
  if (progress <= 0) return 0;
  if (progress >= 1) return text.length;
  var i = (text.length * progress).floor();
  while (i < text.length && _wordChar.hasMatch(text[i])) {
    i++;
  }
  return i;
}

/// About how long a phone voice takes to read [text] (no voice reports its
/// progress through `PronunciationService`): ~14 characters a second, at
/// least a second. The fill waits at the end if the voice is slower and
/// finishes at once when it is done sooner.
Duration karaokeDuration(String text) =>
    Duration(milliseconds: (text.length * 70).clamp(1000, 1 << 30));

import 'package:flutter/painting.dart';

import '../../../core/dialogues/dialogue_match.dart';

/// Word masking and bolding for exercise cards (learn-kit AC-15, AC-16,
/// S-12; D-08, D-27). One rule everywhere: `matchPlaces` from
/// `core/dialogues/dialogue_match.dart` (a whole word in any case, with
/// -s/-es/-ed/-ing; a phrase in order), the same as the Worker's word check.

/// [text] with every place of [word] shown as "___".
String maskWord(String text, String word) {
  final out = StringBuffer();
  var at = 0;
  for (final place in matchPlaces(text, word)) {
    out
      ..write(text.substring(at, place.start))
      ..write('___');
    at = place.end;
  }
  out.write(text.substring(at));
  return out.toString();
}

/// Whether [text] holds [word] exactly once: a text that should hold it once
/// but holds it twice or not at all is rejected for that word.
bool holdsWordOnce(String text, String word) => matchPlaces(text, word).length == 1;

/// [text] as plain spans with every place of [word] in bold, and nothing else.
/// AI text is never parsed: markup characters stay plain characters.
List<TextSpan> boldWord(String text, String word) {
  const bold = TextStyle(fontWeight: FontWeight.bold);
  final spans = <TextSpan>[];
  var at = 0;
  for (final place in matchPlaces(text, word)) {
    if (place.start > at) spans.add(TextSpan(text: text.substring(at, place.start)));
    spans.add(TextSpan(text: text.substring(place.start, place.end), style: bold));
    at = place.end;
  }
  if (at < text.length || spans.isEmpty) spans.add(TextSpan(text: text.substring(at)));
  return spans;
}

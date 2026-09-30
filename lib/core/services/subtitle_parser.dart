/// Turns an SRT or VTT subtitle file into the spoken lines the Worker's
/// POST /subtitles/words takes (words-from-subtitles, ADR-0002): no cue
/// numbers, timings, tags, sound captions, speaker labels or music marks
/// (AC-08). Pure Dart, no I/O.
class SubtitleParser {
  /// The Worker refuses a longer line (contracts/openapi.yaml `lines`).
  static const maxLineChars = 200;

  static final _timing = RegExp(
    r'^(\d{1,2}:)?\d{1,2}:\d{2}[,.]\d{1,3}\s*-->\s*(\d{1,2}:)?\d{1,2}:\d{2}[,.]\d{1,3}',
  );
  static final _tag = RegExp(r'<[^>]*>');
  static final _assOverride = RegExp(r'\{\\[^}]*\}');
  static final _caption = RegExp(r'\[[^\]]*\]|\([^)]*\)');
  static final _music = RegExp('[♪♫♬]');
  static final _speakerLabel = RegExp(r"^[A-Z][A-Z0-9 .'\-]{0,30}:\s*");
  static final _newSpeaker = RegExp(r'^(-|>>)\s*');
  static final _spaces = RegExp(r'\s+');

  /// The spoken lines in file order, each 1–[maxLineChars] characters.
  /// Empty when [extension] is not srt or vtt, the file has no timed cue, or
  /// no dialogue is left after stripping — all three mean "no English
  /// subtitles to read in this file" (AC-10).
  static List<String> parse(String text, {required String extension}) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (ext != 'srt' && ext != 'vtt') return const [];

    final normalized = text.replaceFirst('﻿', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = <String>[];
    for (final block in normalized.split(RegExp(r'\n\s*\n'))) {
      final rows = block.split('\n');
      final timingAt = rows.indexWhere((row) => _timing.hasMatch(row.trim()));
      if (timingAt < 0) continue; // WEBVTT header, NOTE, STYLE, REGION or stray text
      for (final utterance in _utterances(rows.sublist(timingAt + 1))) {
        lines.addAll(_split(utterance));
      }
    }
    return lines;
  }

  /// One cue's text rows as spoken lines: rows run together into one line
  /// until a dash, `>>` or a `NAME:` label starts the next speaker.
  static List<String> _utterances(List<String> rows) {
    final utterances = <String>[];
    var current = '';
    for (final row in rows) {
      var text = _decode(row.replaceAll(_assOverride, '').replaceAll(_tag, '')).trim();
      final startsSpeaker = _newSpeaker.hasMatch(text) || _speakerLabel.hasMatch(text);
      text = text
          .replaceFirst(_newSpeaker, '')
          .replaceFirst(_speakerLabel, '')
          .replaceAll(_caption, ' ')
          .replaceAll(_music, ' ')
          .replaceAll(_spaces, ' ')
          .trim();
      if (startsSpeaker && current.isNotEmpty) {
        utterances.add(current);
        current = '';
      }
      if (text.isEmpty) continue;
      current = current.isEmpty ? text : '$current $text';
    }
    if (current.isNotEmpty) utterances.add(current);
    return utterances;
  }

  static String _decode(String text) => text
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lrm;', '')
      .replaceAll('&rlm;', '')
      .replaceAll('&amp;', '&');

  /// Splits a line longer than [maxLineChars] at spaces; a single longer word
  /// is cut into [maxLineChars] pieces.
  static List<String> _split(String line) {
    if (line.length <= maxLineChars) return [line];
    final parts = <String>[];
    var current = '';
    for (final word in line.split(' ')) {
      if (word.length > maxLineChars) {
        if (current.isNotEmpty) parts.add(current);
        current = '';
        for (var i = 0; i < word.length; i += maxLineChars) {
          final end = i + maxLineChars < word.length ? i + maxLineChars : word.length;
          final piece = word.substring(i, end);
          if (piece.length == maxLineChars) {
            parts.add(piece);
          } else {
            current = piece;
          }
        }
      } else if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= maxLineChars) {
        current = '$current $word';
      } else {
        parts.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) parts.add(current);
    return parts;
  }
}

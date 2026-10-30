/// The pure origin rules of word-context (AC-02 – AC-05, AC-07, AC-08): which
/// [SourceType] a row gets, what an edit by the learner sets, what a changed
/// word clears, the season and episode in a subtitle file's name, and when in
/// the film a word is first said. Every function returns new objects and never
/// changes its inputs.
library;

import '../dialogues/dialogue_match.dart';
import '../models/session_source.dart';
import '../models/word_origin.dart';
import '../models/word_pair.dart';

/// The origin a row gets from its `sourceId`'s source (AC-02, AC-03): photo →
/// image, subtitles → movie (with the film's name, season and episode), set →
/// set, no or unknown source → manuallyEntered. Both edit flags start false.
WordOrigin originForRow(WordPair row, List<SessionSource> sources) {
  final origin = WordOrigin();
  final id = row.sourceId;
  if (id == null) return origin;
  SessionSource? source;
  for (final s in sources) {
    if (s.id == id) {
      source = s;
      break;
    }
  }
  if (source == null) return origin;
  switch (source.kind) {
    case SourceKind.photo:
      origin.typeOfSource = SourceType.image;
    case SourceKind.set:
      origin.typeOfSource = SourceType.set;
    case SourceKind.subtitles:
      origin.typeOfSource = SourceType.movie;
      final title = source.title?.trim() ?? '';
      final name = source.name?.trim() ?? '';
      origin.movieName = title.isNotEmpty ? title : name;
      final fromName = episodeFromFileName(name);
      final fromTitle = episodeFromFileName(title);
      origin.season = fromName.season ?? fromTitle.season;
      origin.episode = fromName.episode ?? fromTitle.episode;
  }
  return origin;
}

/// A copy of [row] whose translation the learner changed (AC-04).
WordPair withEditedTranslation(WordPair row) =>
    row.copy()..origin = (row.origin.copy()..wasTranslationEditByUser = true);

/// A copy of [row] whose definition the learner changed (AC-04).
WordPair withEditedDefinition(WordPair row) =>
    row.copy()..origin = (row.origin.copy()..wasDescriptionEditByUser = true);

/// A copy of [row] after the learner changed the English word (AC-05): the
/// context, its kind, both edit flags and `contextTried` are cleared; the
/// source type and the film fields stay.
WordPair withChangedWord(WordPair row) => row.copy()
  ..context = ''
  ..contextKind = ContextKind.none
  ..contextTried = false
  ..origin = (row.origin.copy()
    ..wasTranslationEditByUser = false
    ..wasDescriptionEditByUser = false);

/// `S02E05`, `s2e5`, `S02.E05`, `S02 E05`; not inside a longer word or number.
final _seasonEpisode = RegExp(
    r'(?<![A-Za-z0-9])s(\d{1,2})[ ._-]?e(\d{1,3})(?!\d)',
    caseSensitive: false);

/// `2x05`, `02x05`: the season is one or two digits with no digit or letter
/// before it and the episode two or three digits, so `1920x1080` is no hit.
final _cross = RegExp(r'(?<![A-Za-z0-9])(\d{1,2})x(\d{2,3})(?!\d)',
    caseSensitive: false);

/// The season and episode in a subtitle file's name (AC-07): `S02E05`, `s2e5`
/// or `2x05`. Both null when the name has none.
({int? season, int? episode}) episodeFromFileName(String name) {
  final m = _seasonEpisode.firstMatch(name) ?? _cross.firstMatch(name);
  if (m == null) return (season: null, episode: null);
  return (season: int.parse(m[1]!), episode: int.parse(m[2]!));
}

/// The start, as `hh:mm:ss`, of the first line that has [word] as a whole
/// word (the matching rule of `dialogue_match.dart`); '' when none has it
/// (AC-08).
String firstLineTime(
    String word, List<({Duration start, String text})> lines) {
  for (final line in lines) {
    if (appears(line.text, word)) return _hhmmss(line.start);
  }
  return '';
}

String _hhmmss(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
      '${two(d.inSeconds.remainder(60))}';
}

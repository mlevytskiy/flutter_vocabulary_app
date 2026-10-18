/// The name rules of a word collection (collections-screen, sad §5).
///
/// Pure Dart: the store, the name dialog and the backfill all call these.
library;

/// Why a name cannot be saved (AC-02).
enum CollectionNameProblem { empty, onlySpaces, tooLong, lineBreak }

/// The most Unicode code points a name may hold (AC-02). The Worker counts
/// the same way, `[...title].length` (api-sync-report A).
const maxCollectionNameLength = 60;

final _lineBreak = RegExp('[\r\n\u0085  ]');

/// Null when [name] can be saved as it is; otherwise why not (AC-02):
/// 1 to 60 code points, on one line, not only spaces.
CollectionNameProblem? collectionNameProblem(String name) {
  if (name.isEmpty) return CollectionNameProblem.empty;
  if (_lineBreak.hasMatch(name)) return CollectionNameProblem.lineBreak;
  if (name.trim().isEmpty) return CollectionNameProblem.onlySpaces;
  if (name.runes.length > maxCollectionNameLength) {
    return CollectionNameProblem.tooLong;
  }
  return null;
}

bool isValidCollectionName(String name) => collectionNameProblem(name) == null;

String _two(int n) => n.toString().padLeft(2, '0');

/// The name of a collection nobody renamed (AC-03): "16.10.2026 14:30",
/// [moment] shown in local time.
String defaultCollectionName(DateTime moment) {
  final t = moment.toLocal();
  return '${_two(t.day)}.${_two(t.month)}.${t.year} '
      '${_two(t.hour)}:${_two(t.minute)}';
}

/// When the collection with [collectionId] was made (AC-04), in local time:
/// the base-36 microseconds before the `-` that `WordCollection.create()`
/// writes. Null when the id does not hold a readable moment, or one past
/// the year 9999 that a "dd.MM.yyyy" name cannot show.
DateTime? creationMomentOf(String collectionId) {
  final dash = collectionId.indexOf('-');
  if (dash <= 0) return null;
  final micros = int.tryParse(collectionId.substring(0, dash), radix: 36);
  if (micros == null || micros <= 0) return null;
  try {
    final moment = DateTime.fromMicrosecondsSinceEpoch(micros);
    return moment.year > 9999 ? null : moment;
  } on ArgumentError {
    return null;
  }
}

// ---- collection-naming (owner, 2026-10-18) ---------------------------------

/// The name of a collection nobody named that has too few words for the AI.
const undefinedCollectionName = 'Vocabulary';

final _vocabularyName = RegExp(r'^Vocabulary(?: ([1-9][0-9]*))?$');

/// The first of "Vocabulary", "Vocabulary 1", "Vocabulary 2", … that no name
/// in [taken] holds.
String nextVocabularyName(Iterable<String?> taken) {
  final used = <int>{};
  for (final name in taken) {
    final m = name == null ? null : _vocabularyName.firstMatch(name);
    if (m != null) used.add(m.group(1) == null ? 0 : int.parse(m.group(1)!));
  }
  var n = 0;
  while (used.contains(n)) {
    n++;
  }
  return n == 0 ? undefinedCollectionName : '$undefinedCollectionName $n';
}

/// True for a "Vocabulary" or "Vocabulary N" name.
bool isVocabularyName(String name) => _vocabularyName.hasMatch(name);

final _dateName = RegExp(r'^\d\d\.\d\d\.\d{4} \d\d:\d\d$');

/// True for a name in the shape [defaultCollectionName] writes, the
/// automatic name from before collection-naming.
bool isDateName(String name) => _dateName.hasMatch(name);

/// The AI's name made fit to store: one line, spaces squeezed, quotes and a
/// final full stop dropped, cut to [maxCollectionNameLength] code points at a
/// word when it can be. Null when nothing usable is left.
String? cleanAutoName(String raw) {
  var name = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceAll(RegExp(r'^["“”«»]+|["“”«»]+$'), '').trim();
  if (name.endsWith('.')) name = name.substring(0, name.length - 1).trim();
  final runes = name.runes.toList();
  if (runes.length > maxCollectionNameLength) {
    name = String.fromCharCodes(runes.take(maxCollectionNameLength));
    final space = name.lastIndexOf(' ');
    if (space > 0) name = name.substring(0, space);
    name = name.trim();
  }
  return collectionNameProblem(name) == null ? name : null;
}

/// The longest description the AI may write (the sheet allows 500).
const maxAutoDescriptionLength = 300;

/// The AI's description made fit to store: one paragraph, spaces squeezed,
/// quotes dropped, cut to [maxAutoDescriptionLength] code points at a word.
/// Null when nothing is left.
String? cleanAutoDescription(String raw) {
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'^["“”«»]+|["“”«»]+$'), '').trim();
  final runes = text.runes.toList();
  if (runes.length > maxAutoDescriptionLength) {
    text = String.fromCharCodes(runes.take(maxAutoDescriptionLength));
    final space = text.lastIndexOf(' ');
    if (space > 0) text = text.substring(0, space);
    text = text.trim();
  }
  return text.isEmpty ? null : text;
}

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

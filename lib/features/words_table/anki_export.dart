import '../../core/models/word_pair.dart';
import '../../core/providers.dart' show WordDetailMode;

/// The AnkiDroid import file ("Close-up B2 format"). The SAME format lives in
/// the Worker (`vocab-photo-api/src/session/anki.ts`) for the download on the
/// shared page; both follow the spec in `vocab-photo-api/README.md`
/// § "AnkiDroid file format". Change one, change the other, and update the
/// spec.
///
/// `#html:true` tells Anki to parse field content as HTML, so `&`, `<` and `>`
/// are escaped as entities. Tabs and newlines inside a field would shift
/// columns or split the record, so any run of them collapses to one space.
String ankiField(String value) => value
    .replaceAll(RegExp(r'[\t\r\n]+'), ' ')
    .trim()
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Fixed columns in every mode (definition-mode, ADR-0005): word,
/// translation, definition, tags. The column [detail] hides is written empty,
/// so a column never changes meaning between exports.
String generateAnkiFile(
  List<WordPair> wordPairs, {
  WordDetailMode detail = WordDetailMode.translation,
}) {
  final showTranslation = detail != WordDetailMode.definition;
  final showDefinition = detail != WordDetailMode.translation;
  final buffer = StringBuffer();

  // Add header
  buffer.writeln('#separator:tab');
  buffer.writeln('#html:true');
  buffer.writeln('#tags column:4');

  // Add word pairs. A row with every field blank is never written: the input
  // screen keeps a trailing empty row by design and it must not become an
  // empty card.
  for (var pair in wordPairs) {
    if (pair.isEmpty) continue;
    final translation = showTranslation ? ankiField(pair.translation) : '';
    final definition = showDefinition ? ankiField(pair.definition) : '';
    buffer.writeln('${ankiField(pair.word)}\t$translation\t$definition\t');
  }

  return buffer.toString();
}

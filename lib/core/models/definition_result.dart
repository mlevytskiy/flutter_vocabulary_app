import 'dart:convert';

enum DefinitionKind { senses, notFound, unavailable }

/// What the Worker's dictionary route answered for one word (definition-mode,
/// ADR-0002). A plain response type beside its service, like
/// `translation_result.dart` — never stored as such; a row keeps only the
/// chosen text and the senses as JSON (ADR-0003, sad §2 override).
class DefinitionResult {
  final DefinitionKind kind;

  /// The dictionary's short senses, first = the one the lightning fills in.
  final List<String> senses;

  /// Spelling suggestions for an unknown word.
  final List<String> suggestions;

  const DefinitionResult._(this.kind,
      {this.senses = const [], this.suggestions = const []});

  const DefinitionResult.found(List<String> senses)
      : this._(DefinitionKind.senses, senses: senses);

  const DefinitionResult.notFound(List<String> suggestions)
      : this._(DefinitionKind.notFound, suggestions: suggestions);

  const DefinitionResult.unavailable() : this._(DefinitionKind.unavailable);

  String? get firstSense => senses.isEmpty ? null : senses.first;

  /// The example of the sense at [index] (null when it has none).
  String? exampleAt(int index) => index < 0 || index >= senses.length
      ? null
      : exampleOfSense(senses[index]);

  /// The example of every sense, null where a sense has none.
  List<String?> get examples => [for (final s in senses) exampleOfSense(s)];

  /// The "example: …" line of a "definition: …\nexample: …" sense; null when
  /// there is none or it is empty (word-context AC-02).
  static String? exampleOfSense(String sense) {
    for (final line in sense.split('\n')) {
      final l = line.trim();
      if (l.toLowerCase().startsWith('example:')) {
        final example = l.substring('example:'.length).trim();
        return example.isEmpty ? null : example;
      }
    }
    return null;
  }

  /// The row's `definitionOptionsJson` shape.
  static String encodeSenses(List<String> senses) =>
      jsonEncode({'senses': senses});

  static List<String> decodeSenses(String? json) {
    if (json == null) return const [];
    try {
      final decoded = jsonDecode(json);
      final senses = decoded is Map ? decoded['senses'] : null;
      return senses is List ? senses.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }
}

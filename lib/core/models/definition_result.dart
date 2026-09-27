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

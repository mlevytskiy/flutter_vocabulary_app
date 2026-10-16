/// File-name and warning text for sharing a named collection (AC-31, AC-32).
library;

final RegExp _unsafe = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');

/// [name] made safe for a shared file name: each of `\ / : * ? " < > |` and
/// every control character becomes `-`; `collection` if nothing is left.
/// The collection's own name is not changed.
String safeFileName(String name) {
  final safe = name.replaceAll(_unsafe, '-');
  return safe.trim().isEmpty ? 'collection' : safe;
}

/// The share sheet's sentence warning that [name] is public (SCR-12).
String publicNameWarning(String name) =>
    'The collection\'s name, "$name", is visible to anyone with the link.';

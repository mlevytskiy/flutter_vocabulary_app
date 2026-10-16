import 'package:isar_community/isar.dart';

import 'tag_kind.dart';

part 'tag_library_entry.g.dart';

/// One tag in the learner's tag library (collection-tags, ADR-0002). Its use
/// counts are computed live, never stored. A second entry with the same
/// (kind, key) is rejected by the unique index: callers upsert by key, so the
/// first spelling wins.
@collection
class TagLibraryEntry {
  Id id = Isar.autoIncrement;

  /// origin = 0, topic = 1; new kinds are only appended.
  @Index(unique: true, replace: false, composite: [CompositeIndex('key')])
  @enumerated
  late TagKind kind;

  /// `text.trim().toLowerCase()`, unique together with [kind].
  late String key;

  /// The first spelling the library met; never rewritten.
  late String text;

  /// Set on every explicit add; null for migrated entries.
  DateTime? lastUsedAt;

  /// Set by Forget; cleared only by an explicit add.
  bool forgotten = false;

  TagLibraryEntry();
}

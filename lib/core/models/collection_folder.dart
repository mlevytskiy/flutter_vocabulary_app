import 'package:isar_community/isar.dart';

part 'collection_folder.g.dart';

/// A folder on the Collections screen (collections-screen, ADR-0004). It holds
/// collections and other folders by being pointed at: a collection names it in
/// `WordCollection.folderId`, a child folder in [parentId]. It owns only its
/// own filing fields; the store's filing transactions write them.
@collection
class CollectionFolder {
  Id id = Isar.autoIncrement;

  /// `uuidV4()`, what collections and child folders point at.
  @Index(unique: true, replace: true)
  late String folderId;

  /// 1–60 characters, one line (`collection_name.dart`). Need not be unique.
  late String name;

  /// The parent's [folderId]; null is the top level. Never itself or a
  /// descendant (`filing.dart`, AC-15).
  String? parentId;

  /// Its place in its level, shared with that level's collections.
  int order = 0;

  /// When the learner deleted it; null when it is not in the bin. Its
  /// contents carry no mark of their own (ADR-0005).
  @Index()
  DateTime? binnedAt;

  /// The folder it was deleted from, the restore target (AC-24).
  String? binnedFromFolderId;
}

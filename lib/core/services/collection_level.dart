import 'package:flutter/foundation.dart';

import '../models/collection_folder.dart';
import '../models/collection_name.dart';
import '../models/word_collection.dart';

/// What a filing action of `CollectionStore` did (collections-screen T8).
/// The actions never throw; a refusal is one of these instead.
enum FilingResult {
  done,

  /// The name breaks the rules of `collection_name.dart` (AC-02).
  invalidName,

  /// A folder would go into itself or a folder inside it (AC-15).
  intoItself,

  /// No such collection or folder, or it, or the target folder, is in the
  /// recycle bin.
  notFound,

  /// The write failed; nothing changed.
  failed,
}

/// One item of a Collections level as `CollectionStore.watchLevel` emits
/// it: exactly one of [collection] and [folder] is set. A read-only view of
/// the stored record, not a model of its own.
@immutable
class LevelItem {
  const LevelItem.collection(WordCollection this.collection) : folder = null;
  const LevelItem.folder(CollectionFolder this.folder) : collection = null;

  final WordCollection? collection;
  final CollectionFolder? folder;

  bool get isFolder => folder != null;

  /// The `collectionId` or the `folderId`.
  String get id => folder?.folderId ?? collection!.collectionId;

  /// A record from before collections-screen that the backfill has not
  /// named yet shows the name the backfill will give it (AC-04).
  String get name {
    if (folder case final f?) return f.name;
    final c = collection!;
    return c.name ??
        defaultCollectionName(creationMomentOf(c.collectionId) ?? c.updatedAt);
  }

  int get order => folder?.order ?? collection!.order;

  /// Non-blank words of a collection; 0 for a folder.
  int get wordCount =>
      collection?.words.where((w) => !w.isEmpty).length ?? 0;
}

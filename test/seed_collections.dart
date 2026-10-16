import 'package:isar_community/isar.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

/// Stores [c] for a test the way `CollectionStore.put()` stored it before
/// collections-screen T5, when put() still inserted: since then only
/// `create()` inserts (ADR-0003). A bare record with [c]'s id, times, filing
/// fields and results goes in first, unless one is there already; then
/// put() writes the rest, blank rows stripped as usual. The store must be
/// open, it owns the `vocab` Isar instance.
Future<void> seedCollection(CollectionStore store, WordCollection c) async {
  final isar = Isar.getInstance('vocab')!;
  await isar.writeTxn(() async {
    final there = await isar.wordCollections
        .filter()
        .collectionIdEqualTo(c.collectionId)
        .count();
    if (there > 0) return;
    await isar.wordCollections.put(WordCollection()
      ..collectionId = c.collectionId
      ..updatedAt = c.updatedAt
      ..lastLocalModifiedAt = c.lastLocalModifiedAt
      ..name = c.name
      ..folderId = c.folderId
      ..order = c.order
      ..binnedAt = c.binnedAt
      ..binnedFromFolderId = c.binnedFromFolderId
      ..keep = c.keep
      ..results = [for (final r in c.results) r.copy()]);
  });
  await store.put(c);
}

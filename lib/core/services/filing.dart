/// The pure filing rules of Collections (collections-screen, sad §5).
///
/// Plain values only — ids, parent ids, orders, `DateTime`s, booleans — so
/// `CollectionStore` can call them inside its transactions (T8, T9) and they
/// test without Isar. A folder tree is passed as `parentOf`: every folder's
/// id mapped to its parent folder's id, `null` for the top level.
library;

/// The folders above [folderId], its parent first and the top-level one
/// last. A loop in stored data ends the walk; the folder that closes it is
/// listed too, so [canMoveFolderInto] still refuses a move into the loop.
List<String> ancestorsOf(String folderId, Map<String, String?> parentOf) {
  final result = <String>[];
  final seen = {folderId};
  var parent = parentOf[folderId];
  while (parent != null && seen.add(parent)) {
    result.add(parent);
    parent = parentOf[parent];
  }
  if (parent != null) result.add(parent);
  return result;
}

/// Every folder inside [folderId], at any depth.
Set<String> descendantsOf(String folderId, Map<String, String?> parentOf) {
  final children = <String, List<String>>{};
  parentOf.forEach((id, parent) {
    if (parent != null) (children[parent] ??= []).add(id);
  });
  final result = <String>{};
  final pending = [...?children[folderId]];
  while (pending.isNotEmpty) {
    final id = pending.removeLast();
    if (id != folderId && result.add(id)) pending.addAll(children[id] ?? []);
  }
  return result;
}

/// Whether an item is in the recycle bin (ADR-0005): it was marked itself
/// ([binned]), or the folder it sits in ([folderId], `null` = top level) or
/// any folder above that is in [binnedFolderIds].
bool isInBin({
  required bool binned,
  required String? folderId,
  required Map<String, String?> parentOf,
  required Set<String> binnedFolderIds,
}) {
  if (binned) return true;
  if (folderId == null) return false;
  return binnedFolderIds.contains(folderId) ||
      ancestorsOf(folderId, parentOf).any(binnedFolderIds.contains);
}

/// False when [folderId] would go into itself or into a folder inside it
/// (AC-15). [targetFolderId] `null` is the top level.
bool canMoveFolderInto(
  String folderId,
  String? targetFolderId,
  Map<String, String?> parentOf,
) {
  if (targetFolderId == null) return true;
  if (targetFolderId == folderId) return false;
  return !ancestorsOf(targetFolderId, parentOf).contains(folderId);
}

/// The level's ids in their new order once [id] is placed [at] (clamped;
/// the end when null). [id] is taken out of [level] first, so the same call
/// inserts a new item and moves one within its level. The index in the
/// result is the new `order`: a level is always numbered 0..n-1.
List<String> placeInLevel(List<String> level, String id, {int? at}) {
  final result = [...level]..remove(id);
  final index = (at ?? result.length).clamp(0, result.length);
  return result..insert(index, id);
}

/// Each id's `order` in a level listed in order.
Map<String, int> ordersOf(List<String> level) => {
      for (final (i, id) in level.indexed) id: i,
    };

/// Where a restored item goes (AC-24, spec §8): back into
/// [binnedFromFolderId] when [folderUsable] (it still exists and is not in
/// the bin), else the top level; at [oldOrder] when that is still within the
/// [levelLength] items there now, else at the end.
({String? folderId, int order}) restoreTarget({
  required String? binnedFromFolderId,
  required bool folderUsable,
  required int oldOrder,
  required int levelLength,
}) =>
    (
      folderId: folderUsable ? binnedFromFolderId : null,
      order: oldOrder < 0 || oldOrder > levelLength ? levelLength : oldOrder,
    );

/// How long the recycle bin keeps an item (AC-26).
const binRetention = Duration(hours: 30 * 24);

/// "N days left" (AC-23): 30 minus the calendar days, in local time, since
/// the day of deletion; 30 on that day, never below 1 (it shows 1 until the
/// sweep erases the item) and never above 30 (a clock moved backwards).
int daysLeft(DateTime binnedAt, DateTime now) {
  DateTime day(DateTime t) {
    final l = t.toLocal();
    return DateTime.utc(l.year, l.month, l.day);
  }

  final days = day(now).difference(day(binnedAt)).inDays;
  return (30 - days).clamp(1, 30);
}

/// Whether the sweep erases an item binned at [binnedAt] (AC-26): from
/// exactly `binnedAt + 30 × 24 h` on. A clock moved backwards never erases
/// early; one moved forward is trusted.
bool isExpired(DateTime binnedAt, DateTime now) =>
    !now.isBefore(binnedAt.add(binRetention));

/// A collection that disappears when the learner leaves it (AC-19): no
/// words, no photos or other sources, no notes or tags, and never [keep]
/// (made with New collection, renamed, moved, reordered or given a word).
bool isEmptyAndUntouched({
  required bool hasWords,
  required bool hasSources,
  required bool hasNotesOrTags,
  required bool keep,
}) =>
    !hasWords && !hasSources && !hasNotesOrTags && !keep;

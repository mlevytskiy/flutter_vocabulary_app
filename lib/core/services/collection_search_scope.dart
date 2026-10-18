/// Where the Collections search's matches are, seen from the open folder
/// (collections-search AC-03, AC-05, AC-06): directly here, or outside —
/// deeper (under the open folder) or elsewhere — and the pruned route from
/// "Collections" down to each match outside.
///
/// Plain Dart over [CollectionSummary] values and [SearchFolder]s, like
/// `collection_search.dart`, so it runs on every keystroke and tests without
/// Flutter or Isar.
library;

import '../models/tag_kind.dart';
import 'collection_search.dart';
import 'filing.dart';
import 'tag_rules.dart';

/// A live (not binned) folder as the search sees it.
class SearchFolder {
  const SearchFolder({
    required this.id,
    required this.name,
    required this.parentId,
    this.order = 0,
  });

  final String id;
  final String name;

  /// null is the top level.
  final String? parentId;

  /// Its place in its level.
  final int order;
}

/// The matches of one search split by the open folder.
class SearchSplit {
  const SearchSplit({
    required this.hereFolders,
    required this.hereCollections,
    required this.outsideFolders,
    required this.outsideCollections,
    required this.deeper,
    required this.elsewhere,
  });

  /// Folders directly in the open folder whose name matches (AC-03).
  final List<SearchFolder> hereFolders;

  /// Matches directly in the open folder, in the search's sort.
  final List<CollectionSummary> hereCollections;

  /// Matching folders anywhere else.
  final List<SearchFolder> outsideFolders;

  /// Matching collections anywhere else, in the search's sort.
  final List<CollectionSummary> outsideCollections;

  /// How many outside matches are under the open folder, and how many are
  /// not (AC-05). At the top level everything outside is deeper.
  final int deeper;
  final int elsewhere;

  bool get hereIsEmpty => hereFolders.isEmpty && hereCollections.isEmpty;
  bool get outsideIsEmpty =>
      outsideFolders.isEmpty && outsideCollections.isEmpty;
}

/// Splits [results] (already searched and sorted) by [openFolderId]. Folder
/// names match only when [filter] has a query and nothing else narrows
/// (AC-03). [folders] are the live folders.
SearchSplit splitByLevel({
  required List<CollectionSummary> results,
  required List<SearchFolder> folders,
  required String? openFolderId,
  required CollectionFilter filter,
}) {
  final query = filter.query.trim().toLowerCase();
  final onlyQuery = query.isNotEmpty &&
      filter.originTags.isEmpty &&
      filter.topicTags.isEmpty &&
      !filter.created.isActive &&
      !filter.edited.isActive;
  final parentOf = {for (final f in folders) f.id: f.parentId};
  final known = parentOf.keys.toSet();

  bool isDeeper(String? folderId) {
    if (openFolderId == null) return true;
    if (folderId == null) return false;
    return folderId == openFolderId ||
        ancestorsOf(folderId, parentOf).contains(openFolderId);
  }

  final matchingFolders = [
    if (onlyQuery)
      for (final f in folders)
        if (f.id != openFolderId && f.name.toLowerCase().contains(query)) f,
  ]..sort((a, b) => a.order.compareTo(b.order));

  final hereFolders = [
    for (final f in matchingFolders)
      if (f.parentId == openFolderId) f
  ];
  final outsideFolders = [
    for (final f in matchingFolders)
      if (f.parentId != openFolderId) f
  ];
  // A collection whose folder is unknown (not live) is treated as top level.
  String? folderOf(CollectionSummary c) =>
      c.folderId != null && known.contains(c.folderId) ? c.folderId : null;
  final hereCollections = [
    for (final c in results)
      if (folderOf(c) == openFolderId) c
  ];
  final outsideCollections = [
    for (final c in results)
      if (folderOf(c) != openFolderId) c
  ];
  var deeper = 0;
  for (final c in outsideCollections) {
    if (isDeeper(folderOf(c))) deeper++;
  }
  for (final f in outsideFolders) {
    if (isDeeper(f.id)) deeper++;
  }
  return SearchSplit(
    hereFolders: hereFolders,
    hereCollections: hereCollections,
    outsideFolders: outsideFolders,
    outsideCollections: outsideCollections,
    deeper: deeper,
    elsewhere: outsideFolders.length + outsideCollections.length - deeper,
  );
}

/// What one line of the route is (AC-06).
enum RouteRowKind { root, folder, collection }

/// How one column of a row's rail is drawn, left to right: a line passing
/// through ([pass]), nothing ([none]), or this row's own branch — one with
/// more siblings below ([tee]) or the last one ([elbow]).
enum RailCell { pass, none, tee, elbow }

/// One line of the route.
class RouteRow {
  const RouteRow({
    required this.kind,
    required this.rail,
    this.folder,
    this.collection,
    this.isHere = false,
    this.nameMatches = false,
    this.count = 0,
  });

  final RouteRowKind kind;
  final List<RailCell> rail;
  final SearchFolder? folder;
  final CollectionSummary? collection;

  /// The open folder ("You are here"); for [RouteRowKind.root], the top
  /// level is open.
  final bool isHere;

  /// A folder on the route whose own name matches.
  final bool nameMatches;

  /// The outside matches under this row.
  final int count;
}

/// The folder tree from "Collections" down, pruned to the branches that lead
/// to a match in [split]'s outside lists, with the open folder on it (AC-06).
/// Folders come before collections in each level, each in their own order.
List<RouteRow> matchRoute({
  required SearchSplit split,
  required List<SearchFolder> folders,
  required String? openFolderId,
}) {
  final byId = {for (final f in folders) f.id: f};
  final parentOf = {for (final f in folders) f.id: f.parentId};
  final keep = <String>{};
  void mark(String? id) {
    if (id == null || !byId.containsKey(id)) return;
    keep.add(id);
    keep.addAll(ancestorsOf(id, parentOf));
  }

  for (final c in split.outsideCollections) {
    mark(c.folderId);
  }
  for (final f in split.outsideFolders) {
    mark(f.id);
  }
  mark(openFolderId);
  final matchedFolderIds = {for (final f in split.outsideFolders) f.id};

  int countUnder(String id) {
    bool under(String? folderId) =>
        folderId != null &&
        (folderId == id || ancestorsOf(folderId, parentOf).contains(id));
    return split.outsideCollections.where((c) => under(c.folderId)).length +
        split.outsideFolders.where((f) => f.id != id && under(f.id)).length;
  }

  final rows = <RouteRow>[
    RouteRow(
      kind: RouteRowKind.root,
      rail: const [],
      isHere: openFolderId == null,
      count: split.outsideFolders.length + split.outsideCollections.length,
    ),
  ];
  final seen = <String>{};
  void walk(String? parentId, List<RailCell> prefix) {
    final childFolders = [
      for (final f in folders)
        if (f.parentId == parentId && keep.contains(f.id)) f
    ]..sort((a, b) => a.order.compareTo(b.order));
    // The open folder's own matches are in the list, not on the route.
    final childCollections = [
      if (parentId != openFolderId)
        for (final c in split.outsideCollections)
          if ((byId.containsKey(c.folderId) ? c.folderId : null) == parentId) c
    ]..sort((a, b) => a.treeIndex.compareTo(b.treeIndex));
    final total = childFolders.length + childCollections.length;
    var i = 0;
    for (final f in childFolders) {
      final last = ++i == total;
      if (!seen.add(f.id)) continue; // a loop in stored data
      rows.add(RouteRow(
        kind: RouteRowKind.folder,
        rail: [...prefix, last ? RailCell.elbow : RailCell.tee],
        folder: f,
        isHere: f.id == openFolderId,
        nameMatches: matchedFolderIds.contains(f.id),
        count: countUnder(f.id),
      ));
      walk(f.id, [...prefix, last ? RailCell.none : RailCell.pass]);
    }
    for (final c in childCollections) {
      final last = ++i == total;
      rows.add(RouteRow(
        kind: RouteRowKind.collection,
        rail: [...prefix, last ? RailCell.elbow : RailCell.tee],
        collection: c,
      ));
    }
  }

  walk(null, const []);
  return rows;
}

/// The folders the outside matches are in, in route order, for the sheet's
/// header (AC-05): a collection's folder, or a matching folder's parent;
/// null is the top level.
List<String?> outsidePlaces(List<RouteRow> route) {
  final places = <String?>[];
  void add(String? id) {
    if (!places.contains(id)) places.add(id);
  }

  for (final r in route) {
    if (r.kind == RouteRowKind.collection) {
      add(r.collection!.folderId);
    } else if (r.kind == RouteRowKind.folder && r.nameMatches) {
      add(r.folder!.parentId);
    }
  }
  return places;
}

/// The path of [folderId] from the top, "Languages / English"; null is
/// "Top level".
String folderPathOf(String? folderId, List<SearchFolder> folders) {
  if (folderId == null) return 'Top level';
  final byId = {for (final f in folders) f.id: f};
  final parentOf = {for (final f in folders) f.id: f.parentId};
  final ids = [...ancestorsOf(folderId, parentOf).reversed, folderId];
  return ids.map((id) => byId[id]?.name ?? '').join(' / ');
}

/// The live tag counts of the filter sheet (AC-09): every tag of [kind] in
/// [all], in its overall order, with how many of [matching] carry it.
List<({String text, int count})> liveTagCounts(
  List<CollectionSummary> all,
  List<CollectionSummary> matching,
  TagKind kind,
) {
  final live = {
    for (final c in tagCounts(matching, kind)) tagKey(c.text): c.count,
  };
  return [
    for (final c in tagCounts(all, kind))
      (text: c.text, count: live[tagKey(c.text)] ?? 0),
  ];
}

/// One tag with its kind, as the filter sheet picks it.
typedef QuickTag = ({TagKind kind, String text});

/// The filter sheet's Popular line (filter-sheet-pills, owner 2026-10-18):
/// with more than [slots] tags in use, the first [recentSlots] tags of
/// [recent] that are still in use, then the most used tags, up to [slots] in
/// all; with [slots] or fewer tags in use, nothing. Each tag shows in the
/// spelling the collections use.
List<QuickTag> quickTags(
  List<CollectionSummary> all,
  List<QuickTag> recent, {
  int slots = 4,
  int recentSlots = 2,
}) {
  final used = [
    for (final kind in TagKind.values)
      for (final c in tagCounts(all, kind))
        (kind: kind, text: c.text, count: c.count),
  ]..sort((a, b) {
      final n = b.count.compareTo(a.count);
      return n != 0 ? n : a.text.toLowerCase().compareTo(b.text.toLowerCase());
    });
  if (used.length <= slots) return const [];
  String id(TagKind kind, String text) => '${kind.name}|${tagKey(text)}';
  final byId = {for (final u in used) id(u.kind, u.text): u};
  final picked = <String, QuickTag>{};
  for (final r in recent) {
    if (picked.length == recentSlots) break;
    final u = byId[id(r.kind, r.text)];
    if (u != null) picked[id(u.kind, u.text)] = (kind: u.kind, text: u.text);
  }
  for (final u in used) {
    if (picked.length == slots) break;
    picked.putIfAbsent(id(u.kind, u.text), () => (kind: u.kind, text: u.text));
  }
  return picked.values.toList();
}

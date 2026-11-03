import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/session_source.dart';
import '../../core/providers.dart';
import '../../core/services/collection_level.dart';
import '../../core/services/filing.dart';
import '../words/words_notifier.dart';
import 'collection_pictures.dart';
import 'collections_view.dart';

part 'collections_notifier.g.dart';

/// What the Collections screen shows: the open folder, its path and its icons.
@immutable
class CollectionsState {
  const CollectionsState({
    required this.folderId,
    required this.path,
    required this.items,
  });

  /// The open folder; null is the top level.
  final String? folderId;

  /// "Collections" first (id null), then the folders down to [folderId].
  final List<PathPart> path;

  /// The level's icons in the learner's order; null until the first read.
  final List<CollectionItemView>? items;

  bool get isTopLevel => folderId == null;
}

/// Holds the open folder of the Collections screen (collections-screen T15).
@riverpod
class CollectionsNotifier extends _$CollectionsNotifier {
  String? _folderId;

  @override
  CollectionsState build() {
    final folders =
        ref.watch(collectionFoldersProvider).value ?? const [];
    final level = ref.watch(collectionLevelProvider(_folderId)).value;
    final currentId =
        ref.watch(wordsProvider).value?.collectionId;

    final byId = {for (final f in folders) f.folderId: f};
    final parentOf = {for (final f in folders) f.folderId: f.parentId};
    final path = <PathPart>[const PathPart(null, 'Collections')];
    final open = _folderId;
    if (open != null) {
      for (final id in [...ancestorsOf(open, parentOf).reversed, open]) {
        path.add(PathPart(id, byId[id]?.name ?? ''));
      }
    }
    return CollectionsState(
      folderId: open,
      path: path,
      items: level
          ?.map((i) => CollectionItemView(
                id: i.id,
                isFolder: i.isFolder,
                name: i.name,
                wordCount: i.wordCount,
                isCurrent: !i.isFolder && i.id == currentId,
                badges: badgesOf(i.collection?.sources ?? const []),
              ))
          .toList(),
    );
  }

  /// Opens [folderId]; null is the top level.
  void open(String? folderId) {
    if (folderId == _folderId) return;
    _folderId = folderId;
    ref.invalidateSelf();
  }

  /// One level up; nothing at the top level.
  void up() {
    if (_folderId == null) return;
    final parent =
        state.path.length >= 2 ? state.path[state.path.length - 2].id : null;
    open(parent);
  }

  /// Renames collection or folder [id] in place (collection inline rename),
  /// through the store's rename (AC-01, AC-17). When it is the current
  /// collection, the main screen takes the stored name at once. Everything
  /// is read before the first await: the screen may be closing.
  Future<FilingResult> rename(String id, String name) async {
    final store = ref.read(collectionStoreProvider.future);
    final words = ref.read(wordsProvider.notifier);
    final isCurrent = ref.read(wordsProvider).value?.collectionId == id;
    final result = await (await store).rename(id, name);
    if (result == FilingResult.done && isCurrent) await words.adoptStored();
    return result;
  }
}

/// One badge per kind of source a collection has, in Stitch's order: Quizlet,
/// film, photo.
List<SourceBadge> badgesOf(List<SessionSource> sources) {
  final kinds = {for (final s in sources) s.kind};
  return [
    if (kinds.contains(SourceKind.set)) SourceBadge.quizlet,
    if (kinds.contains(SourceKind.subtitles)) SourceBadge.movie,
    if (kinds.contains(SourceKind.photo)) SourceBadge.image,
  ];
}

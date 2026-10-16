import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../core/services/filing.dart';
import '../word_input/word_input_notifier.dart';
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
    final folders = ref.watch(collectionFoldersProvider).valueOrNull ?? const [];
    final level = ref.watch(collectionLevelProvider(_folderId)).valueOrNull;
    final currentId = ref.watch(wordInputNotifierProvider).valueOrNull?.collectionId;

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
    final parent = state.path.length >= 2 ? state.path[state.path.length - 2].id : null;
    open(parent);
  }
}

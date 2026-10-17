import 'collection_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
import '../../core/services/collection_level.dart';
import '../../core/services/collection_search.dart';
import '../../core/services/collection_search_scope.dart';
import '../../core/services/filing.dart';
import '../../router/routes.dart';
import '../word_input/word_input_notifier.dart';
import 'bin_dialogs.dart';
import 'collection_drag.dart';
import 'collection_icon.dart';
import 'collections_filter_sheet.dart';
import 'collections_notifier.dart';
import 'collections_results_view.dart';
import 'collections_search_notifier.dart';
import 'collections_speed_dial.dart';
import 'collections_view.dart';
import 'fly_to_bin.dart';
import 'match_outside_sheet.dart';
import 'name_dialog.dart';
import 'recycle_bin_screen.dart';

/// The Collections screen (SCR-04): the path bar (inside a folder) and the
/// icon grid of one level, with three round buttons along the bottom:
/// Settings, the recycle bin (also where a dragged icon is dropped to delete
/// it) and the plus button with New folder and New collection. A tap on the
/// recycle bin offers to open it or to switch delete mode, where each icon
/// gets a small bin button that flies it into the recycle bin.
///
/// The top bar's search icon (collection-tags SCR-05) opens the search
/// field and the filter icon; while a search or filter is on, the folder
/// view gives way to what matches directly in the open folder, and the
/// Match outside sheet holds the rest with the route to each
/// (collections-search). [tagKind] and [tag], from a tag tap on the main
/// screen, open the screen filtered.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.tagKind, this.tag});

  final TagKind? tagKind;
  final String? tag;

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

enum _BinAction { open, toggleDeleteMode }

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  /// Delete mode: every icon but the current collection has a small bin
  /// button. A screen-only switch; it is off whenever the screen opens.
  bool _deleteMode = false;

  /// Items whose picture is flying to the recycle bin; drawn invisible.
  final _flying = <String>{};

  /// The recycle-bin button, where flights land; [_binBounce] while it
  /// swallows one.
  final _binKey = GlobalKey();
  bool _binBounce = false;

  /// The item being dragged and the folder the drag started in (null = top
  /// level), kept in this State because the dragged icon's own widget can go
  /// away when a hover-open changes the level (AC-14).
  CollectionItemView? _dragged;
  String? _dragFrom;
  bool _dragging = false;

  /// The search field's text (collection-tags SCR-05).
  final _query = TextEditingController();

  CollectionsSearchProvider get _searchProvider =>
      collectionsSearchProvider(widget.tagKind, widget.tag);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openSearch() {
    // Delete mode has no place while searching (AC-22).
    setState(() => _deleteMode = false);
    ref.read(_searchProvider.notifier).openSearch();
  }

  /// Clear / Clear filters / the first Back: the folder view comes back at
  /// the folder it was showing (AC-24, AC-39).
  void _clearSearch() {
    _query.clear();
    ref.read(_searchProvider.notifier).clear();
  }

  /// The filter icon: the filter sheet (SCR-06) applies only on its button;
  /// dismissing it changes nothing. The search text is kept.
  Future<void> onOpenFilter() async {
    final current = ref.read(_searchProvider).filter;
    final result = await showCollectionsFilterSheet(context, current: current);
    if (result == null || !mounted) return;
    ref.read(_searchProvider.notifier).setFilter(result);
  }

  void _dragStarted(CollectionItemView item) {
    setState(() {
      _dragged = item;
      _dragFrom = ref.read(collectionsNotifierProvider).folderId;
      _dragging = true;
    });
  }

  void _dragStopped() {
    if (_dragging && mounted) setState(() => _dragging = false);
  }

  /// Carries out what a drop means (AC-14, AC-15, AC-16).
  Future<void> _decide(DropDecision decision) async {
    final item = _dragged;
    if (item == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    switch (decision) {
      case MoveInto(:final folderId, :final at):
        await store.move(item.id, folderId, at: at);
      case Reorder(:final index):
        await store.reorder(item.id, index);
      case ToBin():
        await onDelete(item);
      case RefusedIntoItself():
        _snack(RefusedIntoItself.message);
      case NoOp():
        break;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _newFolder(String? parentId) async {
    final name = await showNameDialog(context, mode: NameDialogMode.newFolder);
    if (name == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.createFolder(parentId: parentId, name: name);
  }

  /// Delete by a drop on the recycle bin (AC-14, AC-20 to AC-22): the
  /// current collection is refused; otherwise the learner confirms (SCR-07),
  /// then the store bins it.
  Future<void> onDelete(CollectionItemView item) async {
    if (item.isCurrent) {
      _snack(refusedCurrentText);
      return;
    }
    final store = await ref.read(collectionStoreProvider.future);
    final p = await store.binPreview(item.id);
    if (p == null || !mounted) return;
    final ok = await confirmBin(
      context,
      BinPreviewView(
        name: p.name,
        isFolder: p.isFolder,
        wordCount: p.wordCount,
        collections: p.collections,
        folders: p.folders,
        currentStaysName: p.currentStaysName,
      ),
    );
    if (!ok || !mounted) return;
    final r = await store.bin(item.id);
    if (r.result == BinResult.refusedCurrent) {
      _snack(refusedCurrentText);
    } else if (r.stayedName != null) {
      _snack(stayedText(r.stayedName!));
    }
  }

  /// The recycle-bin button: open the bin, or switch delete mode.
  Future<void> _binMenu() async {
    final action = await showDialog<_BinAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Recycle bin'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _BinAction.open),
            child: const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text(goToBinText),
            ),
          ),
          // Not offered while a search or filter is on (AC-22).
          if (!_searchLocked)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, _BinAction.toggleDeleteMode),
              child: ListTile(
                leading: Icon(_deleteMode
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked),
                title: Text(
                    _deleteMode ? disableDeleteModeText : enableDeleteModeText),
              ),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _BinAction.open:
        const RecycleBinRoute().push(context);
      case _BinAction.toggleDeleteMode:
        setState(() => _deleteMode = !_deleteMode);
    }
  }

  /// A search or filter is on: no drag, reorder or delete mode (AC-22).
  bool get _searchLocked {
    final search = ref.read(_searchProvider);
    return search.searching || search.filter.isActive;
  }

  /// Delete mode's small bin button: the picture flies into the recycle-bin
  /// button, then the store bins the item, with no question (it can come
  /// back from the bin). A folder holding the current collection keeps it out
  /// and says so (AC-22).
  Future<void> _binByButton(CollectionItemView item, Rect picture) async {
    // The current collection shows the button too, but stays (owner,
    // 2026-10-17).
    if (item.isCurrent) {
      _snack(refusedCurrentText);
      return;
    }
    final bin = _binKey.currentContext?.findRenderObject() as RenderBox?;
    if (bin == null || _flying.contains(item.id)) return;
    final landing = bin.localToGlobal(bin.size.center(Offset.zero));
    setState(() => _flying.add(item.id));
    await flyToBin(
      context,
      from: picture,
      to: landing,
      child: CollectionPicture(
        kind: item.isFolder
            ? CollectionIconKind.folder
            : CollectionIconKind.collection,
        badges: item.badges,
      ),
    );
    if (!mounted) return;
    setState(() => _binBounce = true);
    final store = await ref.read(collectionStoreProvider.future);
    final r = await store.bin(item.id);
    if (!mounted) return;
    setState(() => _flying.remove(item.id));
    if (r.result == BinResult.refusedCurrent) {
      _snack(refusedCurrentText);
    } else if (r.stayedName != null) {
      _snack(stayedText(r.stayedName!));
    }
  }

  /// A tap on a collection (AC-09, AC-18): open it with no question and go to
  /// the main screen; opening the current one changes nothing.
  Future<void> _openCollection(String id) async {
    await ref.read(wordInputNotifierProvider.notifier).open(id);
    if (mounted) const WordInputRoute().go(context);
  }

  /// New collection (AC-10): made at the end of the open folder, then shown.
  Future<void> _newCollection(String? folderId) async {
    final details =
        await showCollectionDetailsSheet(context, mode: DetailsMode.create);
    if (details == null || !mounted) return;
    await ref.read(wordInputNotifierProvider.notifier).newCollectionWithDetails(
          folderId,
          name: details.name,
          description: details.description,
          origin: details.origin,
          topic: details.topic,
        );
    if (mounted) const WordInputRoute().go(context);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(_searchProvider);
    final searchNotifier = ref.read(_searchProvider.notifier);
    final locked = search.searching || search.filter.isActive;
    final binFull =
        ref.watch(binItemsProvider).valueOrNull?.isNotEmpty ?? false;
    List<CollectionSummary>? results;
    if (search.showsResults) {
      final summaries = ref.watch(collectionSummariesProvider).valueOrNull;
      results = summaries == null
          ? null
          : searchCollections(summaries, search.filter, now: DateTime.now());
    }
    final state = ref.watch(collectionsNotifierProvider);
    final folders =
        ref.watch(collectionFoldersProvider).valueOrNull ?? const [];
    final parentOf = {for (final f in folders) f.folderId: f.parentId};
    final notifier = ref.read(collectionsNotifierProvider.notifier);

    // Where the matches are, seen from the open folder (collections-search).
    SearchSplit? split;
    var route = const <RouteRow>[];
    final liveFolders = <SearchFolder>[];
    if (results != null) {
      final binned = {
        for (final f in folders)
          if (f.binnedAt != null) f.folderId,
      };
      for (final f in folders) {
        if (isInBin(
          binned: f.binnedAt != null,
          folderId: f.parentId,
          parentOf: parentOf,
          binnedFolderIds: binned,
        )) {
          continue;
        }
        liveFolders.add(SearchFolder(
            id: f.folderId,
            name: f.name,
            parentId: f.parentId,
            order: f.order));
      }
      split = splitByLevel(
        results: results,
        folders: liveFolders,
        openFolderId: state.folderId,
        filter: search.filter,
      );
      if (!split.outsideIsEmpty) {
        route = matchRoute(
            split: split, folders: liveFolders, openFolderId: state.folderId);
      }
    }
    final showsSheet = split != null && !split.outsideIsEmpty;
    final folderName = state.isTopLevel ? null : state.path.last.name;
    CollectionDragLevel level() => CollectionDragLevel(
          openFolderId: state.folderId,
          parentOf: parentOf,
          levelIds: [for (final i in state.items ?? const []) i.id],
          fromFolderId: _dragFrom,
        );
    // Back from a search started here clears it first; from a tag tap it
    // pops straight to the main screen (ux-flows, "Back from SCR-05").
    return PopScope(
      canPop: !locked || search.enteredFromTag,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSearch();
      },
      child: Listener(
        onPointerUp: (_) => _dragStopped(),
        onPointerCancel: (_) => _dragStopped(),
        child: Scaffold(
          appBar: AppBar(
            title: search.searching
                ? TextField(
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      // Where the search looks (collections-search AC-02).
                      hintText: folderName == null
                          ? 'Search collections'
                          : 'Search in $folderName',
                      border: InputBorder.none,
                    ),
                    onChanged: searchNotifier.setQuery,
                  )
                : const Text('Collections'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              if (!search.searching)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: _openSearch,
                ),
              // The filter belongs to search; a filter that is on without the
              // field (a tag tap) shows it too (collections-search AC-01).
              if (search.searching || search.filter.isActive)
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filter',
                  onPressed: onOpenFilter,
                ),
            ],
          ),
          // Settings bottom-left like the main screen's, the recycle bin in
          // the middle, the plus button bottom-right.
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          // Hidden while Match outside shows, so they do not cover it
          // (collections-search AC-05).
          floatingActionButton: Offstage(
            // Kept in the tree (the bin button's key must not be built twice
            // while the Scaffold animates it back in).
            offstage: showsSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    heroTag: null,
                    onPressed: () => const SettingsRoute().push(context),
                    tooltip: 'Settings',
                    elevation: 8.0,
                    shape: const CircleBorder(),
                    backgroundColor: AppDecor.of(context).fabAlt,
                    foregroundColor: AppDecor.of(context).onFabAlt,
                    child: const Icon(Icons.settings),
                  ),
                  BinDropTarget(
                    level: level(),
                    onDecision: _decide,
                    // A short bounce when a flown picture lands in it.
                    builder: (context, highlighted) => AnimatedScale(
                      scale: _binBounce ? 1.18 : 1,
                      duration: const Duration(milliseconds: 120),
                      onEnd: () {
                        if (_binBounce && mounted) {
                          setState(() => _binBounce = false);
                        }
                      },
                      child: FloatingActionButton(
                        key: _binKey,
                        heroTag: null,
                        onPressed: _binMenu,
                        tooltip: 'Recycle bin',
                        elevation: 8.0,
                        shape: const CircleBorder(),
                        backgroundColor: highlighted
                            ? AppDecor.of(context).binHot
                            : AppDecor.of(context).bin,
                        foregroundColor: AppDecor.of(context).onBin,
                        // Full while the recycle bin holds something (owner,
                        // 2026-10-17).
                        child:
                            Icon(binFull ? Icons.delete : Icons.delete_outline),
                      ),
                    ),
                  ),
                  CollectionsSpeedDial(
                    onNewFolder: () => _newFolder(state.folderId),
                    onNewCollection: () => _newCollection(state.folderId),
                  ),
                ],
              ),
            ),
          ),
          body: search.showsResults
              ? LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      CollectionsResultsView(
                        filter: search.filter,
                        results: split?.hereCollections,
                        folders: split?.hereFolders ?? const [],
                        onOpenFolder: notifier.open,
                        emptyHere:
                            split != null && showsSheet && split.hereIsEmpty
                                ? _emptyHere(split, folderName)
                                : null,
                        bottomPadding: showsSheet
                            ? box.maxHeight * MatchOutsideSheet.peekSize + 16
                            : 96,
                        onOpen: _openCollection,
                        onClear: _clearSearch,
                        onRemoveTag: searchNotifier.removeTag,
                        onClearCreated: searchNotifier.clearCreated,
                        onClearEdited: searchNotifier.clearEdited,
                      ),
                      if (showsSheet)
                        Positioned.fill(
                          child: MatchOutsideSheet(
                            split: split!,
                            route: route,
                            folders: liveFolders,
                            query: search.filter.query,
                            autoOpen: split.hereIsEmpty,
                            autoOpenKey:
                                _autoOpenKey(state.folderId, search.filter),
                            onOpenFolder: notifier.open,
                            onOpenCollection: _openCollection,
                          ),
                        ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (!state.isTopLevel)
                      CollectionsPathBar(
                        parts: state.path,
                        upEnabled: true,
                        onUp: notifier.up,
                        onPart: notifier.open,
                        upWrapper: (context, up) => UpDropTarget(
                            level: level(), onDecision: _decide, child: up),
                        partWrapper: (context, part, child) =>
                            PathPartDropTarget(
                          part: part,
                          level: level(),
                          onDecision: _decide,
                          onHoverOpen: notifier.open,
                          child: child,
                        ),
                      ),
                    Expanded(
                      child: CollectionsGrid(
                        items: state.items,
                        // Room below the last row for the round buttons.
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                        onBin: _deleteMode ? _binByButton : null,
                        hidden: _flying,
                        onTap: (item) {
                          if (item.isFolder) {
                            notifier.open(item.id);
                          } else {
                            _openCollection(item.id);
                          }
                        },
                        // No drag or reorder while the search field is open (AC-22).
                        itemWrapper: locked
                            ? null
                            : (context, item, icon) {
                                final ids = [
                                  for (final i in state.items ?? const []) i.id
                                ];
                                final index = ids.indexOf(item.id);
                                // Invisible gap targets on the tile's left edge (and the last
                                // tile's right edge) reorder to that place.
                                return Stack(
                                  children: [
                                    DraggableCollectionIcon(
                                      item: item,
                                      level: level(),
                                      onDecision: _decide,
                                      onHoverOpen: notifier.open,
                                      onDragStarted: () => _dragStarted(item),
                                      onDragEnded: _dragStopped,
                                      child: icon,
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 8,
                                      child: CollectionGapTarget(
                                          index: index,
                                          level: level(),
                                          onDecision: _decide),
                                    ),
                                    if (index == ids.length - 1)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: 8,
                                        child: CollectionGapTarget(
                                            index: ids.length,
                                            level: level(),
                                            onDecision: _decide),
                                      ),
                                  ],
                                );
                              },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The list's two lines when nothing matches directly in the open folder
/// but Match outside has something (collections-search AC-08).
(String, String) _emptyHere(SearchSplit split, String? folderName) {
  final place = folderName ?? 'the top level';
  if (split.deeper == 0) {
    return (
      'Nothing in $folderName or its subfolders matches',
      '${split.elsewhere} found elsewhere, shown below',
    );
  }
  final elsewhere =
      split.elsewhere > 0 ? ' and ${split.elsewhere} elsewhere' : '';
  return (
    'Nothing directly in $place matches',
    '${split.deeper} found deeper$elsewhere, shown below',
  );
}

/// Match outside opens by itself once per open folder and search (AC-08).
String _autoOpenKey(String? folderId, CollectionFilter f) => [
      folderId ?? '',
      f.query.trim().toLowerCase(),
      f.originTags.join(','),
      f.topicTags.join(','),
      f.created.hashCode,
      f.edited.hashCode,
    ].join('|');

const goToBinText = 'Go to recycle bin';
const enableDeleteModeText = 'Enable delete mode';
const disableDeleteModeText = 'Disable delete mode';

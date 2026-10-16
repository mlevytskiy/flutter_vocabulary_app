import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../core/services/filing.dart' show daysLeft;
import 'bin_dialogs.dart';
import 'recycle_bin_view.dart';

part 'recycle_bin_screen.g.dart';

/// The recycle bin's items (SCR-08), newest deleted first, with the days left
/// counted from now; re-emitted after every write.
@riverpod
Stream<List<BinItemView>> binItems(Ref ref) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  await for (final items in store.watchBin()) {
    final now = DateTime.now();
    yield [
      for (final i in items)
        BinItemView(
          id: i.id,
          isFolder: i.isFolder,
          name: i.name,
          wordCount: i.wordCount,
          daysLeft: daysLeft(i.binnedAt ?? now, now),
        ),
    ];
  }
}

/// SCR-08: the recycle bin. Opened only from the top-level bin icon.
class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  Future<bool> _anyShared(WidgetRef ref, Iterable<String> ids) async {
    final store = await ref.read(collectionStoreProvider.future);
    for (final id in ids) {
      if (await store.hasSharedLink(id)) return true;
    }
    return false;
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, BinItemView item) async {
    final store = await ref.read(collectionStoreProvider.future);
    final r = await store.restore(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(restoredText(r.folderName))));
  }

  Future<void> _erase(BuildContext context, WidgetRef ref, BinItemView item) async {
    final shared = await _anyShared(ref, [item.id]);
    if (!context.mounted) return;
    if (!await confirmEraseForever(context, name: item.name, anyShared: shared)) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.erase(item.id);
  }

  Future<void> _empty(BuildContext context, WidgetRef ref, List<BinItemView> items) async {
    final shared = await _anyShared(ref, [for (final i in items) i.id]);
    if (!context.mounted) return;
    if (!await confirmEmptyBin(context, itemCount: items.length, anyShared: shared)) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.emptyBin();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(binItemsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle bin'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          EmptyBinAction(
            enabled: items != null && items.isNotEmpty,
            onPressed: () => _empty(context, ref, items!),
          ),
        ],
      ),
      body: RecycleBinList(
        items: items,
        onRestore: (i) => _restore(context, ref, i),
        onDeleteForever: (i) => _erase(context, ref, i),
      ),
    );
  }
}

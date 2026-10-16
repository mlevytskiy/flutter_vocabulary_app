import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/routes.dart';
import 'collections_notifier.dart';
import 'collections_view.dart';

/// The Collections screen (SCR-04): the path bar and the icon grid of one
/// level. New folder / New collection and the item menu are wired by T16/T17,
/// the recycle bin by T19.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsNotifierProvider);
    final notifier = ref.read(collectionsNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New folder',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.library_add_outlined),
            tooltip: 'New collection',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          CollectionsPathBar(
            parts: state.path,
            upEnabled: !state.isTopLevel,
            onUp: notifier.up,
            onPart: notifier.open,
          ),
          Expanded(
            child: CollectionsGrid(
              items: state.items,
              showBin: state.isTopLevel,
              onBinTap: () => const RecycleBinRoute().push(context),
              onTap: (item) {
                if (item.isFolder) notifier.open(item.id);
              },
              onMenu: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

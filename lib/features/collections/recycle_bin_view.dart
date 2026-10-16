import 'package:flutter/material.dart';

/// One item of the recycle bin (SCR-08), as plain values.
@immutable
class BinItemView {
  const BinItemView({
    required this.id,
    required this.isFolder,
    required this.name,
    this.wordCount = 0,
    required this.daysLeft,
  });

  final String id;
  final bool isFolder;
  final String name;
  final int wordCount;

  /// 30 on the deletion day down to 1 on the last (`filing.daysLeft`).
  final int daysLeft;
}

String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

/// The recycle bin's items in the given order (newest deleted first).
/// [items] null = loading. A row never opens anything: a tap, long press or
/// ⋮ opens the SCR-09 menu with Restore / Delete forever.
class RecycleBinList extends StatelessWidget {
  const RecycleBinList({
    super.key,
    required this.items,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final List<BinItemView>? items;
  final ValueChanged<BinItemView> onRestore;
  final ValueChanged<BinItemView> onDeleteForever;

  static const emptyText = 'The recycle bin is empty';

  @override
  Widget build(BuildContext context) {
    final list = items;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const Center(
        child: Text(emptyText, style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) => _BinRow(
        key: ValueKey(list[i].id),
        item: list[i],
        onRestore: onRestore,
        onDeleteForever: onDeleteForever,
      ),
    );
  }
}

enum _BinAction { restore, deleteForever }

class _BinRow extends StatelessWidget {
  _BinRow({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final BinItemView item;
  final ValueChanged<BinItemView> onRestore;
  final ValueChanged<BinItemView> onDeleteForever;
  final _menu = GlobalKey<PopupMenuButtonState<_BinAction>>();

  void _open() => _menu.currentState?.showButtonMenu();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.isFolder ? Icons.folder : Icons.style,
        color: item.isFolder ? Colors.amber.shade600 : Theme.of(context).colorScheme.primary,
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: item.isFolder ? null : Text(_count(item.wordCount, 'word')),
      onTap: _open,
      onLongPress: _open,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_count(item.daysLeft, 'day')} left'),
          PopupMenuButton<_BinAction>(
            key: _menu,
            icon: const Icon(Icons.more_vert),
            onSelected: (a) => switch (a) {
              _BinAction.restore => onRestore(item),
              _BinAction.deleteForever => onDeleteForever(item),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _BinAction.restore, child: Text('Restore')),
              PopupMenuItem(value: _BinAction.deleteForever, child: Text('Delete forever')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The SCR-08 `AppBar` action; unavailable ([enabled] false) when the bin is empty.
class EmptyBinAction extends StatelessWidget {
  const EmptyBinAction({super.key, required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  static const label = 'Empty recycle bin';

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: enabled ? onPressed : null, child: const Text(label));
}

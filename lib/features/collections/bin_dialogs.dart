import 'package:flutter/material.dart';

/// What a delete would send to the recycle bin (SCR-07), as plain values.
@immutable
class BinPreviewView {
  const BinPreviewView({
    required this.name,
    required this.isFolder,
    this.wordCount = 0,
    this.collections = 0,
    this.folders = 0,
    this.currentStaysName,
  });

  final String name;
  final bool isFolder;

  /// Words of a collection; unused for a folder.
  final int wordCount;

  /// Collections and folders inside a folder that go to the bin with it.
  final int collections;
  final int folders;

  /// The current collection inside the folder, which stays out of the bin.
  final String? currentStaysName;
}

/// SnackBar on SCR-04 when Delete or a bin drop hits the current collection.
const refusedCurrentText =
    'The current collection cannot be deleted. Open another collection first.';

/// SnackBar on SCR-04 after a folder holding the current collection was binned.
String stayedText(String name) => '$name stayed here because it is the current collection.';

/// SnackBar on SCR-08 after Restore; [folderName] null = the top level.
String restoredText(String? folderName) => 'Restored to ${folderName ?? 'Collections'}';

/// The shared-page sentence of SCR-10.
const sharedPageText =
    'Its shared page stays online until it expires, and can no longer be updated from the app.';

String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

/// The body of the SCR-07 confirmation.
String binBodyText(BinPreviewView p) {
  if (!p.isFolder) {
    return '${_count(p.wordCount, 'word')}. '
        'It goes to the recycle bin for 30 days. Its shared link keeps working.';
  }
  final parts = [
    if (p.collections > 0) _count(p.collections, 'collection'),
    if (p.folders > 0) _count(p.folders, 'folder'),
  ];
  final total = p.collections + p.folders;
  final what = parts.isEmpty
      ? 'It goes to the recycle bin for 30 days.'
      : '${parts.join(' and ')} ${total == 1 ? 'goes' : 'go'} '
          'to the recycle bin with it, for 30 days.';
  final stays = p.currentStaysName;
  if (stays == null) return what;
  return '$what "$stays" stays, because it is the current collection. '
      'It moves to where this folder is.';
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// SCR-07: true on Delete; false on Cancel, Back or a tap outside.
Future<bool> confirmBin(BuildContext context, BinPreviewView preview) => _confirm(
      context,
      title: 'Delete "${preview.name}"?',
      body: binBodyText(preview),
      confirmLabel: 'Delete',
    );

/// SCR-10 one item: true on Delete forever.
Future<bool> confirmEraseForever(
  BuildContext context, {
  required String name,
  required bool anyShared,
}) =>
    _confirm(
      context,
      title: 'Delete "$name" forever?',
      body: 'This cannot be undone. Its words and photos are erased from the phone.'
          '${anyShared ? ' $sharedPageText' : ''}',
      confirmLabel: 'Delete forever',
    );

/// SCR-10 empty the bin: true on Empty.
Future<bool> confirmEmptyBin(
  BuildContext context, {
  required int itemCount,
  required bool anyShared,
}) =>
    _confirm(
      context,
      title: 'Empty the recycle bin?',
      body: '${_count(itemCount, 'item')} ${itemCount == 1 ? 'is' : 'are'} erased for good. '
          'This cannot be undone.${anyShared ? ' $sharedPageText' : ''}',
      confirmLabel: 'Empty',
    );

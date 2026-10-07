import 'package:flutter/material.dart';

/// Asks before "Make a new story" spends money (AC-16). True when confirmed.
Future<bool> confirmNewStory(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Make a new story?'),
      content: const Text(
          'The AIs will write and draw this group again, and that costs money. '
          'The old story stays in Story runs.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Make a new story'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

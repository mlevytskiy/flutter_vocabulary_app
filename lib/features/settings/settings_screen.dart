import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Preferences for the app. One row today: the drag-and-drop mode toggle that
/// used to be an `IconButton` in the input screen's AppBar (task-13, reversing
/// part of task-10). The screen is built to take more rows.
///
/// The mode itself is not stored here -- it is `dragModeProvider`, read by the
/// input screen and written by this switch, so the two screens cannot disagree
/// (rule 2, docs/architecture.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDragMode = ref.watch(dragModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.drag_indicator),
            title: const Text('Drag and Drop мод'),
            subtitle: const Text('Reorder the words by dragging a row'),
            value: isDragMode,
            onChanged: (_) => ref.read(dragModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

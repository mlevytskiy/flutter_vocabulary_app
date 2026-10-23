import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_decor.dart';
import '../words/words_notifier.dart';

/// Collections settings (owner, 2026-10-18): opened from the Collections
/// screen's Settings button. "Replace all date names" gives every collection
/// still called after a moment ("17.10.2026 17:05") a name by the naming
/// rules: "Vocabulary N" under 5 words, the AI's name from 5 on.
class CollectionsSettingsScreen extends ConsumerStatefulWidget {
  const CollectionsSettingsScreen({super.key});

  static const replaceDateNamesKey = Key('collections-settings-replace-dates');

  @override
  ConsumerState<CollectionsSettingsScreen> createState() =>
      _CollectionsSettingsScreenState();
}

class _CollectionsSettingsScreenState
    extends ConsumerState<CollectionsSettingsScreen> {
  bool _replacing = false;

  Future<void> _replaceDateNames() async {
    setState(() => _replacing = true);
    final result =
        await ref.read(wordsProvider.notifier).replaceDateNames();
    if (!mounted) return;
    setState(() => _replacing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(replaceDateNamesMessage(result))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collections settings')),
      body: ListView(
        children: [
          ListTile(
            key: CollectionsSettingsScreen.replaceDateNamesKey,
            enabled: !_replacing,
            leading:
                Icon(Icons.auto_awesome, color: AppDecor.of(context).aiAccent),
            title: const Text('Replace all date names'),
            subtitle: Text(
              'Names like 17.10.2026 17:05 become "Vocabulary" under 5 '
              'words, or a name AI picks from the words',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: _replacing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _replacing ? null : _replaceDateNames,
          ),
        ],
      ),
    );
  }
}

/// What "Replace all date names" did, as one snackbar line.
String replaceDateNamesMessage(({int vocabulary, int ai, int kept}) r) {
  if (r.vocabulary + r.ai + r.kept == 0) return 'No date names to replace';
  String n(int count) => count == 1 ? '1 collection' : '$count collections';
  final parts = [
    if (r.ai > 0) 'AI named ${n(r.ai)}',
    if (r.vocabulary > 0) '${n(r.vocabulary)} now called "Vocabulary"',
    if (r.kept > 0)
      'AI did not answer for ${n(r.kept)}, they keep their dates: '
          'try again later',
  ];
  final line = parts.join('. ');
  return '${line[0].toUpperCase()}${line.substring(1)}';
}

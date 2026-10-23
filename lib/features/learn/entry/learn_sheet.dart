import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_collection.dart';
import '../../../core/providers.dart';
import '../../../core/story/word_grouping.dart' show wordsToLearn;
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../session/session_words.dart';

/// The Learn sheet (learn-redesign SCR-02, AC-01, AC-05, AC-06, AC-14): how to
/// learn, the word and due counts, and the split choice from 20 words.
///
/// [onSettings] opens the Learn settings (the gear hides without it);
/// [onTalk] starts a talk (without it the card says "Coming soon").
Future<void> showLearnSheet(
  BuildContext context,
  WidgetRef ref, {
  String? collectionId,
  required WordCollection collection,
  VoidCallback? onSettings,
  VoidCallback? onTalk,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _LearnSheet(
      outer: context,
      collectionId: collectionId,
      collection: collection,
      onSettings: onSettings,
      onTalk: onTalk,
    ),
  );
}

class _LearnSheet extends ConsumerWidget {
  const _LearnSheet({
    required this.outer,
    required this.collectionId,
    required this.collection,
    required this.onSettings,
    required this.onTalk,
  });

  final BuildContext outer;
  final String? collectionId;
  final WordCollection collection;
  final VoidCallback? onSettings;
  final VoidCallback? onTalk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decor = AppDecor.of(context);
    final id = collection.collectionId;
    final count = wordsToLearn(collection).length;
    final due = dueCount(collection, DateTime.now());
    final canSplit = count >= splitShowsAt;
    final split = canSplit && ref.watch(learnSplitNotifierProvider(id));

    String nextLine = '';
    if (split) {
      nextLine = sessionGroupLabel(pickSessionWords(
        collection,
        split: true,
        wordsPerSession: null,
        lastGroup: ref.watch(learnLastGroupNotifierProvider(id)),
        now: DateTime.now(),
      ));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('How do you want to learn?',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              if (onSettings != null)
                IconButton(
                  tooltip: 'Learn settings',
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSettings!();
                  },
                ),
            ]),
            Text('$count words · $due due',
                style: TextStyle(color: decor.muted)),
            const SizedBox(height: 12),
            _Card(
              title: 'Exercises',
              subtitle: '3 steps · a mix of short tasks',
              onTap: () {
                Navigator.of(context).pop();
                LearningSessionRoute(collectionId: collectionId, split: split)
                    .push(outer);
              },
            ),
            const SizedBox(height: 8),
            _Card(
              title: 'Talk with AI',
              subtitle: 'Talk using your words',
              onTap: () {
                if (onTalk != null) {
                  Navigator.of(context).pop();
                  onTalk!();
                } else {
                  ScaffoldMessenger.of(outer).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                }
              },
            ),
            if (canSplit) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: split,
                title: const Text('Split words into groups of 7–12'),
                onChanged: (v) => ref
                    .read(learnSplitNotifierProvider(id).notifier)
                    .set(v ?? true),
              ),
              if (nextLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text('Next: $nextLine',
                      style: TextStyle(color: decor.muted)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(
      {required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          onTap: onTap,
        ),
      );
}

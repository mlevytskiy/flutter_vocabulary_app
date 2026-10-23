import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_decor.dart';
import '../../../router/routes.dart';
import 'leitner.dart';
import 'session_result.dart';

/// The results of a finished session or talk (learn-redesign SCR-04; AC-07,
/// AC-12, AC-22): pages played, know well / shaky / new counts, each word's
/// next review, then Practise shaky, Next group and Done. Reads
/// [lastSessionResultProvider]; opened by `SessionResultsRoute`.
class SessionResultsScreen extends ConsumerWidget {
  const SessionResultsScreen({super.key, this.collectionId});

  /// As on `LearningSessionRoute`; the result's own id wins when set.
  final String? collectionId;

  static const binnedText = 'This collection is in the recycle bin — results not saved';
  static const notSavedText = 'Results not saved';

  /// Which not-saved line applies: the recycle bin when the collection still
  /// exists, else the neutral one.
  Future<String> _notSavedLine(WidgetRef ref, String? id) async {
    if (id == null) return notSavedText;
    final store = await ref.read(collectionStoreProvider.future);
    final c = await store.byId(id);
    return c == null ? notSavedText : binnedText;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(lastSessionResultProvider);
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    if (result == null) {
      return Scaffold(
        body: Center(child: FilledButton(onPressed: () => context.pop(), child: const Text('Done'))),
      );
    }
    final id = result.collectionId ?? collectionId;
    int count(WordState s) => result.moves.where((m) => m.state == s).length;
    final shaky = [for (final m in result.moves) if (m.state == WordState.shaky) m.rowId];
    final rows = [for (final m in result.moves) if (m.after != null) m];
    final now = DateTime.now();

    Widget chip(String text, Color bg, Color fg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Session done', style: theme.textTheme.headlineSmall),
            if (result.kind == SessionKind.exercises) ...[
              const SizedBox(height: 4),
              Text('${result.pages} pages', style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                chip('${count(WordState.knownWell)} know well', decor.learnRight, decor.onLearnRight),
                const SizedBox(width: 8),
                chip('${count(WordState.shaky)} shaky', decor.learnWrong, decor.onLearnWrong),
                const SizedBox(width: 8),
                chip('${count(WordState.isNew)} new', theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.onSurface),
              ],
            ),
            const SizedBox(height: 16),
            for (final m in rows)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(m.word, style: theme.textTheme.titleMedium)),
                      Text(nextReviewText(m.after!.dueAt, now), style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            if (result.kind == SessionKind.talk && result.unusedCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${result.unusedCount} words not used — unchanged', style: theme.textTheme.bodyMedium),
              ),
            if (!result.written)
              FutureBuilder<String>(
                future: _notSavedLine(ref, id),
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(snap.data ?? notSavedText, style: theme.textTheme.bodyMedium),
                ),
              ),
            const SizedBox(height: 16),
            if (shaky.isNotEmpty)
              FilledButton(
                onPressed: () => LearningSessionRoute(collectionId: id, split: false, rowIds: shaky.join(','))
                    .pushReplacement(context),
                child: Text('Practise ${shaky.length} shaky words'),
              ),
            if (result.groupCount > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => LearningSessionRoute(collectionId: id, split: true, skipGroup: result.groupIndex)
                    .pushReplacement(context),
                child: const Text('Next group'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pop(), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

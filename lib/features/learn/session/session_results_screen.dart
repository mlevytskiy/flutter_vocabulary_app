import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_events_service.dart';
import '../../../core/theme/app_decor.dart';
import '../../../router/routes.dart';
import '../flow/flow_result.dart';
import '../flow/flow_stories.dart';
import '../flow/learn_flow_notifier.dart';
import 'leitner.dart';
import 'self_check.dart';
import 'session_result.dart';

/// The results of a finished session or talk (learn-redesign SCR-04; AC-07,
/// AC-12, AC-22): pages played, know well / shaky / new counts, each word's
/// next review, then Practise shaky, Next group and Done. Reads
/// [lastSessionResultProvider]; opened by `SessionResultsRoute`.
///
/// With a [flow] it shows a finished Learn flow instead (learn-welcome AC-15):
/// Cards, Stories and Talk, "N words due tomorrow", then Exercises, Talk with
/// AI and Done. The flow screen embeds it for its results phase.
class SessionResultsScreen extends ConsumerWidget {
  const SessionResultsScreen({super.key, this.collectionId, this.flow});

  /// As on `LearningSessionRoute`; the result's own id wins when set.
  final String? collectionId;

  /// A finished Learn flow's results; null for an exercise session or talk.
  final FlowResult? flow;

  static const talkLimitText = 'Daily talk limit reached';

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

  /// A flagged word's line under its name (self-check-cards AC-10): the
  /// rating and the box move, or "not checked, box kept" when never rated.
  Widget _ratingLine(SessionMove m, ThemeData theme, AppDecor decor) {
    final style = theme.textTheme.bodySmall;
    final rating = m.rating;
    if (rating == null) {
      return Text('not checked, box kept', key: ValueKey('rating-${m.rowId}'), style: style);
    }
    final (name, color) = switch (rating) {
      SelfRating.dontRemember => ("I don't remember", decor.rateForgot),
      SelfRating.hard => ('Hard', decor.rateHard),
      SelfRating.medium => ('Medium', decor.rateMedium),
      SelfRating.easy => ('Easy', decor.rateEasy),
    };
    return Text.rich(
      key: ValueKey('rating-${m.rowId}'),
      TextSpan(children: [
        TextSpan(text: name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        TextSpan(text: ' · box ${m.before?.box ?? 0} → ${m.after?.box ?? 0}'),
      ]),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = this.flow;
    if (flow != null) return _FlowResults(flow: flow);
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
    bool flagged(SessionMove m) => m.state == WordState.shaky || m.state == WordState.isNew;
    final rows = [for (final m in result.moves) if (m.after != null || flagged(m)) m];
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.word, style: theme.textTheme.titleMedium),
                            if (flagged(m)) _ratingLine(m, theme, decor),
                          ],
                        ),
                      ),
                      if (m.after != null)
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

/// The Learn flow's results (learn-welcome AC-15), in the layout above.
class _FlowResults extends ConsumerStatefulWidget {
  const _FlowResults({required this.flow});

  final FlowResult flow;

  @override
  ConsumerState<_FlowResults> createState() => _FlowResultsState();
}

class _FlowResultsState extends ConsumerState<_FlowResults> {
  /// "Was this talk interesting?" is open (learn-warm-up-v2 AC-16).
  bool _asking = false;

  FlowResult get flow => widget.flow;

  @override
  void initState() {
    super.initState();
    if (!flow.results.talkLimit) _countTalk();
  }

  /// A talk reached results: the store's counter goes up, and every 3rd
  /// talk asks for the 👍/👎.
  Future<void> _countTalk() async {
    final store = ref.read(learnerProfileStoreProvider);
    final n = (await store.read()).talksCounter + 1;
    await store.setTalksCounter(n);
    if (n % 3 == 0 && mounted) setState(() => _asking = true);
  }

  void _rate(bool up) {
    ref.read(learnEventsServiceProvider).send([LearnEvent.talkRating(up: up)]);
    setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final r = flow.results;
    final neutral = theme.colorScheme.surfaceContainerHighest;
    final onNeutral = theme.colorScheme.onSurface;

    Widget chip(String text, Color bg, Color fg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(text, textAlign: TextAlign.center, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
          ),
        );
    Widget chips(List<Widget> items) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
          ],
        );
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(text, style: theme.textTheme.titleMedium),
        );
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text, style: theme.textTheme.bodyMedium),
        );

    final rated = [
      (SelfRating.dontRemember, "I don't remember", decor.rateForgot),
      (SelfRating.hard, 'Hard', decor.rateHard),
      (SelfRating.medium, 'Medium', decor.rateMedium),
      (SelfRating.easy, 'Easy', decor.rateEasy),
    ];
    final talk = [
      (DialogWordResult.used, 'used', decor.learnRight, decor.onLearnRight),
      (DialogWordResult.afterHint, 'after hint', neutral, onNeutral),
      (DialogWordResult.missed, 'missed', decor.learnWrong, decor.onLearnWrong),
      (DialogWordResult.unused, 'unused', neutral, onNeutral),
    ];
    final saved = r.storiesSaved.length;
    final stories = r.storiesShown.isNotEmpty || saved > 0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Session done', style: theme.textTheme.headlineSmall),
            heading('Cards'),
            chips([
              for (final (rating, label, color) in rated)
                chip('${r.ratingCounts[rating] ?? 0}\n$label', color, decor.onLearnRight),
            ]),
            line('${r.movedUp.length} words moved up · ${r.movedDown.length} moved down'),
            if (stories) ...[
              heading('Stories'),
              if (r.storiesShown.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in r.storiesShown) _StoryThumb(story: s)],
                ),
              if (saved > 0) line(saved == 1 ? 'Story saved to Story runs' : '$saved stories saved to Story runs'),
            ],
            heading('Talk'),
            if (r.talkLimit)
              line(SessionResultsScreen.talkLimitText)
            else
              chips([
                for (final (result, label, bg, fg) in talk) chip('${r.talk[result] ?? 0}\n$label', bg, fg),
              ]),
            if (r.grammarRule != null && r.grammarRight + r.grammarWrong > 0)
              line('${r.grammarRule}: used ${r.grammarRight + r.grammarWrong} times, ${r.grammarRight} right'),
            if (_asking)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(child: Text('Was this talk interesting?', style: theme.textTheme.bodyMedium)),
                  TextButton(
                    key: const ValueKey('talk-rating-up'),
                    onPressed: () => _rate(true),
                    child: const Text('👍', style: TextStyle(fontSize: 24)),
                  ),
                  TextButton(
                    key: const ValueKey('talk-rating-down'),
                    onPressed: () => _rate(false),
                    child: const Text('👎', style: TextStyle(fontSize: 24)),
                  ),
                ]),
              ),
            const SizedBox(height: 20),
            Text('${r.dueTomorrow} words due tomorrow', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: flow.cardRowIds.isEmpty
                  ? null
                  : () => LearningSessionRoute(
                          collectionId: flow.collectionId, split: false, rowIds: flow.cardRowIds.join(','))
                      .pushReplacement(context),
              child: const Text('Exercises'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => TalkRoute(collectionId: flow.collectionId, split: false).pushReplacement(context),
              child: const Text('Talk with AI'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pop(), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

/// One story's picture as a thumbnail; a plain tile while it has none.
class _StoryThumb extends StatelessWidget {
  const _StoryThumb({required this.story});

  final FlowStory story;

  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = story.picturePath;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.auto_stories_outlined, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      key: ValueKey('flow-story-${story.index}'),
      borderRadius: BorderRadius.circular(12),
      child: path == null
          ? placeholder
          : Image.file(File(path),
              width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/providers.dart';
import '../../core/services/story_api_service.dart';
import '../../core/story/story_run_tracker.dart';
import '../../core/story/word_grouping.dart';
import '../../core/story/word_groups_notifier.dart';
import '../../router/routes.dart';
import '../word_input/word_input_notifier.dart';
import 'exercises.dart';
import 'widgets/group_pager.dart';
import 'widgets/step_progress.dart';

/// Said on the learn page when the day's story allowance is used up (AC-19).
const storyDayLimitMessage =
    "Today's story limit is reached. Try again tomorrow.";

/// The learn page (learn-part-step-1, SCR-03). [sessionId] is the session the
/// exercises will read: none is the current session, an id is a History row
/// (AC-13). Ticks are transient UI state.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final Set<String> _ticked = {};

  /// This screen's own messenger, so the hint never follows the user back to
  /// the Words screen.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// One card per step; the title above the cards follows the page.
  static const _stages = [1, 2, 3];
  static const _cardSize = Size(280, 350);

  /// Each page is the card plus this gap, so the edge of the next card shows.
  static const _cardGap = 16.0;

  /// Room above and below the card inside the pager, so its shadow is not
  /// cut off.
  static const _shadowRoom = 8.0;

  /// Next/Start sits over the pager at the current card's bottom-right corner.
  static const _buttonInset = 12.0;
  PageController? _pages;
  int _page = 0;

  /// The pager's viewport fraction depends on the screen width, so the
  /// controller is rebuilt (keeping the page) when the width changes.
  PageController _pagesFor(double width) {
    final fraction = ((_cardSize.width + _cardGap) / width).clamp(0.1, 1.0);
    final old = _pages;
    if (old != null && old.viewportFraction == fraction) return old;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return _pages = PageController(
      initialPage: _page,
      viewportFraction: fraction,
    );
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pages?.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  /// Opens the first ticked exercise: Mnemonic story opens the story of the
  /// selected group (AC-06); the others are still coming soon.
  void _start() {
    final id = exercises.firstWhere((e) => _ticked.contains(e.id)).id;
    final group =
        ref.read(wordGroupsNotifierProvider(widget.sessionId)).selectedGroupId;
    if (id == 'mnemonic-story' && group != null) {
      StoryRoute(sessionId: widget.sessionId, groupId: group)
          .push<void>(context);
    } else {
      ComingSoonRoute(exercise: id).push<void>(context);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showHint();
      // Grouping starts here too when the words changed (AC-03); the page
      // shows it going.
      _groups.ensureGrouped().catchError((_) {});
    });
  }

  WordGroupsNotifier get _groups =>
      ref.read(wordGroupsNotifierProvider(widget.sessionId).notifier);

  /// Sticky until OK or until an exercise is ticked.
  void _showHint() {
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Pick at least one exercise'),
        duration: const Duration(days: 365),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _toggle(String id, bool on) {
    final wasEmpty = _ticked.isEmpty;
    setState(() => on ? _ticked.add(id) : _ticked.remove(id));
    if (wasEmpty && _ticked.isNotEmpty) {
      _messenger.currentState?.hideCurrentSnackBar();
    } else if (!wasEmpty && _ticked.isEmpty) {
      _showHint();
    }
  }

  bool _canStart(WordGroupsState grouping) =>
      _ticked.isNotEmpty &&
      !(_ticked.contains('mnemonic-story') && grouping.selectedGroupId == null);

  /// The session whose words the groups name.
  Session? get _session => widget.sessionId == null
      ? ref.watch(wordInputNotifierProvider).valueOrNull
      : ref.watch(sessionByIdProvider(widget.sessionId!)).valueOrNull;

  /// The group line, the group pager and the grouping messages above the
  /// exercise cards (AC-01 – AC-05, AC-19).
  List<Widget> _groupSection(
      WordGroupsState grouping, StoryStartRefusal? refusal) {
    final style = Theme.of(context).textTheme.bodyMedium;
    Widget line(String text, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(text, textAlign: TextAlign.center, style: style),
        );
    final status = grouping.status;
    return [
      if (status is GroupingInProgress) line('Grouping your words…'),
      if (status is GroupingFailed) ...[
        line('Could not group your words'),
        ElevatedButton(
          onPressed: () => _groups.ensureGrouped().catchError((_) {}),
          child: const Text('Try again'),
        ),
      ],
      if (grouping.groups.length >= 2) ...[
        line('We grouped your words into sets of up to 19 words. '
            'Please select one group to learn.'),
        GroupPager(
          groups: grouping.groups,
          wordsByRowId: {
            for (final w in wordsToLearn(_session ?? Session.create()))
              w.rowId: w.word.trim(),
          },
          selectedId: grouping.selectedGroupId,
          onSelect: (id) => _groups.select(id).catchError((_) {}),
        ),
      ],
      if (status is GroupingWaiting)
        line('${status.count} more words are waiting for a group '
            '(at least 7 are needed)'),
      if (refusal?.reason == StoryRefusal.dayLimit) line(storyDayLimitMessage),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final grouping = ref.watch(wordGroupsNotifierProvider(widget.sessionId));
    // The story is made from the selected group, so Mnemonic story cannot
    // start without one (AC-04, AC-05).
    final canStart = _canStart(grouping);
    final refusal = ref.watch(storyRunTrackerProvider
        .select((s) => s.refusals[grouping.selectedGroupId]));

    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learn'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: canStart ? _start : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._groupSection(grouping, refusal),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: _cardSize.width,
                  child: StepProgress(
                    labels: [for (final stage in _stages) 'Step $stage'],
                    current: _page,
                    onTap: _goTo,
                  ),
                ),
              ),
              // The card's height plus room for its shadow, or less when the
              // screen is shorter.
              Flexible(
                child: SizedBox(
                  height: _cardSize.height + 2 * _shadowRoom,
                  child: LayoutBuilder(
                      builder: (context, c) => _pager(context, c, canStart)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pager(
      BuildContext context, BoxConstraints constraints, bool canStart) {
    final width = constraints.maxWidth;
    final cardWidth = width < _cardSize.width ? width : _cardSize.width;
    final isLast = _page == _stages.length - 1;
    return Stack(
      children: [
        PageView.builder(
          controller: _pagesFor(width),
          itemCount: _stages.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, page) => _card(_stages[page]),
        ),
        // In front of the pager, not on a page: it stays put while the cards
        // slide, and turns into Start on the last step.
        Positioned(
          right: (width - cardWidth) / 2 + _buttonInset,
          bottom: _shadowRoom + _buttonInset,
          child: ElevatedButton.icon(
            key: const ValueKey('pager-button'),
            onPressed:
                isLast ? (canStart ? _start : null) : () => _goTo(_page + 1),
            icon: Icon(isLast ? Icons.play_arrow : Icons.arrow_forward),
            label: Text(isLast ? 'Start' : 'Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(int stage) {
    // A fixed-size card in the middle of its page; it only shrinks when the
    // screen has less room than that.
    return Center(
      key: ValueKey('step-$stage'),
      child: SizedBox.fromSize(
        size: _cardSize,
        child: Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  // The bottom leaves room for the Next/Start button on top.
                  padding: const EdgeInsets.only(top: 8, bottom: 64),
                  children: [
                    for (final exercise
                        in exercises.where((e) => e.stage == stage))
                      CheckboxListTile(
                        value: _ticked.contains(exercise.id),
                        enabled: exercise.available,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(exercise.name),
                        subtitle: exercise.available
                            ? null
                            : const Text('Coming soon'),
                        onChanged: exercise.available
                            ? (on) => _toggle(exercise.id, on == true)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

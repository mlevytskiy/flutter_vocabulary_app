import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_box.dart';
import '../../../core/models/word_origin.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/theme/app_decor.dart';
import '../session/learning_session_screen.dart' show confirmLeaveSession;
import '../session/self_check_card.dart';
import '../session/self_check.dart';
import 'flow_peek_pager.dart';
import 'learn_flow_notifier.dart';
import 'story_page.dart';
import 'story_slots.dart';

/// Builds what the flow screen shows in a phase other than
/// [FlowPhase.cards] (warm-up, dialog, results…), given the flow's state and
/// its notifier.
typedef FlowPhaseBuilder = Widget Function(BuildContext context, LearnFlowState state, LearnFlow flow);

/// The Learn flow of one collection (learn-welcome AC-07, AC-10, AC-11,
/// AC-16). While [FlowPhase.cards], one peek pager ([FlowPeekPager],
/// learn-flow-cards) whose next page the notifier picks ([LearnFlowState.slot]): card pages ("Card N of M" and the
/// self-check card), story pages (the picture alone, [StoryPage]) and the
/// wait page ("Writing your story…", progress, "Skip, show it later").
///
/// The other phases show [phases]' builder for that phase, else a plain
/// placeholder (a spinner while loading).
class LearnFlowScreen extends ConsumerStatefulWidget {
  const LearnFlowScreen({
    super.key,
    required this.collectionId,
    this.phases = const {},
    this.onStoryEnter,
    this.onStoryExit,
  });

  final String collectionId;

  /// What the phases other than [FlowPhase.cards] show.
  final Map<FlowPhase, FlowPhaseBuilder> phases;

  /// Passed on to every [StoryPage]: run when it is first built and when it
  /// goes away.
  final VoidCallback? onStoryEnter;
  final VoidCallback? onStoryExit;

  @override
  ConsumerState<LearnFlowScreen> createState() => _LearnFlowScreenState();
}

/// One page of the pager, as it was when it opened.
@immutable
class _FlowPage {
  const _FlowPage.card(this.row, this.number, this.box, this.side)
      : story = null,
        wait = false;
  const _FlowPage.story(int this.story)
      : row = null,
        number = 0,
        box = null,
        side = 'uk',
        wait = false;
  const _FlowPage.wait(int this.story)
      : row = null,
        number = 0,
        box = null,
        side = 'uk',
        wait = true;

  final WordPair? row;

  /// The card's 1-based number.
  final int number;
  final WordBox? box;
  final String side;
  final int? story;
  final bool wait;

  bool same(_FlowPage other) =>
      other.row?.rowId == row?.rowId && other.number == number && other.story == story && other.wait == wait;
}

class _LearnFlowScreenState extends ConsumerState<LearnFlowScreen> {
  final _pager = flowPeekController();
  final _swipeLimit = FlowSwipeLimit();
  final _pages = <_FlowPage>[];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// The page [s] asks for; null outside the cards.
  _FlowPage? _pageOf(LearnFlowState s) {
    if (s.phase != FlowPhase.cards) return null;
    return switch (s.slot) {
      CardSlot() =>
        s.card == null ? null : _FlowPage.card(s.card!, s.cardsDone + 1, s.boxes[s.card!.rowId], s.sideOf(s.card!)),
      StorySlot(:final story) => _FlowPage.story(story),
      WaitSlot(:final story) => _FlowPage.wait(story),
      DialogSlot() => null,
    };
  }

  /// Adds the page [s] asks for when it is a new one, and moves to it.
  void _follow(LearnFlowState s) {
    final page = _pageOf(s);
    if (page == null || (_pages.isNotEmpty && _pages.last.same(page))) return;
    _pages.add(page);
    final to = _pages.length - 1;
    if (to == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pager.hasClients) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _pager.jumpToPage(to);
      } else {
        // The story page turns the screen while the slide is still running,
        // and the slide then stops short of it; land on the page asked for.
        _pager.animateToPage(to, duration: const Duration(milliseconds: 300), curve: Curves.easeOut).then((_) {
          if (mounted && _pager.hasClients && to == _pages.length - 1 && _pager.page != to) _pager.jumpToPage(to);
        });
      }
    });
  }

  /// Back on page [index] after the story zoom closed and the screen turned
  /// back to portrait (learn-flow-cards).
  void _landOn(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pager.hasClients && index < _pages.length && _pager.page != index) _pager.jumpToPage(index);
    });
  }

  /// The page count when a swipe past the last page last counted, so one
  /// drag (many overscroll events) moves on once.
  int _swipedPastAt = -1;

  /// A swipe forward past the current page (owner, 2026-11-01): on a story
  /// page it is "seen", as a tap; on a card it skips the card unrated
  /// ([LearnFlow.skipCard]: no rating, no box move); the wait page keeps its
  /// "Skip, show it later".
  void _swipePast(LearnFlowState s, LearnFlow flow) {
    if (_pages.isEmpty || _swipedPastAt == _pages.length) return;
    final page = _pages.last;
    if (page.wait) return;
    _swipedPastAt = _pages.length;
    if (page.story == null) {
      flow.skipCard();
    } else {
      flow.storyDone();
    }
  }

  /// The leave dialog (AC-16): Leave drops the flow and closes the screen.
  Future<void> _confirmLeave() async {
    final leave = await confirmLeaveSession(context);
    if (!leave || !mounted) return;
    ref.read(learnFlowProvider(widget.collectionId).notifier).leave();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = learnFlowProvider(widget.collectionId);
    final s = ref.watch(provider);
    final flow = ref.read(provider.notifier);
    _follow(s);
    final asks = s.phase == FlowPhase.warmUp || s.phase == FlowPhase.cards || s.phase == FlowPhase.dialog;
    final custom = widget.phases[s.phase];
    final Widget body;
    if (s.phase == FlowPhase.cards) {
      body = FlowPeekPager(
        controller: _pager,
        count: _pages.length,
        current: _pages.length - 1,
        itemBuilder: (context, i) => _buildPage(context, i, s, flow),
        limit: _swipeLimit,
        onSwipePast: () => _swipePast(s, flow),
      );
    } else if (custom != null) {
      body = custom(context, s, flow);
    } else {
      body = SafeArea(
        child: Center(
          child: s.phase == FlowPhase.loading ? const CircularProgressIndicator() : const SizedBox.shrink(),
        ),
      );
    }
    return PopScope(
      canPop: !asks,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(body: body),
    );
  }

  /// Page [index]. A page before the last one was already answered: it can be
  /// looked at again after a swipe back, but rates, skips and moves on
  /// nothing (owner, 2026-11-01).
  Widget _buildPage(BuildContext context, int index, LearnFlowState s, LearnFlow flow) {
    final page = _pages[index];
    final live = index == _pages.length - 1;
    final story = page.story;
    if (story == null) {
      return _CardPage(
        key: ValueKey('flow-card-${page.number}'),
        row: page.row!,
        number: page.number,
        total: s.words.length,
        box: page.box,
        side: page.side,
        now: ref.read(learnFlowClockProvider)(),
        onClose: _confirmLeave,
        onRated: live ? flow.rate : null,
      );
    }
    final flowStory = story < s.stories.length ? s.stories[story] : null;
    if (page.wait) {
      return _WaitPage(
        key: ValueKey('flow-wait-$story'),
        progress: flowStory?.progress ?? 0,
        onSkip: live ? () => flow.skipStory(story) : null,
        onClose: _confirmLeave,
      );
    }
    return StoryPage(
      key: ValueKey('flow-story-$story'),
      picturePath: flowStory?.picturePath,
      onDone: live ? flow.storyDone : () {},
      onEnter: widget.onStoryEnter,
      onExit: widget.onStoryExit,
      onZoomClosed: () => _landOn(index),
    );
  }
}

/// Close and the "Card N of M" counter, which replaces the step bar (AC-07).
class _CardPage extends StatelessWidget {
  const _CardPage({
    super.key,
    required this.row,
    required this.number,
    required this.total,
    required this.box,
    required this.side,
    required this.now,
    required this.onClose,
    required this.onRated,
  });

  final WordPair row;
  final int number;
  final int total;
  final WordBox? box;
  final String side;
  final DateTime now;
  final VoidCallback onClose;
  final ValueChanged<SelfRating>? onRated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(
              children: [
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
                const Spacer(),
                Text('Card $number of $total', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SelfCheckCard(
                row: row,
                box: box,
                side: side,
                now: now,
                wordContext: row.context,
                contextByAi: row.contextKind == ContextKind.ai,
                onRated: onRated,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Writing your story…" with the run's progress and "Skip, show it later"
/// (AC-10). The notifier opens the story by itself once it is ready.
class _WaitPage extends StatelessWidget {
  const _WaitPage({super.key, required this.progress, required this.onSkip, required this.onClose});

  final double progress;
  final VoidCallback? onSkip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final decor = AppDecor.of(context);
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Writing your story…', textAlign: TextAlign.center, style: text.titleMedium),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      key: const ValueKey('flow-wait-progress'),
                      value: progress.clamp(0.0, 1.0),
                      borderRadius: BorderRadius.circular(decor.wordRowRadius),
                    ),
                    const SizedBox(height: 24),
                    TextButton(onPressed: onSkip, child: const Text('Skip, show it later')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

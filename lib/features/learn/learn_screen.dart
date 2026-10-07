import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/routes.dart';
import 'exercises.dart';
import 'widgets/step_progress.dart';

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

  /// Opens the first ticked exercise.
  void _start() => ComingSoonRoute(
        exercise: exercises.firstWhere((e) => _ticked.contains(e.id)).id,
      ).push<void>(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHint());
  }

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

  @override
  Widget build(BuildContext context) {
    final canStart = _ticked.isNotEmpty;

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
                  child: LayoutBuilder(builder: _pager),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pager(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final cardWidth = width < _cardSize.width ? width : _cardSize.width;
    final isLast = _page == _stages.length - 1;
    final canStart = _ticked.isNotEmpty;
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

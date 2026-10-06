import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/quizlet_link.dart';
import '../../../core/services/quizlet_page_script.dart';
import '../../../core/services/quizlet_set_parser.dart';
import '../quizlet_read_controller.dart';

/// Builds the page driver for a set link; tests pass a fake.
typedef QuizletPageDriverFactory = QuizletPageDriver Function(
    QuizletSetLink link);

/// The progress dialog (import-from-quizlet SCR-03, sad §6 F2): opens the set
/// page out of sight and shows a pager of skeleton cards under a skeleton
/// title instead. The skeletons stay at least [quizletSkeletonFor]; then the
/// title shows the set's name once known and, once the set is read, the cards
/// show its terms and the pager scrolls from the first card to the last in
/// [quizletCardsScrollFor] before the dialog closes. While Quizlet's robot
/// check is on screen the page itself is shown full size instead of the cards.
/// Resolves with the parsed set, a failure (AC-07, at once) or a cancel
/// (Cancel/Back, AC-07b). When [afterRead] is given, the dialog stays open
/// while it runs on the read set (the translations, sad §6 F3), alongside the
/// cards, and Cancel/Back still end it as a cancel.
/// The least time the skeleton cards and title are shown.
const Duration quizletSkeletonFor = Duration(seconds: 1);

/// How long the filled pager takes to scroll from the first card to the last.
const Duration quizletCardsScrollFor = Duration(seconds: 2);

Future<QuizletReadOutcome> showQuizletProgressDialog(
  BuildContext context,
  QuizletSetLink link, {
  QuizletPageDriverFactory? driverFactory,
  Future<void> Function(QuizletSet set)? afterRead,
}) async {
  final outcome = await showDialog<QuizletReadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _QuizletProgressDialog(
      link: link,
      driverFactory:
          driverFactory ?? ((link) => WebViewQuizletPageDriver(link.setId)),
      afterRead: afterRead,
    ),
  );
  return outcome ?? const QuizletReadCancelled();
}

class _QuizletProgressDialog extends StatefulWidget {
  const _QuizletProgressDialog(
      {required this.link, required this.driverFactory, this.afterRead});

  final QuizletSetLink link;
  final QuizletPageDriverFactory driverFactory;
  final Future<void> Function(QuizletSet set)? afterRead;

  @override
  State<_QuizletProgressDialog> createState() => _QuizletProgressDialogState();
}

class _QuizletProgressDialogState extends State<_QuizletProgressDialog>
    with SingleTickerProviderStateMixin {
  static const double _smallPreviewHeight = 180;

  final _pages = PageController(viewportFraction: 0.82);

  // The skeletons' soft pulse.
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  // Completes once the skeletons have been up for [quizletSkeletonFor].
  final _skeletonShown = Completer<void>();
  Timer? _skeletonTimer;

  /// The read set's cards, shown once the skeleton time is over.
  List<QuizletCard>? _cards;

  late final QuizletPageDriver _driver = widget.driverFactory(widget.link);
  late final QuizletReadController _controller;

  // Built once and kept at the same place in the tree, so the page is not
  // reloaded when the preview changes size.
  late final Widget _preview = _driver.buildView();

  // Set once the dialog has been popped, so a late afterRead does not pop
  // what is below it.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = QuizletReadController(
      link: widget.link,
      driver: _driver,
      onDone: _readDone,
    )..addListener(_changed);
    _skeletonTimer = Timer(quizletSkeletonFor, () {
      _skeletonShown.complete();
      _changed();
    });
    _controller.start();
  }

  bool get _skeletonOver => _skeletonShown.isCompleted;

  Future<void> _readDone(QuizletReadOutcome outcome) async {
    if (outcome is! QuizletReadSucceeded) {
      _close(outcome);
      return;
    }
    final afterRead = widget.afterRead;
    await Future.wait([
      if (afterRead != null) afterRead(outcome.set),
      _showCards(outcome.set),
    ]);
    _close(outcome);
  }

  /// Fills the pager once the skeletons have had their time, then scrolls it
  /// from the first card to the last.
  Future<void> _showCards(QuizletSet set) async {
    await _skeletonShown.future;
    if (_closed || !mounted) return;
    setState(() => _cards = set.cards);
    await WidgetsBinding.instance.endOfFrame;
    if (_closed || !mounted) return;
    final last = set.cards.length - 1;
    if (last > 0 && _pages.hasClients) {
      await _pages.animateToPage(last,
          duration: quizletCardsScrollFor, curve: Curves.easeInOut);
    } else {
      await Future<void>.delayed(quizletCardsScrollFor);
    }
  }

  void _close(QuizletReadOutcome outcome) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(outcome);
  }

  /// Cancel or Back: while reading the controller decides; once the set is
  /// read (afterRead running) the dialog ends as a cancel itself (AC-07b).
  void _cancel() {
    if (_controller.outcome is QuizletReadSucceeded) {
      debugPrint('QUIZLET: cancelled');
      _close(const QuizletReadCancelled());
    } else {
      _controller.cancel();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    _pulse.dispose();
    _pages.dispose();
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robotCheck = _controller.robotCheck;
    final media = MediaQuery.of(context);
    // Full size: the screen height less the dialog's title, name line,
    // actions and paddings.
    final fullHeight = math.max(
        _smallPreviewHeight, media.size.height - media.padding.vertical - 292);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        insetPadding: robotCheck
            ? const EdgeInsets.all(8)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        title: const Text('Reading the Quizlet set…'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(context),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SizedBox(
                key: const Key('quizlet-preview'),
                height: robotCheck ? fullHeight : _smallPreviewHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  // The page stays loaded under the cards at its full width,
                  // so it reads as before; only the robot check shows it.
                  child: Stack(
                    children: [
                      Positioned.fill(child: _preview),
                      if (!robotCheck)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            child: _pager(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// The set's name, or a skeleton bar until it is known and the skeleton
  /// time is over.
  Widget _title(BuildContext context) {
    final name = _cards != null
        ? (_controller.outcome as QuizletReadSucceeded?)?.set.name ??
            _controller.name
        : _controller.name;
    if (!_skeletonOver || name.isEmpty) {
      return SizedBox(
        key: const Key('quizlet-set-name-skeleton'),
        height: 24,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _bone(context, width: 180, height: 16),
        ),
      );
    }
    return SizedBox(
      height: 24,
      child: Text(
        name,
        key: const Key('quizlet-set-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  /// The cards pager: three skeleton cards until the set's cards are shown.
  Widget _pager(BuildContext context) {
    final cards = _cards;
    final count = cards?.length ?? 3;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const Key('quizlet-cards'),
            controller: _pages,
            itemCount: count,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
              child: cards == null
                  ? _skeletonCard(context)
                  : _card(context, cards[i]),
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: cards == null
              ? null
              : AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) {
                    final page = _pages.hasClients && _pages.page != null
                        ? _pages.page!.round()
                        : 0;
                    return Text('${page + 1} / ${cards.length}',
                        key: const Key('quizlet-cards-position'),
                        style: Theme.of(context).textTheme.bodySmall);
                  },
                ),
        ),
      ],
    );
  }

  Widget _frame(BuildContext context, {Key? key, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _skeletonCard(BuildContext context) => _frame(
        context,
        key: const Key('quizlet-card-skeleton'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bone(context, width: 110, height: 18),
            const SizedBox(height: 16),
            _bone(context, width: 160, height: 10),
            const SizedBox(height: 8),
            _bone(context, width: 120, height: 10),
          ],
        ),
      );

  Widget _card(BuildContext context, QuizletCard card) {
    final text = Theme.of(context).textTheme;
    return _frame(
      context,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.term,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge),
          if (card.back.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(card.back,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium),
          ],
        ],
      ),
    );
  }

  /// One grey skeleton bar, softly pulsing.
  Widget _bone(BuildContext context,
      {required double width, required double height}) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.08 + 0.08 * _pulse.value),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// The real page driver: a `webview_flutter` page with JavaScript on and no
/// JavaScript channel, so the page cannot call into the app (sad §8). Every
/// top-level navigation goes through [allowWebViewNavigation]; new windows
/// are never opened (the plugin opens none without a handler).
class WebViewQuizletPageDriver implements QuizletPageDriver {
  WebViewQuizletPageDriver(this.setId);

  final String setId;
  final WebViewController _web = WebViewController();
  bool _stopped = false;

  // iOS reports its own cancelled loads (a refused redirect, a new load
  // replacing the current one) as errors: NSURLErrorCancelled and WebKit's
  // "frame load interrupted".
  static const _cancelledCodes = {-999, 102};

  @override
  void open(
    Uri url, {
    required void Function() onPageFinished,
    required void Function(String reason) onLoadError,
  }) {
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (!_stopped &&
              allowWebViewNavigation(request.url,
                  isMainFrame: request.isMainFrame, setId: setId)) {
            return NavigationDecision.navigate;
          }
          final host = Uri.tryParse(request.url)?.host ?? '';
          debugPrint('QUIZLET: navigation blocked to $host');
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (!_stopped) onPageFinished();
        },
        onWebResourceError: (error) {
          if (_stopped || error.isForMainFrame == false) return;
          if (_cancelledCodes.contains(error.errorCode)) return;
          onLoadError(error.errorType?.name ?? 'code ${error.errorCode}');
        },
      ))
      ..loadRequest(url);
  }

  @override
  Future<Object?> runReader() =>
      _web.runJavaScriptReturningResult(quizletPageScript);

  @override
  Widget buildView() => WebViewWidget(controller: _web);

  @override
  void stop() => _stopped = true;
}

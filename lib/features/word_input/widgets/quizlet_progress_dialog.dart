import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/quizlet_link.dart';
import '../../../core/services/quizlet_page_script.dart';
import '../quizlet_read_controller.dart';

/// Builds the page driver for a set link; tests pass a fake.
typedef QuizletPageDriverFactory = QuizletPageDriver Function(
    QuizletSetLink link);

/// The progress dialog (import-from-quizlet SCR-03, sad §6 F2): opens the set
/// page in a small live preview, shows the set's name once known, grows the
/// preview to full size while Quizlet's robot check is on screen, and
/// resolves with the parsed set, a failure (AC-07) or a cancel (Cancel/Back,
/// AC-07b).
Future<QuizletReadOutcome> showQuizletProgressDialog(
  BuildContext context,
  QuizletSetLink link, {
  QuizletPageDriverFactory? driverFactory,
}) async {
  final outcome = await showDialog<QuizletReadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _QuizletProgressDialog(
      link: link,
      driverFactory:
          driverFactory ?? ((link) => WebViewQuizletPageDriver(link.setId)),
    ),
  );
  return outcome ?? const QuizletReadCancelled();
}

class _QuizletProgressDialog extends StatefulWidget {
  const _QuizletProgressDialog(
      {required this.link, required this.driverFactory});

  final QuizletSetLink link;
  final QuizletPageDriverFactory driverFactory;

  @override
  State<_QuizletProgressDialog> createState() => _QuizletProgressDialogState();
}

class _QuizletProgressDialogState extends State<_QuizletProgressDialog> {
  static const double _smallPreviewHeight = 180;

  late final QuizletPageDriver _driver = widget.driverFactory(widget.link);
  late final QuizletReadController _controller;

  // Built once and kept at the same place in the tree, so the page is not
  // reloaded when the preview changes size.
  late final Widget _preview = _driver.buildView();

  @override
  void initState() {
    super.initState();
    _controller = QuizletReadController(
      link: widget.link,
      driver: _driver,
      onDone: (outcome) {
        if (mounted) Navigator.of(context).pop(outcome);
      },
    )..addListener(_changed);
    _controller.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
        _smallPreviewHeight, media.size.height - media.padding.vertical - 260);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.cancel();
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
              if (_controller.name.isNotEmpty) ...[
                Text(
                  _controller.name,
                  key: const Key('quizlet-set-name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SizedBox(
                key: const Key('quizlet-preview'),
                height: robotCheck ? fullHeight : _smallPreviewHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _preview,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _controller.cancel,
            child: const Text('Cancel'),
          ),
        ],
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

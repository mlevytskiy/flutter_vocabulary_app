import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/services/quizlet_link.dart';
import '../../core/services/quizlet_set_parser.dart';

/// Why reading a set failed (AC-07); only logged, the learner sees one message.
enum QuizletReadFailure {
  /// No connection or the page failed to load before it had loaded once.
  loadError,

  /// The page had not finished loading within the limit.
  noFirstLoad,

  /// The page loaded but no cards of the set were found within the limit.
  noCards,
}

/// How the progress dialog ended (sad §6 F2).
sealed class QuizletReadOutcome {
  const QuizletReadOutcome();
}

/// The cards of exactly the pasted set were read.
class QuizletReadSucceeded extends QuizletReadOutcome {
  const QuizletReadSucceeded(this.set);
  final QuizletSet set;
}

/// The set could not be read (AC-07).
class QuizletReadFailed extends QuizletReadOutcome {
  const QuizletReadFailed(this.reason);
  final QuizletReadFailure reason;
}

/// The learner tapped Cancel or went Back (AC-07b).
class QuizletReadCancelled extends QuizletReadOutcome {
  const QuizletReadCancelled();
}

/// The seam between the reading logic and the in-app page. The real one wraps
/// `webview_flutter` (quizlet_progress_dialog.dart); tests use a fake.
abstract class QuizletPageDriver {
  /// Starts loading [url]. [onPageFinished] may be called more than once;
  /// [onLoadError] reports a failed load of the page itself (not of an advert
  /// or other part of it).
  void open(
    Uri url, {
    required void Function() onPageFinished,
    required void Function(String reason) onLoadError,
  });

  /// Runs the reader script on the page and returns its raw result.
  Future<Object?> runReader();

  /// The live page, shown as the preview.
  Widget buildView();

  /// Stops reacting to the page: no more callbacks, every navigation refused.
  void stop();
}

/// Whether the in-app page may follow a navigation to [url] while reading
/// the set [setId] (AC-11, ADR-0004): a top-level page only on Quizlet and
/// never another set's page; embedded frames load as the page asks.
bool allowWebViewNavigation(String url,
    {required bool isMainFrame, required String setId}) {
  if (!isMainFrame) return true;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return QuizletLink.isNavigationAllowed(uri, setId);
}

/// The reader script's result as the raw JSON text the parser expects.
/// Android hands back the returned string JSON-quoted, iOS as it is.
String readerResultText(Object? result) {
  if (result is! String) return '';
  final t = result.trim();
  if (t.startsWith('"')) {
    try {
      final inner = jsonDecode(t);
      if (inner is String) return inner;
    } catch (_) {}
  }
  return result;
}

/// The waiting and deciding of the progress dialog (sad §4 "waiting"):
/// [limit] for the first load, then [limit] again for cards from the first
/// finished load; the clock does not run while Quizlet's robot check is on
/// screen. About every [tick] the page is read; the first read with cards of
/// the pasted set ends it. Timing is counted in ticks, so it is exact under
/// test time and within one tick on a device.
class QuizletReadController extends ChangeNotifier {
  QuizletReadController({
    required this.link,
    required this.driver,
    required this.onDone,
    this.limit = const Duration(seconds: 30),
    this.tick = const Duration(seconds: 1),
  });

  final QuizletSetLink link;
  final QuizletPageDriver driver;
  final void Function(QuizletReadOutcome outcome) onDone;
  final Duration limit;
  final Duration tick;

  /// The set's name once the page states it, else empty.
  String get name => _name;

  /// Whether Quizlet's own robot check is on screen (preview full size).
  bool get robotCheck => _robotCheck;

  /// Whether the page has finished loading at least once.
  bool get loaded => _loaded;

  QuizletReadOutcome? get outcome => _outcome;

  String _name = '';
  bool _robotCheck = false;
  bool _loaded = false;
  bool _reading = false;
  Duration _waited = Duration.zero;
  Timer? _ticker;
  QuizletReadOutcome? _outcome;

  void start() {
    debugPrint('QUIZLET: reading set ${link.setId}');
    driver.open(Uri.parse(link.plainUrl),
        onPageFinished: _pageFinished, onLoadError: _loadError);
    _ticker = Timer.periodic(tick, (_) => _onTick());
  }

  /// Cancel or Back (AC-07b).
  void cancel() {
    if (_outcome != null) return;
    debugPrint('QUIZLET: cancelled');
    _finish(const QuizletReadCancelled());
  }

  void _onTick() {
    if (_outcome != null) return;
    if (!_robotCheck) {
      _waited += tick;
      if (_waited >= limit) {
        final reason = _loaded
            ? QuizletReadFailure.noCards
            : QuizletReadFailure.noFirstLoad;
        debugPrint('QUIZLET: failed: ${reason.name}');
        _finish(QuizletReadFailed(reason));
        return;
      }
    }
    _read();
  }

  void _pageFinished() {
    if (_outcome != null) return;
    if (!_loaded) {
      _loaded = true;
      _waited = Duration.zero;
      debugPrint('QUIZLET: page loaded');
      notifyListeners();
    }
    _read();
  }

  void _loadError(String reason) {
    if (_outcome != null) return;
    if (_loaded) {
      // The page is there; the clock decides whether its cards come.
      debugPrint('QUIZLET: load error after the page loaded: $reason');
      return;
    }
    debugPrint('QUIZLET: failed: load error $reason');
    _finish(const QuizletReadFailed(QuizletReadFailure.loadError));
  }

  Future<void> _read() async {
    if (_reading || _outcome != null) return;
    _reading = true;
    String raw;
    try {
      raw = readerResultText(await driver.runReader());
    } catch (_) {
      raw = '';
    } finally {
      _reading = false;
    }
    if (_outcome != null) return;

    switch (parseQuizletPage(raw, link.setId)) {
      case QuizletSetFound(:final set):
        final of = set.statedCount == null ? '' : ' of ${set.statedCount}';
        debugPrint('QUIZLET: cards read ${set.cards.length}$of');
        _finish(QuizletReadSucceeded(set));
      case QuizletRobotCheck():
        if (!_robotCheck) {
          debugPrint('QUIZLET: robot check shown');
          _robotCheck = true;
          notifyListeners();
        }
      case QuizletNothingYet(name: final pageName):
        var changed = false;
        if (_robotCheck) {
          debugPrint('QUIZLET: robot check passed');
          _robotCheck = false;
          changed = true;
        }
        if (pageName.isNotEmpty && pageName != _name) {
          _name = pageName;
          changed = true;
        }
        if (changed) notifyListeners();
    }
  }

  void _finish(QuizletReadOutcome outcome) {
    _outcome = outcome;
    _ticker?.cancel();
    driver.stop();
    onDone(outcome);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_outcome == null) driver.stop();
    super.dispose();
  }
}

import 'package:flutter/widgets.dart';

/// How one row of a page was answered (self-check-cards AC-01, Q-3): right,
/// wrong, or right only after a hint (the typed field's second try after the
/// "Starts with …" line). A hinted row is not a clean right; the next tasks
/// flag it for a self-check card.
enum PageResult {
  right,
  wrong,
  hinted;

  /// The old right/wrong view of a bool result.
  static PageResult of(bool right) => right ? PageResult.right : PageResult.wrong;
}

/// The channel between an exercise page body and the learn page frame
/// (learn-redesign, ADR-0011). A body that needs the frame's Check button calls
/// [ready] with its check function once it has an answer and [notReady] when
/// the answer is cleared; a self-checking body calls [done] with its results
/// and the frame shows no Check. A body that knows about hints uses
/// [readyResults] / [doneResults] instead, with a [PageResult] per row id;
/// the right/wrong view ([results], [runCheck]) counts a hinted row as right
/// unless the body says otherwise (`hintedCountsRight: false`).
class PageAnswer extends ChangeNotifier {
  Future<Map<String, PageResult>> Function()? _check;
  Map<String, PageResult>? _done;
  Map<String, bool>? _doneBools;
  Map<String, PageResult>? _checked;
  bool _selfChecking = false;
  bool _hintedCountsRight = true;

  /// Whether the body has an answer the frame can check.
  bool get isReady => _check != null;

  /// Whether the body reported its results itself ([done]).
  bool get isDone => _done != null;

  /// The results passed to [done], once it was called.
  Map<String, bool>? get results => _doneBools;

  /// The results passed to [done] or [doneResults], with hints, once given.
  Map<String, PageResult>? get pageResults => _done;

  /// What the last [runCheck] / [runCheckResults] returned, with hints.
  Map<String, PageResult>? get checkedResults => _checked;

  /// Set once the body has used [done]: the frame shows no Check.
  bool get selfChecking => _selfChecking;

  Map<String, bool> _bools(Map<String, PageResult> results) => {
        for (final e in results.entries)
          e.key: e.value == PageResult.right || (e.value == PageResult.hinted && _hintedCountsRight),
      };

  static Map<String, PageResult> _fromBools(Map<String, bool> results) => {
        for (final e in results.entries) e.key: PageResult.of(e.value),
      };

  /// The body has an answer; [check] returns right/wrong by row id.
  void ready(Future<Map<String, bool>> Function() check) =>
      readyResults(() async => _fromBools(await check()));

  /// The body has an answer; [check] returns a [PageResult] by row id.
  void readyResults(Future<Map<String, PageResult>> Function() check, {bool hintedCountsRight = true}) {
    _check = check;
    _hintedCountsRight = hintedCountsRight;
    notifyListeners();
  }

  /// The answer is empty or incomplete: Check is disabled.
  void notReady() {
    if (_check == null) return;
    _check = null;
    notifyListeners();
  }

  /// The body checked itself; the frame passes [results] on at once.
  void done(Map<String, bool> results) {
    _hintedCountsRight = true;
    _selfChecking = true;
    _done = _fromBools(results);
    _doneBools = results;
    notifyListeners();
  }

  /// [done] with a [PageResult] by row id.
  void doneResults(Map<String, PageResult> results, {bool hintedCountsRight = true}) {
    _hintedCountsRight = hintedCountsRight;
    _selfChecking = true;
    _done = results;
    _doneBools = _bools(results);
    notifyListeners();
  }

  /// Runs the check function given to [ready]; empty when not ready.
  Future<Map<String, bool>> runCheck() async => _bools(await runCheckResults());

  /// Runs the check function given to [ready] or [readyResults], with hints;
  /// empty when not ready.
  Future<Map<String, PageResult>> runCheckResults() async {
    final check = _check;
    if (check == null) return const {};
    return _checked = await check();
  }

  /// Forgets the state for the next page.
  void reset() {
    _check = null;
    _done = null;
    _doneBools = null;
    _checked = null;
    _selfChecking = false;
    _hintedCountsRight = true;
    notifyListeners();
  }
}

/// One page of a learn session: which exercise it belongs to, its step
/// (1 Meet, 2 Practise, 3 Use), the rows it covers and the body to draw.
class ExercisePage {
  const ExercisePage({
    required this.exerciseId,
    required this.exerciseName,
    required this.step,
    required this.rowIds,
    required this.body,
  });

  final String exerciseId;
  final String exerciseName;
  final int step;
  final List<String> rowIds;
  final Widget Function(BuildContext, PageAnswer) body;
}

/// What the verdict bar says after a page was checked.
class PageVerdict {
  const PageVerdict({
    required this.right,
    required this.word,
    required this.translation,
    this.rightAnswer,
  });

  final bool right;
  final String word;
  final String translation;

  /// Shown on a wrong page when the body has one to show.
  final String? rightAnswer;
}

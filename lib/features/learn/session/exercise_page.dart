import 'package:flutter/widgets.dart';

/// The channel between an exercise page body and the learn page frame
/// (learn-redesign, ADR-0011). A body that needs the frame's Check button calls
/// [ready] with its check function once it has an answer and [notReady] when
/// the answer is cleared; a self-checking body calls [done] with its results
/// and the frame shows no Check.
class PageAnswer extends ChangeNotifier {
  Future<Map<String, bool>> Function()? _check;
  Map<String, bool>? _done;
  bool _selfChecking = false;

  /// Whether the body has an answer the frame can check.
  bool get isReady => _check != null;

  /// Whether the body reported its results itself ([done]).
  bool get isDone => _done != null;

  /// The results passed to [done], once it was called.
  Map<String, bool>? get results => _done;

  /// Set once the body has used [done]: the frame shows no Check.
  bool get selfChecking => _selfChecking;

  /// The body has an answer; [check] returns right/wrong by row id.
  void ready(Future<Map<String, bool>> Function() check) {
    _check = check;
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
    _selfChecking = true;
    _done = results;
    notifyListeners();
  }

  /// Runs the check function given to [ready]; empty when not ready.
  Future<Map<String, bool>> runCheck() async {
    final check = _check;
    if (check == null) return const {};
    return check();
  }

  /// Forgets the state for the next page.
  void reset() {
    _check = null;
    _done = null;
    _selfChecking = false;
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

/// How a typed answer compares with the stored word (learn-kit AC-11,
/// AC-12, S-10; D-18). [almost] is one slip on a word of five or more
/// letters: it counts as right, and the exercise shows the correct spelling.
enum TypedMatch {
  right,
  almost,
  wrong;

  bool get isRight => this != TypedMatch.wrong;
}

final _spaces = RegExp(r'\s+');
final _leading = RegExp(r'^(to|a|an|the) ');

/// Trim, lower-case, collapse spaces, drop one leading "to"/"a"/"an"/"the".
String _normal(String text) =>
    text.trim().toLowerCase().replaceAll(_spaces, ' ').replaceFirst(_leading, '');

/// Endings that make another form of the word, not a slip (D-18).
const _forms = ['s', 'es', 'ed', 'ing', 'd'];

/// The answer against the stored word. No AI, no network.
TypedMatch matchTyped(String answer, String expected) {
  final a = _normal(answer);
  final e = _normal(expected);
  if (a.isEmpty || e.isEmpty) return TypedMatch.wrong;
  if (a == e) return TypedMatch.right;
  if (e.replaceAll(' ', '').length < 5) return TypedMatch.wrong;
  if (_forms.any((ending) => a == e + ending)) return TypedMatch.wrong;
  return _oneEdit(a, e) ? TypedMatch.almost : TypedMatch.wrong;
}

/// True when [a] is one add, drop, change or swap of neighbours from [b]
/// (optimal string alignment distance 1).
bool _oneEdit(String a, String b) {
  final x = a.runes.toList();
  final y = b.runes.toList();
  if ((x.length - y.length).abs() > 1) return false;
  var i = 0;
  while (i < x.length && i < y.length && x[i] == y[i]) {
    i++;
  }
  bool same(List<int> p, int from, List<int> q, int qFrom) {
    if (p.length - from != q.length - qFrom) return false;
    for (var k = 0; k < p.length - from; k++) {
      if (p[from + k] != q[qFrom + k]) return false;
    }
    return true;
  }

  if (x.length == y.length) {
    if (same(x, i + 1, y, i + 1)) return true; // change
    return i + 1 < x.length && x[i] == y[i + 1] && x[i + 1] == y[i] && same(x, i + 2, y, i + 2); // swap
  }
  return x.length > y.length ? same(x, i + 1, y, i) : same(x, i, y, i + 1); // add / drop
}

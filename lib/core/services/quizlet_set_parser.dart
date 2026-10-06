import 'dart:convert';

/// One card of a Quizlet set as read from the page: the term, its back side
/// and an optional example sentence. Any of them may be empty (an image-only
/// card has no text term); the cards rules decide what is proposed.
class QuizletCard {
  const QuizletCard({required this.term, this.back = '', this.example = ''});

  final String term;
  final String back;
  final String example;

  @override
  bool operator ==(Object other) =>
      other is QuizletCard &&
      other.term == term &&
      other.back == back &&
      other.example == example;

  @override
  int get hashCode => Object.hash(term, back, example);

  @override
  String toString() => 'QuizletCard($term | $back | $example)';
}

/// The set read from a page: [statedCount] is the "Terms in this set (N)"
/// number, or null when the page states none.
class QuizletSet {
  const QuizletSet({
    required this.setId,
    required this.name,
    required this.statedCount,
    required this.cards,
  });

  final String setId;
  final String name;
  final int? statedCount;
  final List<QuizletCard> cards;
}

/// What one read of the page gave.
sealed class QuizletPageRead {
  const QuizletPageRead();
}

/// Cards of the asked-for set were found.
class QuizletSetFound extends QuizletPageRead {
  const QuizletSetFound(this.set);
  final QuizletSet set;
}

/// Quizlet's own robot check is on screen (AC-05).
class QuizletRobotCheck extends QuizletPageRead {
  const QuizletRobotCheck();
}

/// No cards yet: still loading, not understood, or a page of another set.
/// [name] is the set's name when the page of the asked-for set already
/// states it (shown in the progress dialog, AC-02), otherwise empty.
class QuizletNothingYet extends QuizletPageRead {
  const QuizletNothingYet({this.name = ''});
  final String name;
}

/// Known signs of Quizlet's robot check, matched case-insensitively against
/// the script's `robot` text (page title and challenge element ids/classes).
/// The one place to extend when a new kind of check shows up (sad §11).
const List<String> quizletRobotCheckMarkers = [
  'just a moment',
  'attention required',
  'verify you are human',
  'verifying you are human',
  'are you a robot',
  'not a robot',
  'captcha',
  'cf-challenge',
  'challenge-form',
  'challenge-platform',
  'cf-turnstile',
  'px-captcha',
];

/// Turns the reader script's raw output [raw] (a JSON string) into what the
/// page holds for the set [setId] (ADR-0003, ADR-0004). Never throws.
///
/// A robot check wins over everything else; material of another set id, or
/// with no stated id, counts as nothing yet. Embedded data is preferred; the
/// visible term list is the fallback.
QuizletPageRead parseQuizletPage(String raw, String setId) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const QuizletNothingYet();
  }
  if (decoded is! Map) return const QuizletNothingYet();

  final robot = _str(decoded['robot']).toLowerCase();
  if (robot.isNotEmpty &&
      quizletRobotCheckMarkers.any((marker) => robot.contains(marker))) {
    return const QuizletRobotCheck();
  }

  if (_str(decoded['setId']) != setId) return const QuizletNothingYet();

  final embedded = _readEmbedded(decoded['embedded'], setId);
  if (embedded != null && embedded.ofAnotherSet) {
    return const QuizletNothingYet();
  }
  final pageName = _cleanName(_str(decoded['name']));
  final name = pageName.isNotEmpty ? pageName : (embedded?.name ?? '');
  var cards = embedded?.cards ?? const <QuizletCard>[];
  if (cards.isEmpty) cards = _readVisible(decoded['visible']);
  if (cards.isEmpty) return QuizletNothingYet(name: name);

  final stated =
      _countFromHeading(_str(decoded['heading'])) ?? embedded?.statedCount;
  return QuizletSetFound(
      QuizletSet(setId: setId, name: name, statedCount: stated, cards: cards));
}

class _Embedded {
  _Embedded(this.cards, this.name, this.statedCount,
      {this.ofAnotherSet = false});
  final List<QuizletCard> cards;
  final String? name;
  final int? statedCount;

  /// The embedded data names a set other than the asked-for one.
  final bool ofAnotherSet;
}

String _str(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');

String _cleanName(String title) => title
    .replaceFirst(RegExp(r'\s*[|\-–]\s*Quizlet\s*$', caseSensitive: false), '')
    .replaceFirst(RegExp(r'\s+Flashcards$', caseSensitive: false), '')
    .trim();

int? _countFromHeading(String heading) {
  final m = RegExp(r'\((\d{1,6})\)').firstMatch(heading);
  return m == null ? null : int.parse(m.group(1)!);
}

List<QuizletCard> _readVisible(Object? visible) {
  if (visible is! List) return const [];
  final cards = <QuizletCard>[];
  for (final row in visible) {
    if (row is! List) continue;
    final sides = [for (final s in row) _str(s)];
    if (sides.every((s) => s.isEmpty)) continue;
    cards.add(QuizletCard(
      term: sides.isNotEmpty ? sides[0] : '',
      back: sides.length > 1 ? sides[1] : '',
      example: sides.length > 2 ? sides[2] : '',
    ));
  }
  return cards;
}

_Embedded? _readEmbedded(Object? embedded, String setId) {
  if (embedded is! String || embedded.isEmpty) return null;
  final root = _tryJson(embedded);
  if (root == null) return null;

  List<QuizletCard>? cards;
  String? name;
  int? count;
  String? statedId;

  void walk(Object? node, int depth) {
    if (depth > 12 || cards != null && statedId != null) return;
    if (node is String) {
      final inner = _tryJson(node);
      if (inner != null) walk(inner, depth + 1);
    } else if (node is List) {
      for (final v in node) {
        walk(v, depth + 1);
      }
    } else if (node is Map) {
      final items = node['studiableItems'];
      if (cards == null && items is List && items.isNotEmpty) {
        cards = _cardsFromItems(items);
      }
      final terms = node['terms'];
      if (cards == null && terms is List && terms.isNotEmpty) {
        final flat = _cardsFromFlatTerms(terms);
        if (flat.isNotEmpty) cards = flat;
      }
      final set = node['set'];
      if (set is Map && set['id'] != null && statedId == null) {
        statedId = _str(set['id']);
        final title = _str(set['title']);
        if (title.isNotEmpty) name = title;
        final n = set['numTerms'] ?? set['termCount'];
        if (n is int) count = n;
      }
      for (final v in node.values) {
        if (v is Map || v is List || v is String && v.length > 40) {
          walk(v, depth + 1);
        }
      }
    }
  }

  walk(root, 0);
  if (statedId != null && statedId != setId) {
    return _Embedded(const [], null, null, ofAnotherSet: true);
  }
  return _Embedded(cards ?? const [], name, count);
}

Object? _tryJson(String s) {
  final t = s.trimLeft();
  if (!(t.startsWith('{') || t.startsWith('['))) return null;
  try {
    return jsonDecode(t);
  } catch (_) {
    return null;
  }
}

List<QuizletCard> _cardsFromItems(List items) {
  final cards = <QuizletCard>[];
  for (final item in items) {
    if (item is! Map) continue;
    final sides = item['cardSides'];
    if (sides is! List) continue;
    final texts = [for (final side in sides) _sideText(side)];
    cards.add(QuizletCard(
      term: texts.isNotEmpty ? texts[0] : '',
      back: texts.length > 1 ? texts[1] : '',
      example: texts.length > 2 ? texts[2] : '',
    ));
  }
  return cards;
}

// A side holds media; only text media (type 1) is read, images are ignored.
String _sideText(Object? side) {
  if (side is! Map) return '';
  final media = side['media'];
  if (media is! List) return '';
  final parts = <String>[];
  for (final m in media) {
    if (m is Map && m['type'] == 1) {
      final t = _str(m['plainText']);
      if (t.isNotEmpty) parts.add(t);
    }
  }
  return parts.join('\n');
}

List<QuizletCard> _cardsFromFlatTerms(List terms) {
  final cards = <QuizletCard>[];
  for (final t in terms) {
    if (t is! Map || !t.containsKey('word')) continue;
    cards.add(QuizletCard(
      term: _str(t['word']),
      back: _str(t['definition']),
      example: _str(t['example']),
    ));
  }
  return cards;
}

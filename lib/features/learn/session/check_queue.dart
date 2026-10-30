/// Why a word was flagged for a self-check card (self-check-cards AC-01).
enum CheckReason {
  /// A wrong page ("Show answer" counts as wrong, Q-3).
  mistake,

  /// A right page reached only after a hint.
  hint,
}

/// A self-check card waiting to be shown or rated.
class CheckCard {
  CheckCard(this.rowId, this.reason);

  final String rowId;

  /// [CheckReason.mistake] once any of the flags it stands for was a mistake.
  CheckReason reason;

  /// Exercise pages of other words recorded since the flag.
  int othersSince = 0;
}

/// The pure scheduling of self-check cards in a learning session
/// (self-check-cards AC-02).
///
/// [pageDone] records each answered exercise page with the words it flagged.
/// A flagged word's card is due once [distance] pages of other words were
/// recorded after the flag, or as soon as no exercise page is left. A due
/// card waits one more page while it would sit directly next to the same
/// word's own page (the page just recorded or the next one) and another
/// word's page is still pending. Every flag gets a card (no limit); a word
/// flagged again while its card is still waiting keeps that one card (a
/// mistake wins over a hint); a word flagged after its card was rated gets a
/// new card. [rate] stores the rating; the last rating of a word counts.
///
/// [R] is the rating type (the self-check card's rating).
class CheckQueue<R> {
  /// How many pages of other words come between a flag and its card.
  static const defaultDistance = 3;

  CheckQueue({this.distance = defaultDistance}) : assert(distance >= 1);

  final int distance;

  final _waiting = <CheckCard>[];
  final _ratings = <String, R>{};
  final _reasons = <String, CheckReason>{};
  Set<String> _lastPage = const {};
  int _rated = 0;

  /// Records one answered exercise page holding [rowIds]; [flags] are the
  /// words it flagged, with their reasons.
  void pageDone(Iterable<String> rowIds, [Map<String, CheckReason> flags = const {}]) {
    final ids = rowIds.toSet();
    for (final card in _waiting) {
      if (!ids.contains(card.rowId)) card.othersSince++;
    }
    flags.forEach((id, reason) {
      final waiting = _cardOf(id);
      if (waiting != null) {
        if (reason == CheckReason.mistake) waiting.reason = CheckReason.mistake;
      } else {
        _waiting.add(CheckCard(id, reason));
      }
    });
    _lastPage = ids;
  }

  /// The card to show now, or null when no card is due.
  ///
  /// [next] is the word of the next exercise page, null when no exercise
  /// page is left (every waiting card is then due); [othersPending] tells
  /// whether an exercise page of a word other than the given one is still
  /// pending (default: yes).
  CheckCard? due({String? next, bool Function(String rowId)? othersPending}) {
    for (final card in _waiting) {
      if (next == null) return card;
      if (card.othersSince < distance) continue;
      final adjacent = _lastPage.contains(card.rowId) || next == card.rowId;
      if (adjacent && (othersPending?.call(card.rowId) ?? true)) continue;
      return card;
    }
    return null;
  }

  /// The due card of [rowId] was rated: it leaves the queue and [rating]
  /// replaces any earlier rating of the word.
  void rate(String rowId, R rating) {
    final card = _cardOf(rowId);
    if (card == null) throw StateError('$rowId has no waiting card');
    _waiting.remove(card);
    _ratings[rowId] = rating;
    _reasons[rowId] = card.reason;
    _rated++;
    _lastPage = const {};
  }

  CheckCard? _cardOf(String rowId) {
    for (final card in _waiting) {
      if (card.rowId == rowId) return card;
    }
    return null;
  }

  /// Cards flagged but not rated yet.
  int get waitingCount => _waiting.length;

  /// Whether [rowId] has a card waiting.
  bool isWaiting(String rowId) => _cardOf(rowId) != null;

  /// How many cards were rated.
  int get rated => _rated;

  /// Each rated word's last rating, by row id.
  Map<String, R> get ratings => Map.unmodifiable(_ratings);

  /// The reason of the card that gave each rated word its last rating.
  Map<String, CheckReason> get ratedReasons => Map.unmodifiable(_reasons);
}

/// Pure scheduler for the story pages of the Learn flow (learn-welcome AC-10).
///
/// After each rated card, after a Skip on a wait page, and when a story becomes
/// ready while a wait page shows, [StorySlots] answers what the next page is.
/// It holds no timers or widgets; the notifier passes in what is ready.
library;

/// The page that comes next.
sealed class NextSlot {
  const NextSlot();
}

/// The next card.
class CardSlot extends NextSlot {
  const CardSlot();
}

/// The story page of group [story] (0-based).
class StorySlot extends NextSlot {
  const StorySlot(this.story);
  final int story;
}

/// The "Writing your story…" page of group [story].
class WaitSlot extends NextSlot {
  const WaitSlot(this.story);
  final int story;
}

/// Cards and due stories are done. [saved] lists the stories skipped to the
/// end and still not ready: they stay only in Story runs ("Story saved to
/// Story runs" on the results).
class DialogSlot extends NextSlot {
  const DialogSlot(this.saved);
  final List<int> saved;
}

class StorySlots {
  /// [groupEnds] are the card counts after which each story is due, ascending;
  /// [totalCards] the number of cards in the flow; [extraCardLimit] how many
  /// more cards a due story that is not ready may wait behind.
  StorySlots({
    required List<int> groupEnds,
    required this.totalCards,
    this.extraCardLimit = 5,
  })  : groupEnds = List.unmodifiable(groupEnds),
        _dueAt = List.of(groupEnds),
        _state = List.filled(groupEnds.length, _Pending.pending);

  final List<int> groupEnds;
  final int totalCards;
  final int extraCardLimit;

  // Card count at which story i is due; a Skip moves it to the next slot's.
  final List<int> _dueAt;
  final List<_Pending> _state;
  // Skipped past the last slot: due only once all cards are done, never waits.
  final Set<int> _final = {};
  final List<int> _saved = [];

  /// Stories saved to Story runs so far.
  List<int> get saved => List.unmodifiable(_saved);

  /// The next page after [cardsDone] cards, given the [ready] stories.
  /// Call it again when a story becomes ready while a wait page shows.
  NextSlot next({required int cardsDone, required Set<int> ready}) {
    final due = <int>[
      for (var i = 0; i < _state.length; i++)
        if (_state[i] == _Pending.pending &&
            cardsDone >= _dueAt[i] &&
            (!_final.contains(i) || cardsDone >= totalCards))
          i,
    ];
    for (final i in due) {
      if (ready.contains(i)) {
        _state[i] = _Pending.shown;
        return StorySlot(i);
      }
    }
    for (final i in due.toList()) {
      if (_final.contains(i)) {
        _state[i] = _Pending.saved;
        _saved.add(i);
        due.remove(i);
      }
    }
    if (due.isNotEmpty) {
      final first = due.first;
      final extra = cardsDone - _dueAt[first];
      if (cardsDone < totalCards && extra < extraCardLimit) {
        return const CardSlot();
      }
      return WaitSlot(first);
    }
    if (cardsDone < totalCards) return const CardSlot();
    return DialogSlot(saved);
  }

  /// "Skip, show it later" on the wait page of [story]: it moves to the next
  /// story slot, else to just before the dialog. Returns the next page.
  NextSlot skip(int story, {required int cardsDone, required Set<int> ready}) {
    final nextSlot = story + 1;
    if (nextSlot < _dueAt.length) {
      _dueAt[story] = _dueAt[nextSlot];
    } else {
      _dueAt[story] = totalCards;
      _final.add(story);
    }
    // A story skipped to a slot already reached waits again behind it only
    // after the cards that follow, so measure its extras from now.
    if (_dueAt[story] < cardsDone) _dueAt[story] = cardsDone;
    return next(cardsDone: cardsDone, ready: ready);
  }
}

enum _Pending { pending, shown, saved }

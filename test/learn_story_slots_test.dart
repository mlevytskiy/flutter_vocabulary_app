import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/story_slots.dart';

void main() {
  // Three groups of 7 cards: stories are due after cards 7, 14 and 21.
  StorySlots make({int limit = 5}) =>
      StorySlots(groupEnds: [7, 14, 21], totalCards: 21, extraCardLimit: limit);

  test('a card comes next while no story is due', () {
    final s = make();
    expect(s.next(cardsDone: 3, ready: {}), isA<CardSlot>());
  });

  test('a ready story comes right after the last card of its group', () {
    final s = make();
    final p = s.next(cardsDone: 7, ready: {0});
    expect(p, isA<StorySlot>());
    expect((p as StorySlot).story, 0);
    // The story is shown once; then cards go on.
    expect(s.next(cardsDone: 7, ready: {0}), isA<CardSlot>());
  });

  test('a story not ready gets up to 5 extra cards, then shows when ready', () {
    final s = make();
    for (var done = 7; done < 12; done++) {
      expect(s.next(cardsDone: done, ready: {}), isA<CardSlot>(),
          reason: '$done');
    }
    final p = s.next(cardsDone: 10, ready: {0});
    expect((p as StorySlot).story, 0);
  });

  test('after the extra-card limit the wait page shows', () {
    final s = make();
    final p = s.next(cardsDone: 12, ready: {});
    expect(p, isA<WaitSlot>());
    expect((p as WaitSlot).story, 0);
  });

  test('the extra-card limit is a parameter', () {
    final s = make(limit: 2);
    expect(s.next(cardsDone: 8, ready: {}), isA<CardSlot>());
    expect(s.next(cardsDone: 9, ready: {}), isA<WaitSlot>());
  });

  test('a story that becomes ready while the wait page shows opens', () {
    final s = make();
    expect(s.next(cardsDone: 12, ready: {}), isA<WaitSlot>());
    final p = s.next(cardsDone: 12, ready: {0});
    expect((p as StorySlot).story, 0);
  });

  test('a last group with no cards after it goes straight to the wait page',
      () {
    final s = make();
    expect(s.next(cardsDone: 7, ready: {0}), isA<StorySlot>());
    expect(s.next(cardsDone: 14, ready: {1}), isA<StorySlot>());
    final p = s.next(cardsDone: 21, ready: {});
    expect((p as WaitSlot).story, 2);
  });

  test('no cards left and nothing due ends in the dialog', () {
    final s = make();
    s.next(cardsDone: 7, ready: {0});
    s.next(cardsDone: 14, ready: {1});
    s.next(cardsDone: 21, ready: {2});
    final p = s.next(cardsDone: 21, ready: {});
    expect(p, isA<DialogSlot>());
    expect((p as DialogSlot).saved, isEmpty);
  });

  test('a skipped story moves to the next story slot and shows there', () {
    final s = make();
    expect(s.next(cardsDone: 12, ready: {}), isA<WaitSlot>());
    // Skip: cards go on.
    expect(s.skip(0, cardsDone: 12, ready: {}), isA<CardSlot>());
    // At the next slot, story 0 (now ready) comes before story 1.
    final p = s.next(cardsDone: 14, ready: {0, 1});
    expect((p as StorySlot).story, 0);
    expect((s.next(cardsDone: 14, ready: {1}) as StorySlot).story, 1);
  });

  test('a story skipped at the last slot goes before the dialog', () {
    final s = make();
    s.next(cardsDone: 7, ready: {0});
    s.next(cardsDone: 14, ready: {1});
    expect(s.next(cardsDone: 21, ready: {}), isA<WaitSlot>());
    final p = s.skip(2, cardsDone: 21, ready: {});
    expect(p, isA<DialogSlot>());
    expect((p as DialogSlot).saved, [2]);
  });

  test('a skipped story ready before the dialog is shown, not saved', () {
    final s = make();
    s.next(cardsDone: 7, ready: {0});
    s.next(cardsDone: 14, ready: {1});
    s.next(cardsDone: 21, ready: {});
    expect(s.skip(2, cardsDone: 21, ready: {2}), isA<StorySlot>());
    final p = s.next(cardsDone: 21, ready: {});
    expect((p as DialogSlot).saved, isEmpty);
  });

  test('a story skipped at a middle slot waits again at the next slot', () {
    final s = make();
    s.next(cardsDone: 12, ready: {}); // wait 0
    s.skip(0, cardsDone: 12, ready: {});
    // Slot 1 reached; neither ready: extra cards, story 0 first in line.
    expect(s.next(cardsDone: 14, ready: {}), isA<CardSlot>());
    final p = s.next(cardsDone: 19, ready: {});
    expect((p as WaitSlot).story, 0);
  });

  test('a single group with all cards done waits at once', () {
    final s = StorySlots(groupEnds: [5], totalCards: 5);
    expect((s.next(cardsDone: 5, ready: {}) as WaitSlot).story, 0);
  });

  test('no groups means cards, then the dialog', () {
    final s = StorySlots(groupEnds: [], totalCards: 3);
    expect(s.next(cardsDone: 2, ready: {}), isA<CardSlot>());
    expect(s.next(cardsDone: 3, ready: {}), isA<DialogSlot>());
  });
}

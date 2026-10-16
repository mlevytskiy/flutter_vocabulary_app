// T4 (collections-screen): the pure filing rules — tree walks, a folder into
// itself (AC-15), level renumbering, the restore target (AC-24), days left
// (AC-23), the 30-day expiry with a controlled clock (AC-26, QG-5) and the
// empty-and-untouched rule (AC-19).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/services/filing.dart';

void main() {
  // Collections › English course › Unit 3 › Week 1, and Travel at the top.
  const parentOf = <String, String?>{
    'english': null,
    'unit3': 'english',
    'week1': 'unit3',
    'unit4': 'english',
    'travel': null,
  };

  group('ancestorsOf / descendantsOf', () {
    test('ancestors run from the parent up to the top', () {
      expect(ancestorsOf('week1', parentOf), ['unit3', 'english']);
      expect(ancestorsOf('english', parentOf), isEmpty);
    });

    test('a broken loop in stored data does not hang', () {
      expect(ancestorsOf('a', {'a': 'b', 'b': 'a'}), ['b', 'a']);
    });

    test('descendants are every folder inside, at any depth', () {
      expect(descendantsOf('english', parentOf), {'unit3', 'week1', 'unit4'});
      expect(descendantsOf('unit4', parentOf), isEmpty);
      expect(descendantsOf('travel', parentOf), isEmpty);
    });
  });

  group('isInBin', () {
    test('an item marked itself is in the bin', () {
      expect(
          isInBin(
              binned: true,
              folderId: null,
              parentOf: parentOf,
              binnedFolderIds: {}),
          isTrue);
    });

    test('an item inside a binned folder, at any depth, is in the bin', () {
      expect(
          isInBin(
              binned: false,
              folderId: 'week1',
              parentOf: parentOf,
              binnedFolderIds: {'english'}),
          isTrue);
      expect(
          isInBin(
              binned: false,
              folderId: 'english',
              parentOf: parentOf,
              binnedFolderIds: {'english'}),
          isTrue);
    });

    test('an item outside every binned folder is not', () {
      expect(
          isInBin(
              binned: false,
              folderId: 'week1',
              parentOf: parentOf,
              binnedFolderIds: {'unit4', 'travel'}),
          isFalse);
      expect(
          isInBin(
              binned: false,
              folderId: null,
              parentOf: parentOf,
              binnedFolderIds: {'english'}),
          isFalse);
    });
  });

  group('canMoveFolderInto (AC-15)', () {
    test('a folder cannot go into itself', () {
      expect(canMoveFolderInto('english', 'english', parentOf), isFalse);
    });

    test('a folder cannot go into a folder inside it, at any depth', () {
      expect(canMoveFolderInto('english', 'unit3', parentOf), isFalse);
      expect(canMoveFolderInto('english', 'week1', parentOf), isFalse);
    });

    test('a folder can go to the top, a sibling or an outside folder', () {
      expect(canMoveFolderInto('unit3', null, parentOf), isTrue);
      expect(canMoveFolderInto('unit3', 'unit4', parentOf), isTrue);
      expect(canMoveFolderInto('english', 'travel', parentOf), isTrue);
      expect(canMoveFolderInto('week1', 'english', parentOf), isTrue);
    });
  });

  group('placeInLevel (renumbering 0..n-1)', () {
    test('a new item goes at the end by default', () {
      expect(placeInLevel(['a', 'b'], 'new'), ['a', 'b', 'new']);
    });

    test('a new item goes at the given place and the rest shift along', () {
      expect(placeInLevel(['a', 'b', 'c'], 'new', at: 1),
          ['a', 'new', 'b', 'c']);
    });

    test('a move within the level takes the dropped-on place', () {
      expect(placeInLevel(['a', 'b', 'c', 'd'], 'a', at: 2),
          ['b', 'c', 'a', 'd']);
      expect(placeInLevel(['a', 'b', 'c', 'd'], 'd', at: 0),
          ['d', 'a', 'b', 'c']);
    });

    test('a place past the end, or below 0, is clamped', () {
      expect(placeInLevel(['a', 'b'], 'new', at: 9), ['a', 'b', 'new']);
      expect(placeInLevel(['a', 'b'], 'new', at: -3), ['new', 'a', 'b']);
      expect(placeInLevel(['a', 'b', 'c'], 'a', at: 9), ['b', 'c', 'a']);
    });

    test('ordersOf numbers a level 0..n-1', () {
      expect(ordersOf(['x', 'y', 'z']), {'x': 0, 'y': 1, 'z': 2});
      expect(ordersOf(placeInLevel(['a', 'b'], 'new', at: 1)),
          {'a': 0, 'new': 1, 'b': 2});
    });
  });

  group('restoreTarget (AC-24, spec §8)', () {
    test('back to the old folder at the old place when it is in the level',
        () {
      final t = restoreTarget(
          binnedFromFolderId: 'unit3',
          folderUsable: true,
          oldOrder: 1,
          levelLength: 4);
      expect(t.folderId, 'unit3');
      expect(t.order, 1);
    });

    test('the old place past the level is the end', () {
      final t = restoreTarget(
          binnedFromFolderId: 'unit3',
          folderUsable: true,
          oldOrder: 7,
          levelLength: 2);
      expect(t.folderId, 'unit3');
      expect(t.order, 2);
    });

    test('a folder that is gone or in the bin means the top level', () {
      final t = restoreTarget(
          binnedFromFolderId: 'unit3',
          folderUsable: false,
          oldOrder: 0,
          levelLength: 5);
      expect(t.folderId, isNull);
      expect(t.order, 0);
    });

    test('deleted from the top level returns to the top level', () {
      final t = restoreTarget(
          binnedFromFolderId: null,
          folderUsable: false,
          oldOrder: 3,
          levelLength: 3);
      expect(t.folderId, isNull);
      expect(t.order, 3);
    });
  });

  group('daysLeft (AC-23)', () {
    final binnedAt = DateTime(2026, 10, 16, 23, 50);

    test('30 on the day of deletion', () {
      expect(daysLeft(binnedAt, binnedAt), 30);
      expect(daysLeft(binnedAt, DateTime(2026, 10, 16, 23, 59)), 30);
    });

    test('counts calendar days, not 24-hour spans', () {
      expect(daysLeft(binnedAt, DateTime(2026, 10, 17, 0, 5)), 29);
    });

    test('1 on the last day, and still 1 until the sweep erases it', () {
      expect(daysLeft(binnedAt, DateTime(2026, 11, 14, 12)), 1);
      expect(daysLeft(binnedAt, DateTime(2026, 11, 15, 12)), 1);
      expect(daysLeft(binnedAt, DateTime(2027, 1, 1)), 1);
    });

    test('across the daylight-saving change in local time', () {
      final march = DateTime(2026, 3, 20, 12);
      expect(daysLeft(march, DateTime(2026, 4, 1, 12)), 18);
    });

    test('a clock moved backwards never shows more than 30', () {
      expect(daysLeft(binnedAt, DateTime(2026, 10, 1)), 30);
    });
  });

  group('isExpired (AC-26, QG-5 controlled clock)', () {
    final binnedAt = DateTime.utc(2026, 10, 16, 14, 30);
    const retention = Duration(hours: 30 * 24);

    test('the bin keeps an item for 30 × 24 h', () {
      expect(binRetention, retention);
    });

    test('not expired one microsecond before 30 × 24 h', () {
      expect(
          isExpired(binnedAt,
              binnedAt.add(retention - const Duration(microseconds: 1))),
          isFalse);
    });

    test('expired at exactly binnedAt + 30 × 24 h and after', () {
      expect(isExpired(binnedAt, binnedAt.add(retention)), isTrue);
      expect(isExpired(binnedAt, binnedAt.add(const Duration(days: 400))),
          isTrue);
    });

    test('not expired right after deletion, even if the app was not opened',
        () {
      expect(isExpired(binnedAt, binnedAt), isFalse);
      expect(isExpired(binnedAt, binnedAt.add(const Duration(days: 29))),
          isFalse);
    });

    test('a clock moved backwards never erases early', () {
      // The clock jumps back a year at a later open, then forward to 29 days.
      expect(
          isExpired(binnedAt, binnedAt.subtract(const Duration(days: 365))),
          isFalse);
      expect(
          isExpired(binnedAt, binnedAt.subtract(const Duration(days: 1))),
          isFalse);
      expect(isExpired(binnedAt, binnedAt.add(const Duration(days: 29))),
          isFalse);
    });

    test('a clock moved forward is trusted', () {
      expect(isExpired(binnedAt, binnedAt.add(const Duration(days: 31))),
          isTrue);
    });

    test('a local-time binnedAt and a UTC now compare as moments', () {
      final local = DateTime(2026, 10, 16, 14, 30);
      expect(isExpired(local, local.toUtc().add(retention)), isTrue);
      expect(
          isExpired(local,
              local.toUtc().add(retention - const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('isEmptyAndUntouched (AC-19)', () {
    test('only a collection with nothing in it and never kept', () {
      expect(
          isEmptyAndUntouched(
              hasWords: false,
              hasSources: false,
              hasNotesOrTags: false,
              keep: false),
          isTrue);
    });

    for (final (label, words, sources, notes, keep) in [
      ('words', true, false, false, false),
      ('a photo or other source', false, true, false, false),
      ('notes or tags', false, false, true, false),
      ('keep: made with New collection, renamed, moved or reordered', false,
          false, false, true),
    ]) {
      test('kept for $label', () {
        expect(
            isEmptyAndUntouched(
                hasWords: words,
                hasSources: sources,
                hasNotesOrTags: notes,
                keep: keep),
            isFalse);
      });
    }
  });
}

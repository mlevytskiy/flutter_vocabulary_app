/// Splits an exercise's usable words into rounds (learn-kit AC-09, S-07):
/// word order kept, the fewest rounds of at most [max], sizes differing by at
/// most one (larger rounds first), never a round under [min]. Fewer than [min]
/// items give no round (the "not enough words" screen, AC-08). Pure: the same
/// input always gives the same split.
List<List<T>> splitRounds<T>(List<T> items, {required int min, required int max}) {
  assert(min >= 1 && max >= 2 * min - 1, 'max must be at least 2 × min − 1');
  final n = items.length;
  if (n < min) return const [];
  final count = (n / max).ceil();
  final base = n ~/ count;
  final larger = n % count;
  final rounds = <List<T>>[];
  var at = 0;
  for (var i = 0; i < count; i++) {
    final size = base + (i < larger ? 1 : 0);
    rounds.add(items.sublist(at, at + size));
    at += size;
  }
  return rounds;
}

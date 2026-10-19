import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/collection_store.dart';
import 'routes.dart';

/// Which screen the app opens on (start-screen, owner 2026-10-18).
///
/// Words when the learner left the app less than [recentGap] ago, or when
/// there is nothing to pick from (no collection, or only one and it is
/// empty: a new user); otherwise Collections. Only a cold start asks; coming
/// back to a running app keeps its screen.
abstract final class StartLocation {
  /// When the app last went to the background, in ms since epoch.
  static const leftAtKey = 'app_left_at';
  static const recentGap = Duration(minutes: 5);

  /// The rule itself, without storage: see the class doc.
  static String pick({
    required DateTime now,
    required DateTime? leftAt,
    required bool onlyOneEmpty,
  }) {
    final recent = leftAt != null && now.difference(leftAt) < recentGap;
    return recent || onlyOneEmpty
        ? const WordsRoute().location
        : const CollectionsRoute().location;
  }

  /// Reads what [pick] needs and returns its answer. Never throws:
  /// Collections when anything fails.
  static Future<String> resolve() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(leftAtKey);
      return pick(
        now: DateTime.now(),
        leftAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        onlyOneEmpty: await CollectionStore.onlyOneEmpty(),
      );
    } catch (_) {
      return const CollectionsRoute().location;
    }
  }

  /// Notes that the app went to the background now.
  static Future<void> recordLeave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(leftAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // the next start falls back to the older time, or Collections
    }
  }
}

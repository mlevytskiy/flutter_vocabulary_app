import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

/// Persists sessions in an Isar database (`vocab`), plus the one
/// `shared_preferences` pointer saying which session is the current one — the
/// pointer lives here because it is the same concept, "which session is now".
///
/// Nothing in this class throws on bad data: a store that kills the app on
/// launch because of a bad write is worse than one that loses a session.
class SessionStore {
  static const _currentSessionKey = 'current_session_id';

  final Isar _isar;
  final SharedPreferences _prefs;

  SessionStore._(this._isar, this._prefs);

  static Future<SessionStore> open({String? directory}) async {
    final dir =
        directory ?? (await getApplicationDocumentsDirectory()).path;
    final isar = Isar.getInstance('vocab') ??
        await Isar.open([SessionSchema], directory: dir, name: 'vocab');
    final prefs = await SharedPreferences.getInstance();
    return SessionStore._(isar, prefs);
  }

  Future<void> close() => _isar.close();

  Future<Session?> byId(String sessionId) async {
    try {
      return await _isar.sessions
          .filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();
    } catch (_) {
      return null;
    }
  }

  /// The session with the newest [Session.lastLocalModifiedAt], or null on an
  /// empty store.
  Future<Session?> newest() async {
    try {
      return await _isar.sessions
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findFirst();
    } catch (_) {
      return null;
    }
  }

  /// Sessions with at least one non-blank word, newest first.
  Future<List<Session>> nonEmpty() async {
    try {
      final all = await _isar.sessions
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findAll();
      return all.where((s) => !s.isEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Upsert on [Session.sessionId]. Blank pairs — the trailing empty row the
  /// screen always keeps — are stripped before the write and the caller's own
  /// session object is left untouched.
  Future<void> put(Session s) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.sessions
            .filter()
            .sessionIdEqualTo(s.sessionId)
            .findFirst();
        final toWrite = Session()
          ..id = existing?.id ?? Isar.autoIncrement
          ..sessionId = s.sessionId
          ..updatedAt = s.updatedAt
          ..lastLocalModifiedAt = s.lastLocalModifiedAt
          ..isShared = s.isShared
          ..words = [
            for (final w in s.words)
              if (!w.isEmpty) w.copy(),
          ];
        s.id = await _isar.sessions.put(toWrite);
      });
    } catch (_) {
      // Losing one debounced write is survivable; crashing the app is not.
    }
  }

  Future<void> delete(String sessionId) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.sessions
            .filter()
            .sessionIdEqualTo(sessionId)
            .findFirst();
        if (existing != null) await _isar.sessions.delete(existing.id);
      });
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  /// Emits once immediately and again after every write. The drawer rule and
  /// the History screen (task-10) read this.
  Stream<List<Session>> watchNonEmpty() => _isar.sessions
      .where()
      .sortByLastLocalModifiedAtDesc()
      .watch(fireImmediately: true)
      .map((all) => all.where((s) => !s.isEmpty).toList());

  Future<String?> currentSessionId() async =>
      _prefs.getString(_currentSessionKey);

  Future<void> setCurrentSessionId(String sessionId) async {
    await _prefs.setString(_currentSessionKey, sessionId);
  }
}

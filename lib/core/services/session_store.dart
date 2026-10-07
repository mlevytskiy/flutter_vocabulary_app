import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';
import '../models/story_run.dart';
import 'source_photo_store.dart' show uuidV4;

/// Persists sessions in an Isar database (`vocab`), plus the one
/// `shared_preferences` pointer saying which session is the current one — the
/// pointer lives here because it is the same concept, "which session is now".
///
/// Nothing in this class throws on bad data: a store that kills the app on
/// launch because of a bad write is worse than one that loses a session.
class SessionStore {
  static const _currentSessionKey = 'current_session_id';
  static const _switchedSessionKey = 'switched_session_id';
  static const _switchedAtKey = 'switched_at';

  final Isar _isar;
  final SharedPreferences _prefs;

  SessionStore._(this._isar, this._prefs);

  static Future<SessionStore> open({String? directory}) async {
    final dir =
        directory ?? (await getApplicationDocumentsDirectory()).path;
    final isar = Isar.getInstance('vocab') ??
        await Isar.open([SessionSchema, StoryRunSchema],
            directory: dir, name: 'vocab');
    final prefs = await SharedPreferences.getInstance();
    final store = SessionStore._(isar, prefs);
    await store._fillRowIdsEverywhere();
    return store;
  }

  /// Gives every row without a [WordPair.rowId] one and saves it, so rows
  /// stored before mnemonic-story get stable ids once. Returns [s] itself.
  /// Never throws, see the class doc.
  Future<Session> _withRowIds(Session s) async {
    if (s.words.every((w) => w.rowId.isNotEmpty)) return s;
    for (final w in s.words) {
      if (w.rowId.isEmpty) w.rowId = uuidV4();
    }
    try {
      await _isar.writeTxn(() => _isar.sessions.put(s));
    } catch (_) {
      // the ids stay on this object; the next read tries again
    }
    return s;
  }

  Future<void> _fillRowIdsEverywhere() async {
    try {
      for (final s in await _isar.sessions.where().findAll()) {
        await _withRowIds(s);
      }
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  Future<void> close() => _isar.close();

  Future<Session?> byId(String sessionId) async {
    try {
      final s = await _isar.sessions
          .filter()
          .sessionIdEqualTo(sessionId)
          .findFirst();
      return s == null ? null : await _withRowIds(s);
    } catch (_) {
      return null;
    }
  }

  /// The session with the newest [Session.lastLocalModifiedAt], or null on an
  /// empty store.
  Future<Session?> newest() async {
    try {
      final s = await _isar.sessions
          .where()
          .sortByLastLocalModifiedAtDesc()
          .findFirst();
      return s == null ? null : await _withRowIds(s);
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
      return [
        for (final s in all)
          if (!s.isEmpty) await _withRowIds(s),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Upsert on [Session.sessionId]. Blank pairs — the trailing empty row the
  /// screen always keeps — are stripped before the write and the caller's own
  /// session object is left untouched.
  Future<void> put(Session s) async {
    try {
      // A row keeps its id for good, so a new one gets it now, on the
      // caller's object too: a group may name it before the next read.
      for (final w in s.words) {
        if (!w.isEmpty && w.rowId.isEmpty) w.rowId = uuidV4();
      }
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
          ]
          ..sources = [for (final p in s.sources) p.copy()]
          ..publishedId = s.publishedId
          ..editToken = s.editToken
          ..groups = [for (final g in s.groups) g.copy()]
          ..selectedGroupId = s.selectedGroupId
          ..groupedWordsKey = s.groupedWordsKey;
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
      .asyncMap((all) async => [
            for (final s in all)
              if (!s.isEmpty) await _withRowIds(s),
          ]);

  Future<String?> currentSessionId() async =>
      _prefs.getString(_currentSessionKey);

  Future<void> setCurrentSessionId(String sessionId) async {
    await _prefs.setString(_currentSessionKey, sessionId);
  }

  /// Records that the learner picked [sessionId] from History at [at]
  /// (edit-session-from-history, ADR-0002). Kept beside the current-session
  /// pointer rather than on the session so a pick never looks like an edit.
  /// Nothing clears it; [switchedAt] only answers for the id it names.
  Future<void> setSwitched(String sessionId, DateTime at) async {
    try {
      await _prefs.setString(_switchedSessionKey, sessionId);
      await _prefs.setString(_switchedAtKey, at.toIso8601String());
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  /// When [sessionId] was last picked from History, or null if the pick
  /// record names another session, is missing, or cannot be read.
  Future<DateTime?> switchedAt(String sessionId) async {
    try {
      if (_prefs.getString(_switchedSessionKey) != sessionId) return null;
      final at = _prefs.getString(_switchedAtKey);
      return at == null ? null : DateTime.tryParse(at);
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/session.dart';
import 'services/dictionary_service.dart';
import 'services/google_translate_service.dart';
import 'services/photo_scaler.dart';
import 'services/pronunciation_service.dart';
import 'services/session_publish_service.dart';
import 'services/session_store.dart';
import 'services/vocab_photo_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) => SessionStore.open();

@Riverpod(keepAlive: true)
GoogleTranslateService googleTranslateService(Ref ref) =>
    GoogleTranslateService();

@Riverpod(keepAlive: true)
PronunciationService pronunciationService(Ref ref) => PronunciationService();

/// Dictionary senses for the definition field, via the Worker (ADR-0002).
@Riverpod(keepAlive: true)
DictionaryService dictionaryService(Ref ref) => DictionaryService();

@Riverpod(keepAlive: true)
SessionPublishService sessionPublishService(Ref ref) => SessionPublishService();

@riverpod
Future<Session?> sessionById(Ref ref, String sessionId) async {
  final store = await ref.watch(sessionStoreProvider.future);
  return store.byId(sessionId);
}

/// Every session that has at least one non-blank word, newest first, re-emitted
/// after every write. The drawer rule on the input screen and the History
/// screen (task-10) both read this one stream.
@riverpod
Stream<List<Session>> nonEmptySessions(Ref ref) async* {
  final store = await ref.watch(sessionStoreProvider.future);
  yield* store.watchNonEmpty();
}

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `Session` because it is not
/// session data and must never reach Isar (task-13), and `keepAlive` because
/// the Settings screen is the only writer while the input screen is the only
/// reader -- autoDispose would drop the value when Settings is popped.
@Riverpod(keepAlive: true)
class DragMode extends _$DragMode {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// What every word row shows and every output carries (definition-mode):
/// translation, definition, or both. Changes what is shown, never what is
/// stored.
enum WordDetailMode { translation, definition, both }

/// Short name used across the app and the design docs; the class cannot be
/// called `WordDetailMode` because the enum is.
final wordDetailModeProvider = wordDetailModeNotifierProvider;

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `Session`. Starts as [WordDetailMode.translation] and
/// switches once the stored value is read ([loaded]).
@Riverpod(keepAlive: true)
class WordDetailModeNotifier extends _$WordDetailModeNotifier {
  static const prefsKey = 'word_detail_mode';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  WordDetailMode build() {
    loaded;
    return WordDetailMode.translation;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    // A choice made before the stored value arrived wins over it.
    if (_setByLearner) return;
    state = WordDetailMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => WordDetailMode.translation,
    );
  }

  Future<void> set(WordDetailMode mode) async {
    _setByLearner = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/session.dart';
import 'models/subtitle_import_options.dart';
import 'services/dictionary_service.dart';
import 'services/google_translate_service.dart';
import 'services/photo_scaler.dart';
import 'services/photo_upload_service.dart';
import 'services/pronunciation_service.dart';
import 'services/session_publish_service.dart';
import 'services/session_store.dart';
import 'services/source_photo_store.dart';
import 'services/vocab_photo_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) => SessionStore.open();

/// The kept 1600 px copies of the session photos (good-looking-web T17).
@Riverpod(keepAlive: true)
SourcePhotoStore sourcePhotoStore(Ref ref) => SourcePhotoStore();

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

/// Background upload of the photos a publish declared (good-looking-web T18).
/// keepAlive, so uploads outlive the words table (sad §8).
@Riverpod(keepAlive: true)
PhotoUploadService photoUploadService(Ref ref) =>
    PhotoUploadService(store: ref.watch(sourcePhotoStoreProvider));

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

/// Short name used across the app and the design docs.
final subtitleImportPrefsProvider = subtitleImportPrefsNotifierProvider;

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of purpose, level and maximum, the "Update with
/// each import" switch, and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.
@Riverpod(keepAlive: true)
class SubtitleImportPrefsNotifier extends _$SubtitleImportPrefsNotifier {
  static const purposeKey = 'subtitle_purpose';
  static const levelKey = 'subtitle_level';
  static const maximumKey = 'subtitle_maximum';
  static const updateEachImportKey = 'subtitle_update_each_import';
  static const modelKey = 'subtitle_model';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  SubtitleImportPrefs build() {
    loaded;
    return SubtitleImportPrefs.firstLaunch;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // A choice made before the stored values arrived wins over them.
    if (_setByLearner) return;
    const d = SubtitleImportPrefs.firstLaunch;
    final purpose = prefs.getString(purposeKey);
    final level = prefs.getString(levelKey);
    final maximum = prefs.getInt(maximumKey);
    final model = prefs.getString(modelKey);
    state = SubtitleImportPrefs(
      purpose: ImportPurpose.values.where((p) => p.name == purpose).firstOrNull ?? d.purpose,
      level: EnglishLevel.values.where((l) => l.wire == level).firstOrNull ?? d.level,
      maximum: maximum != null && SubtitleImportPrefs.isValidMaximum(maximum) ? maximum : d.maximum,
      updateEachImport: prefs.getBool(updateEachImportKey) ?? d.updateEachImport,
      model: SubtitleModel.values.where((m) => m.name == model).firstOrNull ?? d.model,
    );
  }

  Future<void> setPurpose(ImportPurpose purpose) async {
    _update(state.copyWith(purpose: purpose));
    await (await SharedPreferences.getInstance()).setString(purposeKey, purpose.name);
  }

  Future<void> setLevel(EnglishLevel level) async {
    _update(state.copyWith(level: level));
    await (await SharedPreferences.getInstance()).setString(levelKey, level.wire);
  }

  /// False, and nothing saved, when [maximum] is outside 1–100 (AC-09).
  Future<bool> setMaximum(int maximum) async {
    if (!SubtitleImportPrefs.isValidMaximum(maximum)) return false;
    _update(state.copyWith(maximum: maximum));
    await (await SharedPreferences.getInstance()).setInt(maximumKey, maximum);
    return true;
  }

  Future<void> setUpdateEachImport(bool on) async {
    _update(state.copyWith(updateEachImport: on));
    await (await SharedPreferences.getInstance()).setBool(updateEachImportKey, on);
  }

  Future<void> setModel(SubtitleModel model) async {
    _update(state.copyWith(model: model));
    await (await SharedPreferences.getInstance()).setString(modelKey, model.name);
  }

  /// Called at Start (F3): with "Update with each import" on, the values used
  /// become the Settings values; with it off, nothing changes (AC-05, AC-05b).
  Future<void> recordUsed({
    required ImportPurpose purpose,
    required EnglishLevel level,
    required int maximum,
  }) async {
    if (!state.updateEachImport) return;
    await setPurpose(purpose);
    await setLevel(level);
    await setMaximum(maximum);
  }

  void _update(SubtitleImportPrefs next) {
    _setByLearner = true;
    state = next;
  }
}

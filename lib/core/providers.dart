import 'dialogues/dialogue_push.dart' show DialoguePushService;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'models/offered_ai.dart';
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
import 'services/story_api_service.dart';
import 'services/story_picture_store.dart';
import 'services/story_run_store.dart';
import 'services/subtitle_google_words.dart';
import 'services/subtitle_search_service.dart';
import 'services/subtitle_words_service.dart';
import 'services/system_gesture_exclusion.dart';
import 'services/vocab_photo_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

/// Camera and gallery picks for the photo chain (photo-from-gallery T2);
/// a provider so widget tests can swap in a fake picker.
@riverpod
ImagePicker imagePicker(Ref ref) => ImagePicker();

@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) => SessionStore.open();

/// The kept 1600 px copies of the session photos (good-looking-web T17).
@Riverpod(keepAlive: true)
SourcePhotoStore sourcePhotoStore(Ref ref) => SourcePhotoStore();

/// The Android Back-gesture exclusion for the photo tab
/// (side-bar-for-main-screen ADR-0002).
@Riverpod(keepAlive: true)
SystemGestureExclusion systemGestureExclusion(Ref ref) => SystemGestureExclusion();

/// The story runs, kept in the same database as the sessions (ADR-0003).
@Riverpod(keepAlive: true)
Future<StoryRunStore> storyRunStore(Ref ref) async {
  await ref.watch(sessionStoreProvider.future); // opens the shared database
  return StoryRunStore.open();
}

/// The compressed story pictures kept on the phone.
@Riverpod(keepAlive: true)
StoryPictureStore storyPictureStore(Ref ref) => StoryPictureStore();

@Riverpod(keepAlive: true)
GoogleTranslateService googleTranslateService(Ref ref) =>
    GoogleTranslateService();

@Riverpod(keepAlive: true)
PronunciationService pronunciationService(Ref ref) => PronunciationService();

/// Dictionary senses for the definition field, via the Worker (ADR-0002).
@Riverpod(keepAlive: true)
DictionaryService dictionaryService(Ref ref) => DictionaryService();

/// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).
@Riverpod(keepAlive: true)
StoryApiService storyApiService(Ref ref) => StoryApiService();

/// The AIs on the Worker's offered list. Fetched on first use and cached in
/// preferences; when the fetch fails, the cached list is used, and when there is
/// none either, the built-in defaults (AC-13). Never throws.
@Riverpod(keepAlive: true)
Future<OfferedAiList> offeredAis(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final list = await ref.watch(storyApiServiceProvider).offeredAis();
    await prefs.setString(OfferedAiCache.key, jsonEncode(list.toJson()));
    return list;
  } catch (_) {
    final cached = prefs.getString(OfferedAiCache.key);
    if (cached != null) {
      try {
        return OfferedAiList.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        // A damaged cache is as good as none.
      }
    }
    return OfferedAiList.fallback;
  }
}

/// Short name used across the app and the design docs.
final aiChoiceProvider = aiChoiceNotifierProvider;

/// The learner's saved AI for each step of a story run (AC-12). Persisted like
/// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
/// before showing or using it, so a withdrawn AI falls back to the default (AC-13).
@Riverpod(keepAlive: true)
class AiChoiceNotifier extends _$AiChoiceNotifier {
  static String idKey(AiRole role) => 'story_ai_${role.name}';
  static String nameKey(AiRole role) => 'story_ai_${role.name}_name';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  StoredAiChoice build() {
    loaded;
    return const StoredAiChoice();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // A choice made before the stored values arrived wins over them.
    if (_setByLearner) return;
    final ids = <AiRole, String>{};
    final names = <AiRole, String>{};
    for (final role in AiRole.values) {
      final id = prefs.getString(idKey(role));
      if (id == null) continue;
      ids[role] = id;
      final name = prefs.getString(nameKey(role));
      if (name != null) names[role] = name;
    }
    state = StoredAiChoice(ids: ids, names: names);
  }

  Future<void> set(AiRole role, OfferedAi ai) async {
    _setByLearner = true;
    state = StoredAiChoice(
      ids: {...state.ids, role: ai.id},
      names: {...state.names, role: ai.name},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(idKey(role), ai.id);
    await prefs.setString(nameKey(role), ai.name);
  }
}

@Riverpod(keepAlive: true)
SessionPublishService sessionPublishService(Ref ref) => SessionPublishService();

/// Word picking from a subtitle file's lines, via the Worker (words-from-subtitles).
@Riverpod(keepAlive: true)
SubtitleWordsService subtitleWordsService(Ref ref) => SubtitleWordsService();

/// Subtitle files found by film name, through the Worker (OpenSubtitles).
@Riverpod(keepAlive: true)
SubtitleSearchService subtitleSearchService(Ref ref) => SubtitleSearchService();

/// Subtitle words translated on the phone with Google Translate.
@Riverpod(keepAlive: true)
SubtitleGoogleWords subtitleGoogleWords(Ref ref) => SubtitleGoogleWords(ref.watch(googleTranslateServiceProvider));

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

/// Adds an import's rows and dialogues, and scene pictures, to a published
/// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
/// uses it is `dialoguePushProvider`.
@Riverpod(keepAlive: true)
DialoguePushService dialoguePushService(Ref ref) => DialoguePushService();

/// Short name used across the app and the design docs.
final dialoguesSettingProvider = dialoguesSettingNotifierProvider;

/// The "Get dialogues from subtitles" switch in Settings
/// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
/// also asks for film dialogues. Persisted like the word detail mode; off
/// until the stored value is read ([loaded]).
@Riverpod(keepAlive: true)
class DialoguesSettingNotifier extends _$DialoguesSettingNotifier {
  static const prefsKey = 'subtitle_dialogues';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  bool build() {
    loaded;
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(prefsKey);
    // A choice made before the stored value arrived wins over it.
    if (_setByLearner) return;
    state = stored ?? false;
  }

  Future<void> set(bool on) async {
    _setByLearner = true;
    state = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, on);
  }
}

/// Short name used across the app and the design docs.
final subtitleImportPrefsProvider = subtitleImportPrefsNotifierProvider;

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of level and maximum, the "Update with
/// each import" switch, the translator and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.
@Riverpod(keepAlive: true)
class SubtitleImportPrefsNotifier extends _$SubtitleImportPrefsNotifier {
  static const levelKey = 'subtitle_level';
  static const maximumKey = 'subtitle_maximum';
  static const updateEachImportKey = 'subtitle_update_each_import';
  static const modelKey = 'subtitle_model';
  static const translatorKey = 'subtitle_translator';
  static const opencodeModelKey = 'subtitle_opencode_model';
  static const boostCloseRepeatsKey = 'subtitle_boost_close_repeats';
  static const removeNamesKey = 'subtitle_remove_names';

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
    final level = prefs.getString(levelKey);
    final maximum = prefs.getInt(maximumKey);
    final model = prefs.getString(modelKey);
    final translator = prefs.getString(translatorKey);
    final opencodeModel = prefs.getString(opencodeModelKey);
    state = SubtitleImportPrefs(
      level: EnglishLevel.values.where((l) => l.wire == level).firstOrNull ?? d.level,
      maximum: maximum != null && SubtitleImportPrefs.isValidMaximum(maximum) ? maximum : d.maximum,
      updateEachImport: prefs.getBool(updateEachImportKey) ?? d.updateEachImport,
      model: SubtitleModel.values.where((m) => m.name == model && !m.opencode).firstOrNull ?? d.model,
      opencodeModel: SubtitleModel.values.where((m) => m.name == opencodeModel && m.opencode).firstOrNull ?? d.opencodeModel,
      boostCloseRepeats: prefs.getBool(boostCloseRepeatsKey) ?? d.boostCloseRepeats,
      removeNames: prefs.getBool(removeNamesKey) ?? d.removeNames,
      translator: SubtitleTranslator.values.where((t) => t.name == translator).firstOrNull ?? d.translator,
    );
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

  Future<void> setBoostCloseRepeats(bool on) async {
    _update(state.copyWith(boostCloseRepeats: on));
    await (await SharedPreferences.getInstance()).setBool(boostCloseRepeatsKey, on);
  }

  Future<void> setRemoveNames(bool on) async {
    _update(state.copyWith(removeNames: on));
    await (await SharedPreferences.getInstance()).setBool(removeNamesKey, on);
  }

  Future<void> setOpencodeModel(SubtitleModel model) async {
    _update(state.copyWith(opencodeModel: model));
    await (await SharedPreferences.getInstance()).setString(opencodeModelKey, model.name);
  }

  Future<void> setTranslator(SubtitleTranslator translator) async {
    _update(state.copyWith(translator: translator));
    await (await SharedPreferences.getInstance()).setString(translatorKey, translator.name);
  }

  /// Called at Start (F3): with "Update with each import" on, the values used
  /// become the Settings values; with it off, nothing changes (AC-05, AC-05b).
  Future<void> recordUsed({
    required EnglishLevel level,
    required int maximum,
  }) async {
    if (!state.updateEachImport) return;
    await setLevel(level);
    await setMaximum(maximum);
  }

  void _update(SubtitleImportPrefs next) {
    _setByLearner = true;
    state = next;
  }
}

/// Short name used across the app and the design docs.
final photoTabTopProvider = photoTabTopNotifierProvider;

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `Session`. Clamped on use by the tab ([clamp]).
@Riverpod(keepAlive: true)
class PhotoTabTopNotifier extends _$PhotoTabTopNotifier {
  static const prefsKey = 'photo_tab_top';

  /// Beside the first word rows (spec AC-01).
  static const firstDefault = 40.0;

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  double build() {
    loaded;
    return firstDefault;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(prefsKey);
    // A drag made before the stored value arrived wins over it.
    if (_setByLearner || stored == null) return;
    state = stored;
  }

  /// A failed write keeps the in-memory value (sad §8 "Error handling").
  Future<void> set(double top) async {
    _setByLearner = true;
    state = top;
    try {
      await (await SharedPreferences.getInstance()).setDouble(prefsKey, top);
    } catch (e) {
      debugPrint('VOCAB: photo panel: tab height not saved: $e');
    }
  }

  /// Keeps the tab between the top bar ([min]) and the floating-button row
  /// ([max]); when the screen is too short for both, the top bar wins.
  static double clamp(double top, {required double min, required double max}) =>
      max < min ? min : top.clamp(min, max);
}

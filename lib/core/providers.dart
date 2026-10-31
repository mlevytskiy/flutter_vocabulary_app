import 'dialogues/dialogue_push.dart' show DialoguePushService;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import '../features/learn/entry/learn_presets.dart';
import 'models/offered_ai.dart';
import 'theme/app_theme.dart' show AppThemeId;
import 'models/collection_folder.dart';
import 'models/tag_library_entry.dart';
import 'models/name_kind.dart';
import 'models/word_collection.dart';
import 'models/subtitle_import_options.dart';
import 'services/dictionary_service.dart';
import 'services/exam_result_sink.dart';
import 'services/google_translate_service.dart';
import 'services/learn_api_service.dart';
import 'services/new_user_trial.dart';
import 'services/photo_scaler.dart';
import 'services/photo_upload_service.dart';
import 'services/openai_voice_service.dart';
import 'services/pronunciation_service.dart';
import 'services/talk_picture_service.dart';
import 'services/voice_player.dart';
import 'services/collection_publish_service.dart';
import 'services/collection_level.dart';
import 'services/collection_naming_service.dart';
import 'services/learn_topics_service.dart';
import 'services/learn_events_service.dart';
import 'services/warm_up_reaction_service.dart';
import 'services/collection_search.dart' show CollectionSummary;
import 'services/collection_search_scope.dart' show QuickTag;
import 'services/tag_rules.dart' show tagKey;
import 'models/tag_kind.dart';
import 'services/collection_store.dart';
import 'services/source_photo_store.dart';
import 'services/speech_input.dart';
import 'services/story_api_service.dart';
import 'services/story_picture_store.dart';
import 'services/story_run_store.dart';
import 'services/subtitle_google_words.dart';
import 'services/talk_api_service.dart';
import 'services/subtitle_search_service.dart';
import 'services/subtitle_words_service.dart';
import 'services/system_gesture_exclusion.dart';
import 'services/vocab_photo_service.dart';
import 'words/context_backfill.dart';

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
Future<CollectionStore> collectionStore(Ref ref) => CollectionStore.open();

/// Puts the user's data aside to show the app as to a new user, and brings
/// it back (new-user-trial, owner 2026-10-17).
@Riverpod(keepAlive: true)
NewUserTrial newUserTrial(Ref ref) => NewUserTrial();

/// When the new-user trial's backup was made; null while no trial is on.
@riverpod
Future<DateTime?> newUserBackup(Ref ref) =>
    ref.watch(newUserTrialProvider).backupTakenAt();

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
  await ref.watch(collectionStoreProvider.future); // opens the shared database
  return StoryRunStore.open();
}

/// The compressed story pictures kept on the phone.
@Riverpod(keepAlive: true)
StoryPictureStore storyPictureStore(Ref ref) => StoryPictureStore();

@Riverpod(keepAlive: true)
GoogleTranslateService googleTranslateService(Ref ref) =>
    GoogleTranslateService();

/// Text to speech. Talk with AI's lines go to OpenAI's voice or the phone's
/// as Learn settings say (openai-voice, AC-31), read when each line starts.
@Riverpod(keepAlive: true)
PronunciationService pronunciationService(Ref ref) => PronunciationService(
      openAi: ref.read(openAiVoiceServiceProvider),
      player: AudioplayersVoicePlayer(),
      voiceChoice: () async {
        await ref.read(voiceSourceProvider.notifier).loaded;
        await ref.read(openAiVoiceProvider.notifier).loaded;
        return (source: ref.read(voiceSourceProvider), openAiVoice: ref.read(openAiVoiceProvider));
      },
    );

/// The Worker's speech route for Talk with AI's OpenAI voice (openai-voice,
/// AC-31).
@Riverpod(keepAlive: true)
OpenAiVoiceService openAiVoiceService(Ref ref) => OpenAiVoiceService();

/// Dictionary senses for the definition field, via the Worker (ADR-0002).
@Riverpod(keepAlive: true)
DictionaryService dictionaryService(Ref ref) => DictionaryService();

/// The launch backfill of empty contexts (word-context AC-12, ADR-0004),
/// started once by the words notifier after the collection autofill.
@Riverpod(keepAlive: true)
ContextBackfill contextBackfill(Ref ref) {
  final backfill = ContextBackfill(
    store: () => ref.read(collectionStoreProvider.future),
    dictionary: ref.read(dictionaryServiceProvider),
  );
  ref.onDispose(backfill.cancel);
  return backfill;
}

/// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).
@Riverpod(keepAlive: true)
StoryApiService storyApiService(Ref ref) => StoryApiService();

/// The Worker's collection naming (collection-naming, owner 2026-10-18).
@Riverpod(keepAlive: true)
CollectionNamingService collectionNamingService(Ref ref) =>
    CollectionNamingService();

/// The Worker's Talk topics (learn-welcome AC-03), bundled three on failure.
@Riverpod(keepAlive: true)
LearnTopicsService learnTopicsService(Ref ref) => LearnTopicsService();

/// The free warm-up reaction (learn-warm-up-v2 AC-05), fixed line on failure.
@Riverpod(keepAlive: true)
WarmUpReactionService warmUpReactionService(Ref ref) =>
    WarmUpReactionService();

/// The fire-and-forget warm-up and talk counts (learn-warm-up-v2 AC-17).
@Riverpod(keepAlive: true)
LearnEventsService learnEventsService(Ref ref) => LearnEventsService();

/// The Worker's exercise services: data and sentence checks (learn-kit S-13).
@Riverpod(keepAlive: true)
LearnApiService learnApiService(Ref ref) => LearnApiService();

/// The Worker's talk turns for Talk with AI (learn-redesign ADR-0007).
@Riverpod(keepAlive: true)
TalkApiService talkApiService(Ref ref) => TalkApiService();

/// The Worker's opening picture of a Talk mission (talk-mission).
@Riverpod(keepAlive: true)
TalkPictureService talkPictureService(Ref ref) => TalkPictureService();

/// Where Step 3 exams record each word's known / repeat result (learn-kit
/// S-23), on the session in the session store.
@Riverpod(keepAlive: true)
ExamResultSink examResultSink(Ref ref) =>
    StoreExamResultSink(() => ref.read(collectionStoreProvider.future));

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
CollectionPublishService collectionPublishService(Ref ref) => CollectionPublishService();

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
Future<WordCollection?> collectionById(Ref ref, String collectionId) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.byId(collectionId);
}

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.
@riverpod
Stream<List<LevelItem>> collectionLevel(Ref ref, String? folderId) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchLevel(folderId);
}

/// Every collection that is not in the bin, empty ones too, for the
/// Collections search and the tag counts (collection-tags ADR-0006); one
/// emission per burst of writes.
@riverpod
Stream<List<CollectionSummary>> collectionSummaries(Ref ref) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchSummaries();
}

/// The whole tag library, forgotten entries included (collection-tags
/// ADR-0009).
@riverpod
Stream<List<TagLibraryEntry>> tagLibrary(Ref ref) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchLibrary();
}

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.
@riverpod
Stream<String?> collectionName(Ref ref, String collectionId) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchName(collectionId);
}

/// The stored name of collection [collectionId] with its [NameKind], for the
/// main screen's title (collection-naming).
@riverpod
Stream<({String? name, NameKind kind})?> collectionNaming(
    Ref ref, String collectionId) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchNaming(collectionId);
}

/// Every folder, binned ones too, for the Collections path and the tree.
@riverpod
Stream<List<CollectionFolder>> collectionFolders(Ref ref) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* store.watchFolders();
}

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `WordCollection` because it is not
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

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
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

/// What the Learn entry remembers (learn-redesign T6, ADR-0006, AC-05/17).
class LearnSettings {
  const LearnSettings({
    required this.preset,
    required this.enabled,
    required this.wordsPerSession,
  });

  final LearnPreset preset;
  final Set<String> enabled;
  final WordsPerSession wordsPerSession;

  LearnSettings copyWith({
    LearnPreset? preset,
    Set<String>? enabled,
    WordsPerSession? wordsPerSession,
  }) =>
      LearnSettings(
        preset: preset ?? this.preset,
        enabled: enabled ?? this.enabled,
        wordsPerSession: wordsPerSession ?? this.wordsPerSession,
      );
}

/// The learn preset, enabled exercises and words per session; persisted like
/// [WordDetailModeNotifier]. Starts as Balanced / its set / all words and
/// switches once the stored values are read ([loaded]).
@Riverpod(keepAlive: true)
class LearnSettingsNotifier extends _$LearnSettingsNotifier {
  static const presetKey = 'learn.preset';
  static const enabledKey = 'learn.enabled';
  static const wordsPerSessionKey = 'learn.wordsPerSession';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  LearnSettings build() {
    loaded;
    return LearnSettings(
      preset: LearnPreset.balanced,
      enabled: presetExercises(LearnPreset.balanced),
      wordsPerSession: WordsPerSession.all,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // A choice made before the stored values arrived wins over them.
    if (_setByLearner) return;
    final storedEnabled = prefs.getStringList(enabledKey);
    final enabled = storedEnabled == null
        ? state.enabled
        : storedEnabled.where(pageExerciseIds.contains).toSet();
    final storedPreset = prefs.getString(presetKey);
    final preset = LearnPreset.values.firstWhere(
      (p) => p.name == storedPreset,
      orElse: () => presetFor(enabled),
    );
    state = LearnSettings(
      preset: preset,
      enabled: enabled,
      wordsPerSession: WordsPerSession.values.firstWhere(
        (w) => w.name == prefs.getString(wordsPerSessionKey),
        orElse: () => WordsPerSession.all,
      ),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(presetKey, state.preset.name);
    await prefs.setStringList(enabledKey, state.enabled.toList()..sort());
    await prefs.setString(wordsPerSessionKey, state.wordsPerSession.name);
  }

  Future<void> pickPreset(LearnPreset preset) async {
    _setByLearner = true;
    state = state.copyWith(
      preset: preset,
      // Custom keeps the current mix; the others bring their own.
      enabled: preset == LearnPreset.custom
          ? state.enabled
          : presetExercises(preset),
    );
    await _save();
  }

  /// Turns [id] on or off. Refuses (false) to turn off the last enabled
  /// exercise of its step; any change sets the preset to the matching one.
  Future<bool> setEnabled(String id, bool on) async {
    if (!pageExerciseIds.contains(id)) return false;
    if (!on && !canTurnOff(state.enabled, id)) return false;
    _setByLearner = true;
    final enabled = {...state.enabled};
    on ? enabled.add(id) : enabled.remove(id);
    state = state.copyWith(enabled: enabled, preset: presetFor(enabled));
    await _save();
    return true;
  }

  Future<void> setWordsPerSession(WordsPerSession value) async {
    _setByLearner = true;
    state = state.copyWith(wordsPerSession: value);
    await _save();
  }
}

/// Index of the session group a collection's learner played last, if any.
@Riverpod(keepAlive: true)
class LearnLastGroupNotifier extends _$LearnLastGroupNotifier {
  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  String get _key => 'learn.lastGroup.$collectionId';

  @override
  int? build(String collectionId) {
    loaded;
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    state = prefs.getInt(_key);
  }

  Future<void> set(int index) async {
    _setByLearner = true;
    state = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }
}

/// The speech recognition engine for Talk with AI's hold-to-talk, picked in
/// Learn settings (learn-redesign AC-28, ADR-0009 Amendment); persisted like
/// [LearnSettingsNotifier]. Starts as [SpeechEngine.speechToText].
@Riverpod(keepAlive: true)
class SpeechEngineNotifier extends _$SpeechEngineNotifier {
  static const key = 'learn.speechEngine';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  SpeechEngine build() {
    loaded;
    return SpeechEngine.speechToText;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    final stored = prefs.getString(key);
    // Apple's engine only where it is offered (iOS).
    state = SpeechEngine.offered.firstWhere((e) => e.name == stored,
        orElse: () => SpeechEngine.speechToText);
  }

  Future<void> set(SpeechEngine engine) async {
    _setByLearner = true;
    state = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, engine.name);
  }
}

/// The hold-to-talk input of the engine picked in Learn settings (AC-25,
/// AC-28, ADR-0009); overridden with a fake in tests.
@Riverpod(keepAlive: true)
SpeechInput speechInput(Ref ref) =>
    switch (ref.watch(speechEngineProvider)) {
      SpeechEngine.speechToText => SpeechToTextInput(onDevice: ref.watch(speechOnDeviceProvider)),
      SpeechEngine.speechToTextPro => SpeechToTextProInput(),
      SpeechEngine.appleSpeechAnalyzer => AppleSpeechAnalyzerInput(),
    };

/// Whether speech_to_text must recognise on the phone only (owner,
/// 2026-10-24: show and pick the recognition mode on the Talk screen). Off
/// by default: the phone's recognizer may use Apple's or Google's servers
/// when online, usually more accurate. speech_to_text_pro has no such mode.
@Riverpod(keepAlive: true)
class SpeechOnDeviceNotifier extends _$SpeechOnDeviceNotifier {
  static const key = 'learn.speechOnDevice';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  bool build() {
    loaded;
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    state = prefs.getBool(key) ?? false;
  }

  Future<void> set(bool onDevice) async {
    _setByLearner = true;
    state = onDevice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, onDevice);
  }
}

/// Whether Talk with AI is hands-free (learn-redesign AC-29, owner
/// 2026-10-24): it listens at once, a pause sends, the AI's reply is spoken
/// and then it listens again. On by default; the Talk bar's headset and
/// Learn settings switch it.
@Riverpod(keepAlive: true)
class HandsFreeNotifier extends _$HandsFreeNotifier {
  static const key = 'learn.handsFree';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  bool build() {
    loaded;
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    state = prefs.getBool(key) ?? true;
  }

  Future<void> set(bool on) async {
    _setByLearner = true;
    state = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, on);
  }
}

/// The seconds of silence that send a hands-free reply (AC-29).
const talkPauseChoices = [2, 3, 4, 6, 8, 10, 15];

/// The hands-free pause in seconds, one of [talkPauseChoices]; 10 by default
/// (owner, 2026-10-24: 4 s sent replies too soon).
@Riverpod(keepAlive: true)
class TalkPauseNotifier extends _$TalkPauseNotifier {
  static const key = 'learn.pauseSeconds';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  int build() {
    loaded;
    return 10;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    final stored = prefs.getInt(key);
    if (stored != null && talkPauseChoices.contains(stored)) state = stored;
  }

  Future<void> set(int seconds) async {
    if (!talkPauseChoices.contains(seconds)) return;
    _setByLearner = true;
    state = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, seconds);
  }
}

/// The voice Talk with AI speaks with, picked in Learn settings (AC-30);
/// null for the best installed voice.
@Riverpod(keepAlive: true)
class TtsVoiceNotifier extends _$TtsVoiceNotifier {
  static const key = 'learn.ttsVoice';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  VoiceId? build() {
    loaded;
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    final stored = prefs.getString(key);
    if (stored == null) return;
    try {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      state = (name: map['name'] as String, locale: map['locale'] as String);
    } catch (_) {
      // A broken value: the best voice.
    }
  }

  Future<void> set(VoiceId voice) async {
    _setByLearner = true;
    state = voice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode({'name': voice.name, 'locale': voice.locale}));
  }
}

/// Who speaks Talk with AI's lines, picked in Learn settings (openai-voice,
/// owner 2026-10-24; AC-31): OpenAI's natural voice by default.
@Riverpod(keepAlive: true)
class VoiceSourceNotifier extends _$VoiceSourceNotifier {
  static const key = 'learn.voiceSource';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  VoiceSource build() {
    loaded;
    return VoiceSource.openAi;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    final stored = prefs.getString(key);
    state = VoiceSource.values.firstWhere((s) => s.name == stored, orElse: () => VoiceSource.openAi);
  }

  Future<void> set(VoiceSource source) async {
    _setByLearner = true;
    state = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, source.name);
  }
}

/// The OpenAI voice Talk with AI speaks with, one of [openAiVoices]; coral
/// by default (AC-31).
@Riverpod(keepAlive: true)
class OpenAiVoiceNotifier extends _$OpenAiVoiceNotifier {
  static const key = 'learn.openAiVoice';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  String build() {
    loaded;
    return defaultOpenAiVoice;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_setByLearner) return;
    final stored = prefs.getString(key);
    if (stored != null && openAiVoices.contains(stored)) state = stored;
  }

  Future<void> set(String voice) async {
    if (!openAiVoices.contains(voice)) return;
    _setByLearner = true;
    state = voice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, voice);
  }
}

/// The installed English voices, best first, for the AI voice picker (AC-30).
@riverpod
Future<List<TtsVoice>> englishVoices(Ref ref) =>
    ref.watch(pronunciationServiceProvider).englishVoices();

/// The app's theme, picked on the App settings page (app-themes, owner
/// 2026-10-17); persisted like [WordDetailModeNotifier]. Starts as
/// [AppThemeId.classic] and switches once the stored value is read.
@Riverpod(keepAlive: true)
class AppThemeNotifier extends _$AppThemeNotifier {
  static const prefsKey = 'app_theme';

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  AppThemeId build() {
    loaded;
    return AppThemeId.classic;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    // A choice made before the stored value arrived wins over it.
    if (_setByLearner) return;
    state = AppThemeId.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => AppThemeId.classic,
    );
  }

  Future<void> set(AppThemeId id) async {
    _setByLearner = true;
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, id.name);
  }
}

/// Adds an import's rows and dialogues, and scene pictures, to a published
/// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
/// uses it is `dialoguePushProvider`.
@Riverpod(keepAlive: true)
DialoguePushService dialoguePushService(Ref ref) => DialoguePushService();

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

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).
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

/// How strong the photo panel's liquid glass is, as fractions of the
/// looks' own values (1 = 100% = as designed): [thickness] widens the band
/// along the edge that bends, [bending] scales how far it bends (the
/// refractive index above 1), [blur] scales the blur (liquid-glass-tuning,
/// owner 2026-10-19).
typedef LiquidGlassTuning = ({double thickness, double bending, double blur});

/// The Words settings' Liquid glass sliders (liquid-glass-tuning, owner
/// 2026-10-19), for the photo tab and the half-open panel. Persisted like
/// [WordDetailModeNotifier], one preferences key per slider; a display
/// preference, never on `WordCollection`. Starts at 100% and switches once
/// the stored values are read ([loaded]).
@Riverpod(keepAlive: true)
class LiquidGlassTuningNotifier extends _$LiquidGlassTuningNotifier {
  static const thicknessKey = 'liquid_glass_thickness';
  static const bendingKey = 'liquid_glass_bending';
  static const blurKey = 'liquid_glass_blur';

  static const LiquidGlassTuning asDesigned =
      (thickness: 1.0, bending: 1.0, blur: 1.0);

  /// The sliders' ranges, as fractions.
  static const thicknessRange = (min: 0.5, max: 3.0);
  static const bendingRange = (min: 0.0, max: 3.0);
  static const blurRange = (min: 0.0, max: 2.0);

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  LiquidGlassTuning build() {
    loaded;
    return asDesigned;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // A change made before the stored values arrived wins over them.
    if (_setByLearner) return;
    state = _clamped((
      thickness: prefs.getDouble(thicknessKey) ?? 1.0,
      bending: prefs.getDouble(bendingKey) ?? 1.0,
      blur: prefs.getDouble(blurKey) ?? 1.0,
    ));
  }

  static LiquidGlassTuning _clamped(LiquidGlassTuning t) => (
        thickness: t.thickness.clamp(thicknessRange.min, thicknessRange.max),
        bending: t.bending.clamp(bendingRange.min, bendingRange.max),
        blur: t.blur.clamp(blurRange.min, blurRange.max),
      );

  /// A failed write keeps the in-memory values.
  Future<void> set(LiquidGlassTuning tuning) async {
    _setByLearner = true;
    state = _clamped(tuning);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(thicknessKey, state.thickness);
      await prefs.setDouble(bendingKey, state.bending);
      await prefs.setDouble(blurKey, state.blur);
    } catch (e) {
      debugPrint('VOCAB: liquid glass tuning not saved: $e');
    }
  }

  Future<void> reset() => set(asDesigned);
}

/// The tags the learner applied from the Collections filter sheet, newest
/// first, at most [keep] (filter-sheet-pills, owner 2026-10-18). Persisted
/// like [WordDetailModeNotifier] under one preferences key, each entry
/// `kind|text`; they feed the sheet's Popular line ([quickTags]).
@Riverpod(keepAlive: true)
class RecentFilterTagsNotifier extends _$RecentFilterTagsNotifier {
  static const prefsKey = 'collections_recent_filter_tags';
  static const keep = 10;

  late final Future<void> loaded = _load();
  bool _setByLearner = false;

  @override
  List<QuickTag> build() {
    loaded;
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(prefsKey) ?? const <String>[];
    if (_setByLearner) return;
    state = [
      for (final s in stored)
        if (_decode(s) case final QuickTag tag) tag,
    ];
  }

  static QuickTag? _decode(String s) {
    final i = s.indexOf('|');
    if (i < 0) return null;
    final kind = TagKind.values.where((k) => k.name == s.substring(0, i));
    if (kind.isEmpty) return null;
    return (kind: kind.first, text: s.substring(i + 1));
  }

  /// Moves [tags] to the front, the first of them first.
  Future<void> record(List<QuickTag> tags) async {
    if (tags.isEmpty) return;
    _setByLearner = true;
    String id(QuickTag t) => '${t.kind.name}|${tagKey(t.text)}';
    final ids = {for (final t in tags) id(t)};
    state = [
      ...tags,
      for (final t in state)
        if (!ids.contains(id(t))) t,
    ].take(keep).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(
          prefsKey, [for (final t in state) '${t.kind.name}|${t.text}']);
    } catch (e) {
      debugPrint('VOCAB: filter sheet: recent tags not saved: $e');
    }
  }
}

/// No automatic retry of a failed provider (Riverpod 3's default retries with
/// a growing pause); failures show at once, as before the toolchain upgrade.
Duration? noProviderRetry(int retryCount, Object error) => null;

/// Riverpod 2's notify rule for an AsyncNotifier, kept by every AsyncNotifier
/// here: a new state always notifies, except while loading stays loading.
/// Riverpod 3 compares with `==`, which would hide an update that stores the
/// same (changed in place) object again (toolchain-upgrade).
bool asyncNotifyAsBefore(AsyncValue<Object?> previous, AsyncValue<Object?> next) {
  final wasLoading = previous.isLoading;
  final isLoading = next.isLoading;
  if (wasLoading || isLoading) return wasLoading != isLoading;
  return true;
}

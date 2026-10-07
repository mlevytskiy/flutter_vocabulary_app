// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$vocabPhotoServiceHash() => r'380ca452d4e4be41e35c3b9266cfb041bceaa536';

/// See also [vocabPhotoService].
@ProviderFor(vocabPhotoService)
final vocabPhotoServiceProvider = Provider<VocabPhotoService>.internal(
  vocabPhotoService,
  name: r'vocabPhotoServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vocabPhotoServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VocabPhotoServiceRef = ProviderRef<VocabPhotoService>;
String _$photoScalerHash() => r'af179c8f6325da4a20a8c72b488e27151515346a';

/// See also [photoScaler].
@ProviderFor(photoScaler)
final photoScalerProvider = Provider<PhotoScaler>.internal(
  photoScaler,
  name: r'photoScalerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$photoScalerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PhotoScalerRef = ProviderRef<PhotoScaler>;
String _$imagePickerHash() => r'7740c09b2d6b395ce466f1b72b93b31db7bfd740';

/// Camera and gallery picks for the photo chain (photo-from-gallery T2);
/// a provider so widget tests can swap in a fake picker.
///
/// Copied from [imagePicker].
@ProviderFor(imagePicker)
final imagePickerProvider = AutoDisposeProvider<ImagePicker>.internal(
  imagePicker,
  name: r'imagePickerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$imagePickerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImagePickerRef = AutoDisposeProviderRef<ImagePicker>;
String _$sessionStoreHash() => r'80c414f1ec22b592d6f68442e3112d05972f08a4';

/// See also [sessionStore].
@ProviderFor(sessionStore)
final sessionStoreProvider = FutureProvider<SessionStore>.internal(
  sessionStore,
  name: r'sessionStoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$sessionStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SessionStoreRef = FutureProviderRef<SessionStore>;
String _$sourcePhotoStoreHash() => r'5ba15f72c22a820489d043a9260d86a9f9d91b3d';

/// The kept 1600 px copies of the session photos (good-looking-web T17).
///
/// Copied from [sourcePhotoStore].
@ProviderFor(sourcePhotoStore)
final sourcePhotoStoreProvider = Provider<SourcePhotoStore>.internal(
  sourcePhotoStore,
  name: r'sourcePhotoStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sourcePhotoStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SourcePhotoStoreRef = ProviderRef<SourcePhotoStore>;
String _$googleTranslateServiceHash() =>
    r'6afdf9f3d52ebdc231e65e17d05446c50f457432';

/// See also [googleTranslateService].
@ProviderFor(googleTranslateService)
final googleTranslateServiceProvider =
    Provider<GoogleTranslateService>.internal(
  googleTranslateService,
  name: r'googleTranslateServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$googleTranslateServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GoogleTranslateServiceRef = ProviderRef<GoogleTranslateService>;
String _$pronunciationServiceHash() =>
    r'a04b5b4ea06bd7d29a7b0874172549524472bb26';

/// See also [pronunciationService].
@ProviderFor(pronunciationService)
final pronunciationServiceProvider = Provider<PronunciationService>.internal(
  pronunciationService,
  name: r'pronunciationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pronunciationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PronunciationServiceRef = ProviderRef<PronunciationService>;
String _$dictionaryServiceHash() => r'55c5a3e42d3dab60fb9f17e0724c51e347330b20';

/// Dictionary senses for the definition field, via the Worker (ADR-0002).
///
/// Copied from [dictionaryService].
@ProviderFor(dictionaryService)
final dictionaryServiceProvider = Provider<DictionaryService>.internal(
  dictionaryService,
  name: r'dictionaryServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dictionaryServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictionaryServiceRef = ProviderRef<DictionaryService>;
String _$storyApiServiceHash() => r'a236884d7c0ebee6e6e8e747202f0035a3f0f616';

/// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).
///
/// Copied from [storyApiService].
@ProviderFor(storyApiService)
final storyApiServiceProvider = Provider<StoryApiService>.internal(
  storyApiService,
  name: r'storyApiServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storyApiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StoryApiServiceRef = ProviderRef<StoryApiService>;
String _$offeredAisHash() => r'5a7c2096143ae6f5c0db6e33b3300caccad2a625';

/// The AIs on the Worker's offered list. Fetched on first use and cached in
/// preferences; when the fetch fails, the cached list is used, and when there is
/// none either, the built-in defaults (AC-13). Never throws.
///
/// Copied from [offeredAis].
@ProviderFor(offeredAis)
final offeredAisProvider = FutureProvider<OfferedAiList>.internal(
  offeredAis,
  name: r'offeredAisProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$offeredAisHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfferedAisRef = FutureProviderRef<OfferedAiList>;
String _$sessionPublishServiceHash() =>
    r'f1fa0f257c2278cdc3e762d3755c1f1baa8ecbfc';

/// See also [sessionPublishService].
@ProviderFor(sessionPublishService)
final sessionPublishServiceProvider = Provider<SessionPublishService>.internal(
  sessionPublishService,
  name: r'sessionPublishServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionPublishServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SessionPublishServiceRef = ProviderRef<SessionPublishService>;
String _$subtitleWordsServiceHash() =>
    r'56f13395451925ab40ca0224660f990ec0cd6ce7';

/// Word picking from a subtitle file's lines, via the Worker (words-from-subtitles).
///
/// Copied from [subtitleWordsService].
@ProviderFor(subtitleWordsService)
final subtitleWordsServiceProvider = Provider<SubtitleWordsService>.internal(
  subtitleWordsService,
  name: r'subtitleWordsServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subtitleWordsServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubtitleWordsServiceRef = ProviderRef<SubtitleWordsService>;
String _$photoUploadServiceHash() =>
    r'8c9008e9902f73f6fe215aff73ac7796edf87107';

/// Background upload of the photos a publish declared (good-looking-web T18).
/// keepAlive, so uploads outlive the words table (sad §8).
///
/// Copied from [photoUploadService].
@ProviderFor(photoUploadService)
final photoUploadServiceProvider = Provider<PhotoUploadService>.internal(
  photoUploadService,
  name: r'photoUploadServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$photoUploadServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PhotoUploadServiceRef = ProviderRef<PhotoUploadService>;
String _$sessionByIdHash() => r'5a9ababfd50081224b9aaab6a0e5d20842921e11';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [sessionById].
@ProviderFor(sessionById)
const sessionByIdProvider = SessionByIdFamily();

/// See also [sessionById].
class SessionByIdFamily extends Family<AsyncValue<Session?>> {
  /// See also [sessionById].
  const SessionByIdFamily();

  /// See also [sessionById].
  SessionByIdProvider call(
    String sessionId,
  ) {
    return SessionByIdProvider(
      sessionId,
    );
  }

  @override
  SessionByIdProvider getProviderOverride(
    covariant SessionByIdProvider provider,
  ) {
    return call(
      provider.sessionId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionByIdProvider';
}

/// See also [sessionById].
class SessionByIdProvider extends AutoDisposeFutureProvider<Session?> {
  /// See also [sessionById].
  SessionByIdProvider(
    String sessionId,
  ) : this._internal(
          (ref) => sessionById(
            ref as SessionByIdRef,
            sessionId,
          ),
          from: sessionByIdProvider,
          name: r'sessionByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sessionByIdHash,
          dependencies: SessionByIdFamily._dependencies,
          allTransitiveDependencies:
              SessionByIdFamily._allTransitiveDependencies,
          sessionId: sessionId,
        );

  SessionByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  Override overrideWith(
    FutureOr<Session?> Function(SessionByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SessionByIdProvider._internal(
        (ref) => create(ref as SessionByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Session?> createElement() {
    return _SessionByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionByIdProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionByIdRef on AutoDisposeFutureProviderRef<Session?> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _SessionByIdProviderElement
    extends AutoDisposeFutureProviderElement<Session?> with SessionByIdRef {
  _SessionByIdProviderElement(super.provider);

  @override
  String get sessionId => (origin as SessionByIdProvider).sessionId;
}

String _$nonEmptySessionsHash() => r'5eed4773be16d0e53b15997c820df92de8d570d1';

/// Every session that has at least one non-blank word, newest first, re-emitted
/// after every write. The drawer rule on the input screen and the History
/// screen (task-10) both read this one stream.
///
/// Copied from [nonEmptySessions].
@ProviderFor(nonEmptySessions)
final nonEmptySessionsProvider =
    AutoDisposeStreamProvider<List<Session>>.internal(
  nonEmptySessions,
  name: r'nonEmptySessionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nonEmptySessionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NonEmptySessionsRef = AutoDisposeStreamProviderRef<List<Session>>;
String _$aiChoiceNotifierHash() => r'56fb292859c4632c546aa2450c049a959ad528bc';

/// The learner's saved AI for each step of a story run (AC-12). Persisted like
/// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
/// before showing or using it, so a withdrawn AI falls back to the default (AC-13).
///
/// Copied from [AiChoiceNotifier].
@ProviderFor(AiChoiceNotifier)
final aiChoiceNotifierProvider =
    NotifierProvider<AiChoiceNotifier, StoredAiChoice>.internal(
  AiChoiceNotifier.new,
  name: r'aiChoiceNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$aiChoiceNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AiChoiceNotifier = Notifier<StoredAiChoice>;
String _$dragModeHash() => r'6c8be31e69381c41da06163dfa7a77cfa9c1bb89';

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `Session` because it is not
/// session data and must never reach Isar (task-13), and `keepAlive` because
/// the Settings screen is the only writer while the input screen is the only
/// reader -- autoDispose would drop the value when Settings is popped.
///
/// Copied from [DragMode].
@ProviderFor(DragMode)
final dragModeProvider = NotifierProvider<DragMode, bool>.internal(
  DragMode.new,
  name: r'dragModeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dragModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DragMode = Notifier<bool>;
String _$wordDetailModeNotifierHash() =>
    r'45973bab20f05a4640eaf6cb6cbd04bff4126d76';

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `Session`. Starts as [WordDetailMode.translation] and
/// switches once the stored value is read ([loaded]).
///
/// Copied from [WordDetailModeNotifier].
@ProviderFor(WordDetailModeNotifier)
final wordDetailModeNotifierProvider =
    NotifierProvider<WordDetailModeNotifier, WordDetailMode>.internal(
  WordDetailModeNotifier.new,
  name: r'wordDetailModeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wordDetailModeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WordDetailModeNotifier = Notifier<WordDetailMode>;
String _$subtitleImportPrefsNotifierHash() =>
    r'1c51c1bcfd4b6dd54478eb525338c3ba7fd99fc1';

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of purpose, level and maximum, the "Update with
/// each import" switch, and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.
///
/// Copied from [SubtitleImportPrefsNotifier].
@ProviderFor(SubtitleImportPrefsNotifier)
final subtitleImportPrefsNotifierProvider =
    NotifierProvider<SubtitleImportPrefsNotifier, SubtitleImportPrefs>.internal(
  SubtitleImportPrefsNotifier.new,
  name: r'subtitleImportPrefsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subtitleImportPrefsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SubtitleImportPrefsNotifier = Notifier<SubtitleImportPrefs>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

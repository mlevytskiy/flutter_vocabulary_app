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
String _$collectionStoreHash() => r'734e53cb3306b24784379060398a3d74e2bac7c5';

/// See also [collectionStore].
@ProviderFor(collectionStore)
final collectionStoreProvider = FutureProvider<CollectionStore>.internal(
  collectionStore,
  name: r'collectionStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CollectionStoreRef = FutureProviderRef<CollectionStore>;
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
String _$systemGestureExclusionHash() =>
    r'6e5cfd25b75fb8acad89848713fcd6222249a31f';

/// The Android Back-gesture exclusion for the photo tab
/// (side-bar-for-main-screen ADR-0002).
///
/// Copied from [systemGestureExclusion].
@ProviderFor(systemGestureExclusion)
final systemGestureExclusionProvider =
    Provider<SystemGestureExclusion>.internal(
  systemGestureExclusion,
  name: r'systemGestureExclusionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$systemGestureExclusionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SystemGestureExclusionRef = ProviderRef<SystemGestureExclusion>;
String _$storyRunStoreHash() => r'406c5b86ac090c61141ffc690cd2065301fb3140';

/// The story runs, kept in the same database as the sessions (ADR-0003).
///
/// Copied from [storyRunStore].
@ProviderFor(storyRunStore)
final storyRunStoreProvider = FutureProvider<StoryRunStore>.internal(
  storyRunStore,
  name: r'storyRunStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storyRunStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StoryRunStoreRef = FutureProviderRef<StoryRunStore>;
String _$storyPictureStoreHash() => r'625afbaf103c13e839e9def2035d1edb5251d58f';

/// The compressed story pictures kept on the phone.
///
/// Copied from [storyPictureStore].
@ProviderFor(storyPictureStore)
final storyPictureStoreProvider = Provider<StoryPictureStore>.internal(
  storyPictureStore,
  name: r'storyPictureStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storyPictureStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StoryPictureStoreRef = ProviderRef<StoryPictureStore>;
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
String _$learnApiServiceHash() => r'2da4556e695e318b873e02fe83b565960e790244';

/// The Worker's exercise services: data and sentence checks (learn-kit S-13).
///
/// Copied from [learnApiService].
@ProviderFor(learnApiService)
final learnApiServiceProvider = Provider<LearnApiService>.internal(
  learnApiService,
  name: r'learnApiServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$learnApiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LearnApiServiceRef = ProviderRef<LearnApiService>;
String _$examResultSinkHash() => r'48e41297d46cc66488d89b803bb61380316ddf96';

/// Where Step 3 exams record each word's known / repeat result (learn-kit
/// S-23), on the session in the session store.
///
/// Copied from [examResultSink].
@ProviderFor(examResultSink)
final examResultSinkProvider = Provider<ExamResultSink>.internal(
  examResultSink,
  name: r'examResultSinkProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$examResultSinkHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExamResultSinkRef = ProviderRef<ExamResultSink>;
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
String _$collectionPublishServiceHash() =>
    r'782c4e1830d4068a7ccce88ceaf477de7cc026d4';

/// See also [collectionPublishService].
@ProviderFor(collectionPublishService)
final collectionPublishServiceProvider =
    Provider<CollectionPublishService>.internal(
  collectionPublishService,
  name: r'collectionPublishServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionPublishServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CollectionPublishServiceRef = ProviderRef<CollectionPublishService>;
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
String _$subtitleSearchServiceHash() =>
    r'cc2abc44e30d06312b788e733574cf0709c3fcdd';

/// Subtitle files found by film name, through the Worker (OpenSubtitles).
///
/// Copied from [subtitleSearchService].
@ProviderFor(subtitleSearchService)
final subtitleSearchServiceProvider = Provider<SubtitleSearchService>.internal(
  subtitleSearchService,
  name: r'subtitleSearchServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subtitleSearchServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubtitleSearchServiceRef = ProviderRef<SubtitleSearchService>;
String _$subtitleGoogleWordsHash() =>
    r'fca5efe9d5a66d33861f0cc0b336f3b1a60f873b';

/// Subtitle words translated on the phone with Google Translate.
///
/// Copied from [subtitleGoogleWords].
@ProviderFor(subtitleGoogleWords)
final subtitleGoogleWordsProvider = Provider<SubtitleGoogleWords>.internal(
  subtitleGoogleWords,
  name: r'subtitleGoogleWordsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subtitleGoogleWordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubtitleGoogleWordsRef = ProviderRef<SubtitleGoogleWords>;
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
String _$collectionByIdHash() => r'ad2b3bf6ef382c136b9269914067acfeafcd7c90';

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

/// See also [collectionById].
@ProviderFor(collectionById)
const collectionByIdProvider = CollectionByIdFamily();

/// See also [collectionById].
class CollectionByIdFamily extends Family<AsyncValue<WordCollection?>> {
  /// See also [collectionById].
  const CollectionByIdFamily();

  /// See also [collectionById].
  CollectionByIdProvider call(
    String collectionId,
  ) {
    return CollectionByIdProvider(
      collectionId,
    );
  }

  @override
  CollectionByIdProvider getProviderOverride(
    covariant CollectionByIdProvider provider,
  ) {
    return call(
      provider.collectionId,
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
  String? get name => r'collectionByIdProvider';
}

/// See also [collectionById].
class CollectionByIdProvider
    extends AutoDisposeFutureProvider<WordCollection?> {
  /// See also [collectionById].
  CollectionByIdProvider(
    String collectionId,
  ) : this._internal(
          (ref) => collectionById(
            ref as CollectionByIdRef,
            collectionId,
          ),
          from: collectionByIdProvider,
          name: r'collectionByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$collectionByIdHash,
          dependencies: CollectionByIdFamily._dependencies,
          allTransitiveDependencies:
              CollectionByIdFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  CollectionByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
  }) : super.internal();

  final String collectionId;

  @override
  Override overrideWith(
    FutureOr<WordCollection?> Function(CollectionByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CollectionByIdProvider._internal(
        (ref) => create(ref as CollectionByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<WordCollection?> createElement() {
    return _CollectionByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionByIdProvider &&
        other.collectionId == collectionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CollectionByIdRef on AutoDisposeFutureProviderRef<WordCollection?> {
  /// The parameter `collectionId` of this provider.
  String get collectionId;
}

class _CollectionByIdProviderElement
    extends AutoDisposeFutureProviderElement<WordCollection?>
    with CollectionByIdRef {
  _CollectionByIdProviderElement(super.provider);

  @override
  String get collectionId => (origin as CollectionByIdProvider).collectionId;
}

String _$nonEmptyCollectionsHash() =>
    r'0736779d8ae8680bceb1731f22ddacf9be9bdec6';

/// History (collections-screen F11): every collection that has at least one
/// non-blank word and is not in the recycle bin, directly or through a folder
/// above it, newest first, re-emitted after every write. The drawer rule on
/// the input screen, the History screen and the tag suggestions read this.
///
/// Copied from [nonEmptyCollections].
@ProviderFor(nonEmptyCollections)
final nonEmptyCollectionsProvider =
    AutoDisposeStreamProvider<List<WordCollection>>.internal(
  nonEmptyCollections,
  name: r'nonEmptyCollectionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nonEmptyCollectionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NonEmptyCollectionsRef
    = AutoDisposeStreamProviderRef<List<WordCollection>>;
String _$collectionLevelHash() => r'35c09f3e0dc5b9ca13c5d35021e6ce1ef3d65d15';

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.
///
/// Copied from [collectionLevel].
@ProviderFor(collectionLevel)
const collectionLevelProvider = CollectionLevelFamily();

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.
///
/// Copied from [collectionLevel].
class CollectionLevelFamily extends Family<AsyncValue<List<LevelItem>>> {
  /// One level of the Collections screen (collections-screen T8): the folders
  /// and collections in [folderId], null being the top level, that are not in
  /// the bin, by order, re-emitted after every write.
  ///
  /// Copied from [collectionLevel].
  const CollectionLevelFamily();

  /// One level of the Collections screen (collections-screen T8): the folders
  /// and collections in [folderId], null being the top level, that are not in
  /// the bin, by order, re-emitted after every write.
  ///
  /// Copied from [collectionLevel].
  CollectionLevelProvider call(
    String? folderId,
  ) {
    return CollectionLevelProvider(
      folderId,
    );
  }

  @override
  CollectionLevelProvider getProviderOverride(
    covariant CollectionLevelProvider provider,
  ) {
    return call(
      provider.folderId,
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
  String? get name => r'collectionLevelProvider';
}

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.
///
/// Copied from [collectionLevel].
class CollectionLevelProvider
    extends AutoDisposeStreamProvider<List<LevelItem>> {
  /// One level of the Collections screen (collections-screen T8): the folders
  /// and collections in [folderId], null being the top level, that are not in
  /// the bin, by order, re-emitted after every write.
  ///
  /// Copied from [collectionLevel].
  CollectionLevelProvider(
    String? folderId,
  ) : this._internal(
          (ref) => collectionLevel(
            ref as CollectionLevelRef,
            folderId,
          ),
          from: collectionLevelProvider,
          name: r'collectionLevelProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$collectionLevelHash,
          dependencies: CollectionLevelFamily._dependencies,
          allTransitiveDependencies:
              CollectionLevelFamily._allTransitiveDependencies,
          folderId: folderId,
        );

  CollectionLevelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.folderId,
  }) : super.internal();

  final String? folderId;

  @override
  Override overrideWith(
    Stream<List<LevelItem>> Function(CollectionLevelRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CollectionLevelProvider._internal(
        (ref) => create(ref as CollectionLevelRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        folderId: folderId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<LevelItem>> createElement() {
    return _CollectionLevelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionLevelProvider && other.folderId == folderId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, folderId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CollectionLevelRef on AutoDisposeStreamProviderRef<List<LevelItem>> {
  /// The parameter `folderId` of this provider.
  String? get folderId;
}

class _CollectionLevelProviderElement
    extends AutoDisposeStreamProviderElement<List<LevelItem>>
    with CollectionLevelRef {
  _CollectionLevelProviderElement(super.provider);

  @override
  String? get folderId => (origin as CollectionLevelProvider).folderId;
}

String _$collectionNameHash() => r'8a07f2bd9b41c3855b426acf2b30592f9ccd9978';

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.
///
/// Copied from [collectionName].
@ProviderFor(collectionName)
const collectionNameProvider = CollectionNameFamily();

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.
///
/// Copied from [collectionName].
class CollectionNameFamily extends Family<AsyncValue<String?>> {
  /// The stored name of one collection (collections-screen T14): the main
  /// screen's title. Null before the backfill; callers show the date name.
  ///
  /// Copied from [collectionName].
  const CollectionNameFamily();

  /// The stored name of one collection (collections-screen T14): the main
  /// screen's title. Null before the backfill; callers show the date name.
  ///
  /// Copied from [collectionName].
  CollectionNameProvider call(
    String collectionId,
  ) {
    return CollectionNameProvider(
      collectionId,
    );
  }

  @override
  CollectionNameProvider getProviderOverride(
    covariant CollectionNameProvider provider,
  ) {
    return call(
      provider.collectionId,
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
  String? get name => r'collectionNameProvider';
}

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.
///
/// Copied from [collectionName].
class CollectionNameProvider extends AutoDisposeStreamProvider<String?> {
  /// The stored name of one collection (collections-screen T14): the main
  /// screen's title. Null before the backfill; callers show the date name.
  ///
  /// Copied from [collectionName].
  CollectionNameProvider(
    String collectionId,
  ) : this._internal(
          (ref) => collectionName(
            ref as CollectionNameRef,
            collectionId,
          ),
          from: collectionNameProvider,
          name: r'collectionNameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$collectionNameHash,
          dependencies: CollectionNameFamily._dependencies,
          allTransitiveDependencies:
              CollectionNameFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  CollectionNameProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
  }) : super.internal();

  final String collectionId;

  @override
  Override overrideWith(
    Stream<String?> Function(CollectionNameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CollectionNameProvider._internal(
        (ref) => create(ref as CollectionNameRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<String?> createElement() {
    return _CollectionNameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionNameProvider &&
        other.collectionId == collectionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CollectionNameRef on AutoDisposeStreamProviderRef<String?> {
  /// The parameter `collectionId` of this provider.
  String get collectionId;
}

class _CollectionNameProviderElement
    extends AutoDisposeStreamProviderElement<String?> with CollectionNameRef {
  _CollectionNameProviderElement(super.provider);

  @override
  String get collectionId => (origin as CollectionNameProvider).collectionId;
}

String _$collectionFoldersHash() => r'0201bdb7340183c54b86017aa80dc98dee5f1df7';

/// Every folder, binned ones too, for the Collections path and the tree.
///
/// Copied from [collectionFolders].
@ProviderFor(collectionFolders)
final collectionFoldersProvider =
    AutoDisposeStreamProvider<List<CollectionFolder>>.internal(
  collectionFolders,
  name: r'collectionFoldersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$collectionFoldersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CollectionFoldersRef
    = AutoDisposeStreamProviderRef<List<CollectionFolder>>;
String _$dialoguePushServiceHash() =>
    r'9bb797404de35c446b3c7b4c3ae6d59018005bba';

/// Adds an import's rows and dialogues, and scene pictures, to a published
/// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
/// uses it is `dialoguePushProvider`.
///
/// Copied from [dialoguePushService].
@ProviderFor(dialoguePushService)
final dialoguePushServiceProvider = Provider<DialoguePushService>.internal(
  dialoguePushService,
  name: r'dialoguePushServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dialoguePushServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DialoguePushServiceRef = ProviderRef<DialoguePushService>;
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
/// preference: it lives here rather than on `WordCollection` because it is not
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
/// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
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
String _$dialoguesSettingNotifierHash() =>
    r'79a0b0141cc70e6d14eb3a468af48a9fb1300bb6';

/// The "Get dialogues from subtitles" switch in Settings
/// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
/// also asks for film dialogues. Persisted like the word detail mode; off
/// until the stored value is read ([loaded]).
///
/// Copied from [DialoguesSettingNotifier].
@ProviderFor(DialoguesSettingNotifier)
final dialoguesSettingNotifierProvider =
    NotifierProvider<DialoguesSettingNotifier, bool>.internal(
  DialoguesSettingNotifier.new,
  name: r'dialoguesSettingNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dialoguesSettingNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DialoguesSettingNotifier = Notifier<bool>;
String _$subtitleImportPrefsNotifierHash() =>
    r'62a46bccde782750c8ef15315e616046294235bb';

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of level and maximum, the "Update with
/// each import" switch, the translator and the model. Persisted like the word detail mode;
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
String _$photoTabTopNotifierHash() =>
    r'64d44d57f4fa1cfe9a9043c6528efcacf16be923';

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).
///
/// Copied from [PhotoTabTopNotifier].
@ProviderFor(PhotoTabTopNotifier)
final photoTabTopNotifierProvider =
    NotifierProvider<PhotoTabTopNotifier, double>.internal(
  PhotoTabTopNotifier.new,
  name: r'photoTabTopNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$photoTabTopNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PhotoTabTopNotifier = Notifier<double>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vocabPhotoService)
final vocabPhotoServiceProvider = VocabPhotoServiceProvider._();

final class VocabPhotoServiceProvider extends $FunctionalProvider<
    VocabPhotoService,
    VocabPhotoService,
    VocabPhotoService> with $Provider<VocabPhotoService> {
  VocabPhotoServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vocabPhotoServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vocabPhotoServiceHash();

  @$internal
  @override
  $ProviderElement<VocabPhotoService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VocabPhotoService create(Ref ref) {
    return vocabPhotoService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VocabPhotoService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VocabPhotoService>(value),
    );
  }
}

String _$vocabPhotoServiceHash() => r'380ca452d4e4be41e35c3b9266cfb041bceaa536';

@ProviderFor(photoScaler)
final photoScalerProvider = PhotoScalerProvider._();

final class PhotoScalerProvider
    extends $FunctionalProvider<PhotoScaler, PhotoScaler, PhotoScaler>
    with $Provider<PhotoScaler> {
  PhotoScalerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'photoScalerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$photoScalerHash();

  @$internal
  @override
  $ProviderElement<PhotoScaler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhotoScaler create(Ref ref) {
    return photoScaler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoScaler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoScaler>(value),
    );
  }
}

String _$photoScalerHash() => r'af179c8f6325da4a20a8c72b488e27151515346a';

/// Camera and gallery picks for the photo chain (photo-from-gallery T2);
/// a provider so widget tests can swap in a fake picker.

@ProviderFor(imagePicker)
final imagePickerProvider = ImagePickerProvider._();

/// Camera and gallery picks for the photo chain (photo-from-gallery T2);
/// a provider so widget tests can swap in a fake picker.

final class ImagePickerProvider
    extends $FunctionalProvider<ImagePicker, ImagePicker, ImagePicker>
    with $Provider<ImagePicker> {
  /// Camera and gallery picks for the photo chain (photo-from-gallery T2);
  /// a provider so widget tests can swap in a fake picker.
  ImagePickerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'imagePickerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$imagePickerHash();

  @$internal
  @override
  $ProviderElement<ImagePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImagePicker create(Ref ref) {
    return imagePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImagePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImagePicker>(value),
    );
  }
}

String _$imagePickerHash() => r'7740c09b2d6b395ce466f1b72b93b31db7bfd740';

@ProviderFor(collectionStore)
final collectionStoreProvider = CollectionStoreProvider._();

final class CollectionStoreProvider extends $FunctionalProvider<
        AsyncValue<CollectionStore>, CollectionStore, FutureOr<CollectionStore>>
    with $FutureModifier<CollectionStore>, $FutureProvider<CollectionStore> {
  CollectionStoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionStoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionStoreHash();

  @$internal
  @override
  $FutureProviderElement<CollectionStore> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CollectionStore> create(Ref ref) {
    return collectionStore(ref);
  }
}

String _$collectionStoreHash() => r'734e53cb3306b24784379060398a3d74e2bac7c5';

/// Puts the user's data aside to show the app as to a new user, and brings
/// it back (new-user-trial, owner 2026-10-17).

@ProviderFor(newUserTrial)
final newUserTrialProvider = NewUserTrialProvider._();

/// Puts the user's data aside to show the app as to a new user, and brings
/// it back (new-user-trial, owner 2026-10-17).

final class NewUserTrialProvider
    extends $FunctionalProvider<NewUserTrial, NewUserTrial, NewUserTrial>
    with $Provider<NewUserTrial> {
  /// Puts the user's data aside to show the app as to a new user, and brings
  /// it back (new-user-trial, owner 2026-10-17).
  NewUserTrialProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'newUserTrialProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$newUserTrialHash();

  @$internal
  @override
  $ProviderElement<NewUserTrial> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NewUserTrial create(Ref ref) {
    return newUserTrial(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NewUserTrial value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NewUserTrial>(value),
    );
  }
}

String _$newUserTrialHash() => r'914f1c160762186768b6cda8ed7401d812808cfb';

/// When the new-user trial's backup was made; null while no trial is on.

@ProviderFor(newUserBackup)
final newUserBackupProvider = NewUserBackupProvider._();

/// When the new-user trial's backup was made; null while no trial is on.

final class NewUserBackupProvider extends $FunctionalProvider<
        AsyncValue<DateTime?>, DateTime?, FutureOr<DateTime?>>
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// When the new-user trial's backup was made; null while no trial is on.
  NewUserBackupProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'newUserBackupProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$newUserBackupHash();

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    return newUserBackup(ref);
  }
}

String _$newUserBackupHash() => r'a385c54cf25fbd0a4a932aea61c2d67dddd8beca';

/// The kept 1600 px copies of the session photos (good-looking-web T17).

@ProviderFor(sourcePhotoStore)
final sourcePhotoStoreProvider = SourcePhotoStoreProvider._();

/// The kept 1600 px copies of the session photos (good-looking-web T17).

final class SourcePhotoStoreProvider extends $FunctionalProvider<
    SourcePhotoStore,
    SourcePhotoStore,
    SourcePhotoStore> with $Provider<SourcePhotoStore> {
  /// The kept 1600 px copies of the session photos (good-looking-web T17).
  SourcePhotoStoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sourcePhotoStoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sourcePhotoStoreHash();

  @$internal
  @override
  $ProviderElement<SourcePhotoStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SourcePhotoStore create(Ref ref) {
    return sourcePhotoStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourcePhotoStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourcePhotoStore>(value),
    );
  }
}

String _$sourcePhotoStoreHash() => r'5ba15f72c22a820489d043a9260d86a9f9d91b3d';

/// The Android Back-gesture exclusion for the photo tab
/// (side-bar-for-main-screen ADR-0002).

@ProviderFor(systemGestureExclusion)
final systemGestureExclusionProvider = SystemGestureExclusionProvider._();

/// The Android Back-gesture exclusion for the photo tab
/// (side-bar-for-main-screen ADR-0002).

final class SystemGestureExclusionProvider extends $FunctionalProvider<
    SystemGestureExclusion,
    SystemGestureExclusion,
    SystemGestureExclusion> with $Provider<SystemGestureExclusion> {
  /// The Android Back-gesture exclusion for the photo tab
  /// (side-bar-for-main-screen ADR-0002).
  SystemGestureExclusionProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'systemGestureExclusionProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$systemGestureExclusionHash();

  @$internal
  @override
  $ProviderElement<SystemGestureExclusion> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemGestureExclusion create(Ref ref) {
    return systemGestureExclusion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemGestureExclusion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemGestureExclusion>(value),
    );
  }
}

String _$systemGestureExclusionHash() =>
    r'6e5cfd25b75fb8acad89848713fcd6222249a31f';

/// The story runs, kept in the same database as the sessions (ADR-0003).

@ProviderFor(storyRunStore)
final storyRunStoreProvider = StoryRunStoreProvider._();

/// The story runs, kept in the same database as the sessions (ADR-0003).

final class StoryRunStoreProvider extends $FunctionalProvider<
        AsyncValue<StoryRunStore>, StoryRunStore, FutureOr<StoryRunStore>>
    with $FutureModifier<StoryRunStore>, $FutureProvider<StoryRunStore> {
  /// The story runs, kept in the same database as the sessions (ADR-0003).
  StoryRunStoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storyRunStoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storyRunStoreHash();

  @$internal
  @override
  $FutureProviderElement<StoryRunStore> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<StoryRunStore> create(Ref ref) {
    return storyRunStore(ref);
  }
}

String _$storyRunStoreHash() => r'406c5b86ac090c61141ffc690cd2065301fb3140';

/// The compressed story pictures kept on the phone.

@ProviderFor(storyPictureStore)
final storyPictureStoreProvider = StoryPictureStoreProvider._();

/// The compressed story pictures kept on the phone.

final class StoryPictureStoreProvider extends $FunctionalProvider<
    StoryPictureStore,
    StoryPictureStore,
    StoryPictureStore> with $Provider<StoryPictureStore> {
  /// The compressed story pictures kept on the phone.
  StoryPictureStoreProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storyPictureStoreProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storyPictureStoreHash();

  @$internal
  @override
  $ProviderElement<StoryPictureStore> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StoryPictureStore create(Ref ref) {
    return storyPictureStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoryPictureStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoryPictureStore>(value),
    );
  }
}

String _$storyPictureStoreHash() => r'625afbaf103c13e839e9def2035d1edb5251d58f';

@ProviderFor(googleTranslateService)
final googleTranslateServiceProvider = GoogleTranslateServiceProvider._();

final class GoogleTranslateServiceProvider extends $FunctionalProvider<
    GoogleTranslateService,
    GoogleTranslateService,
    GoogleTranslateService> with $Provider<GoogleTranslateService> {
  GoogleTranslateServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'googleTranslateServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$googleTranslateServiceHash();

  @$internal
  @override
  $ProviderElement<GoogleTranslateService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoogleTranslateService create(Ref ref) {
    return googleTranslateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleTranslateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleTranslateService>(value),
    );
  }
}

String _$googleTranslateServiceHash() =>
    r'6afdf9f3d52ebdc231e65e17d05446c50f457432';

@ProviderFor(pronunciationService)
final pronunciationServiceProvider = PronunciationServiceProvider._();

final class PronunciationServiceProvider extends $FunctionalProvider<
    PronunciationService,
    PronunciationService,
    PronunciationService> with $Provider<PronunciationService> {
  PronunciationServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'pronunciationServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pronunciationServiceHash();

  @$internal
  @override
  $ProviderElement<PronunciationService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PronunciationService create(Ref ref) {
    return pronunciationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PronunciationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PronunciationService>(value),
    );
  }
}

String _$pronunciationServiceHash() =>
    r'a04b5b4ea06bd7d29a7b0874172549524472bb26';

/// Dictionary senses for the definition field, via the Worker (ADR-0002).

@ProviderFor(dictionaryService)
final dictionaryServiceProvider = DictionaryServiceProvider._();

/// Dictionary senses for the definition field, via the Worker (ADR-0002).

final class DictionaryServiceProvider extends $FunctionalProvider<
    DictionaryService,
    DictionaryService,
    DictionaryService> with $Provider<DictionaryService> {
  /// Dictionary senses for the definition field, via the Worker (ADR-0002).
  DictionaryServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dictionaryServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dictionaryServiceHash();

  @$internal
  @override
  $ProviderElement<DictionaryService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DictionaryService create(Ref ref) {
    return dictionaryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DictionaryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DictionaryService>(value),
    );
  }
}

String _$dictionaryServiceHash() => r'55c5a3e42d3dab60fb9f17e0724c51e347330b20';

/// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).

@ProviderFor(storyApiService)
final storyApiServiceProvider = StoryApiServiceProvider._();

/// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).

final class StoryApiServiceProvider extends $FunctionalProvider<StoryApiService,
    StoryApiService, StoryApiService> with $Provider<StoryApiService> {
  /// The Worker's story routes: offered AIs, grouping, runs (mnemonic-story T12).
  StoryApiServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'storyApiServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storyApiServiceHash();

  @$internal
  @override
  $ProviderElement<StoryApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StoryApiService create(Ref ref) {
    return storyApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoryApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoryApiService>(value),
    );
  }
}

String _$storyApiServiceHash() => r'a236884d7c0ebee6e6e8e747202f0035a3f0f616';

/// The Worker's collection naming (collection-naming, owner 2026-10-18).

@ProviderFor(collectionNamingService)
final collectionNamingServiceProvider = CollectionNamingServiceProvider._();

/// The Worker's collection naming (collection-naming, owner 2026-10-18).

final class CollectionNamingServiceProvider extends $FunctionalProvider<
    CollectionNamingService,
    CollectionNamingService,
    CollectionNamingService> with $Provider<CollectionNamingService> {
  /// The Worker's collection naming (collection-naming, owner 2026-10-18).
  CollectionNamingServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionNamingServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionNamingServiceHash();

  @$internal
  @override
  $ProviderElement<CollectionNamingService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CollectionNamingService create(Ref ref) {
    return collectionNamingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionNamingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionNamingService>(value),
    );
  }
}

String _$collectionNamingServiceHash() =>
    r'ea710e876937b0fa9333378880697a6e9fce73db';

/// The Worker's exercise services: data and sentence checks (learn-kit S-13).

@ProviderFor(learnApiService)
final learnApiServiceProvider = LearnApiServiceProvider._();

/// The Worker's exercise services: data and sentence checks (learn-kit S-13).

final class LearnApiServiceProvider extends $FunctionalProvider<LearnApiService,
    LearnApiService, LearnApiService> with $Provider<LearnApiService> {
  /// The Worker's exercise services: data and sentence checks (learn-kit S-13).
  LearnApiServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'learnApiServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnApiServiceHash();

  @$internal
  @override
  $ProviderElement<LearnApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LearnApiService create(Ref ref) {
    return learnApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearnApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearnApiService>(value),
    );
  }
}

String _$learnApiServiceHash() => r'2da4556e695e318b873e02fe83b565960e790244';

/// The Worker's talk turns for Talk with AI (learn-redesign ADR-0007).

@ProviderFor(talkApiService)
final talkApiServiceProvider = TalkApiServiceProvider._();

/// The Worker's talk turns for Talk with AI (learn-redesign ADR-0007).

final class TalkApiServiceProvider
    extends $FunctionalProvider<TalkApiService, TalkApiService, TalkApiService>
    with $Provider<TalkApiService> {
  /// The Worker's talk turns for Talk with AI (learn-redesign ADR-0007).
  TalkApiServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'talkApiServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$talkApiServiceHash();

  @$internal
  @override
  $ProviderElement<TalkApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TalkApiService create(Ref ref) {
    return talkApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TalkApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TalkApiService>(value),
    );
  }
}

String _$talkApiServiceHash() => r'210b666c417cfb782e871aedfb4eeb8ee1dbbaed';

/// Where Step 3 exams record each word's known / repeat result (learn-kit
/// S-23), on the session in the session store.

@ProviderFor(examResultSink)
final examResultSinkProvider = ExamResultSinkProvider._();

/// Where Step 3 exams record each word's known / repeat result (learn-kit
/// S-23), on the session in the session store.

final class ExamResultSinkProvider
    extends $FunctionalProvider<ExamResultSink, ExamResultSink, ExamResultSink>
    with $Provider<ExamResultSink> {
  /// Where Step 3 exams record each word's known / repeat result (learn-kit
  /// S-23), on the session in the session store.
  ExamResultSinkProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'examResultSinkProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$examResultSinkHash();

  @$internal
  @override
  $ProviderElement<ExamResultSink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExamResultSink create(Ref ref) {
    return examResultSink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExamResultSink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExamResultSink>(value),
    );
  }
}

String _$examResultSinkHash() => r'48e41297d46cc66488d89b803bb61380316ddf96';

/// The AIs on the Worker's offered list. Fetched on first use and cached in
/// preferences; when the fetch fails, the cached list is used, and when there is
/// none either, the built-in defaults (AC-13). Never throws.

@ProviderFor(offeredAis)
final offeredAisProvider = OfferedAisProvider._();

/// The AIs on the Worker's offered list. Fetched on first use and cached in
/// preferences; when the fetch fails, the cached list is used, and when there is
/// none either, the built-in defaults (AC-13). Never throws.

final class OfferedAisProvider extends $FunctionalProvider<
        AsyncValue<OfferedAiList>, OfferedAiList, FutureOr<OfferedAiList>>
    with $FutureModifier<OfferedAiList>, $FutureProvider<OfferedAiList> {
  /// The AIs on the Worker's offered list. Fetched on first use and cached in
  /// preferences; when the fetch fails, the cached list is used, and when there is
  /// none either, the built-in defaults (AC-13). Never throws.
  OfferedAisProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'offeredAisProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$offeredAisHash();

  @$internal
  @override
  $FutureProviderElement<OfferedAiList> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OfferedAiList> create(Ref ref) {
    return offeredAis(ref);
  }
}

String _$offeredAisHash() => r'5a7c2096143ae6f5c0db6e33b3300caccad2a625';

/// The learner's saved AI for each step of a story run (AC-12). Persisted like
/// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
/// before showing or using it, so a withdrawn AI falls back to the default (AC-13).

@ProviderFor(AiChoiceNotifier)
final aiChoiceProvider = AiChoiceNotifierProvider._();

/// The learner's saved AI for each step of a story run (AC-12). Persisted like
/// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
/// before showing or using it, so a withdrawn AI falls back to the default (AC-13).
final class AiChoiceNotifierProvider
    extends $NotifierProvider<AiChoiceNotifier, StoredAiChoice> {
  /// The learner's saved AI for each step of a story run (AC-12). Persisted like
  /// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
  /// before showing or using it, so a withdrawn AI falls back to the default (AC-13).
  AiChoiceNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'aiChoiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiChoiceNotifierHash();

  @$internal
  @override
  AiChoiceNotifier create() => AiChoiceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoredAiChoice value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoredAiChoice>(value),
    );
  }
}

String _$aiChoiceNotifierHash() => r'56fb292859c4632c546aa2450c049a959ad528bc';

/// The learner's saved AI for each step of a story run (AC-12). Persisted like
/// the word detail mode; check it with [resolveAiChoice] against [offeredAisProvider]
/// before showing or using it, so a withdrawn AI falls back to the default (AC-13).

abstract class _$AiChoiceNotifier extends $Notifier<StoredAiChoice> {
  StoredAiChoice build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StoredAiChoice, StoredAiChoice>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<StoredAiChoice, StoredAiChoice>,
        StoredAiChoice,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(collectionPublishService)
final collectionPublishServiceProvider = CollectionPublishServiceProvider._();

final class CollectionPublishServiceProvider extends $FunctionalProvider<
    CollectionPublishService,
    CollectionPublishService,
    CollectionPublishService> with $Provider<CollectionPublishService> {
  CollectionPublishServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionPublishServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionPublishServiceHash();

  @$internal
  @override
  $ProviderElement<CollectionPublishService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CollectionPublishService create(Ref ref) {
    return collectionPublishService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CollectionPublishService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CollectionPublishService>(value),
    );
  }
}

String _$collectionPublishServiceHash() =>
    r'782c4e1830d4068a7ccce88ceaf477de7cc026d4';

/// Word picking from a subtitle file's lines, via the Worker (words-from-subtitles).

@ProviderFor(subtitleWordsService)
final subtitleWordsServiceProvider = SubtitleWordsServiceProvider._();

/// Word picking from a subtitle file's lines, via the Worker (words-from-subtitles).

final class SubtitleWordsServiceProvider extends $FunctionalProvider<
    SubtitleWordsService,
    SubtitleWordsService,
    SubtitleWordsService> with $Provider<SubtitleWordsService> {
  /// Word picking from a subtitle file's lines, via the Worker (words-from-subtitles).
  SubtitleWordsServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'subtitleWordsServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subtitleWordsServiceHash();

  @$internal
  @override
  $ProviderElement<SubtitleWordsService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubtitleWordsService create(Ref ref) {
    return subtitleWordsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleWordsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleWordsService>(value),
    );
  }
}

String _$subtitleWordsServiceHash() =>
    r'56f13395451925ab40ca0224660f990ec0cd6ce7';

/// Subtitle files found by film name, through the Worker (OpenSubtitles).

@ProviderFor(subtitleSearchService)
final subtitleSearchServiceProvider = SubtitleSearchServiceProvider._();

/// Subtitle files found by film name, through the Worker (OpenSubtitles).

final class SubtitleSearchServiceProvider extends $FunctionalProvider<
    SubtitleSearchService,
    SubtitleSearchService,
    SubtitleSearchService> with $Provider<SubtitleSearchService> {
  /// Subtitle files found by film name, through the Worker (OpenSubtitles).
  SubtitleSearchServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'subtitleSearchServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subtitleSearchServiceHash();

  @$internal
  @override
  $ProviderElement<SubtitleSearchService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubtitleSearchService create(Ref ref) {
    return subtitleSearchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleSearchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleSearchService>(value),
    );
  }
}

String _$subtitleSearchServiceHash() =>
    r'cc2abc44e30d06312b788e733574cf0709c3fcdd';

/// Subtitle words translated on the phone with Google Translate.

@ProviderFor(subtitleGoogleWords)
final subtitleGoogleWordsProvider = SubtitleGoogleWordsProvider._();

/// Subtitle words translated on the phone with Google Translate.

final class SubtitleGoogleWordsProvider extends $FunctionalProvider<
    SubtitleGoogleWords,
    SubtitleGoogleWords,
    SubtitleGoogleWords> with $Provider<SubtitleGoogleWords> {
  /// Subtitle words translated on the phone with Google Translate.
  SubtitleGoogleWordsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'subtitleGoogleWordsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subtitleGoogleWordsHash();

  @$internal
  @override
  $ProviderElement<SubtitleGoogleWords> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubtitleGoogleWords create(Ref ref) {
    return subtitleGoogleWords(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleGoogleWords value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleGoogleWords>(value),
    );
  }
}

String _$subtitleGoogleWordsHash() =>
    r'fca5efe9d5a66d33861f0cc0b336f3b1a60f873b';

/// Background upload of the photos a publish declared (good-looking-web T18).
/// keepAlive, so uploads outlive the words table (sad §8).

@ProviderFor(photoUploadService)
final photoUploadServiceProvider = PhotoUploadServiceProvider._();

/// Background upload of the photos a publish declared (good-looking-web T18).
/// keepAlive, so uploads outlive the words table (sad §8).

final class PhotoUploadServiceProvider extends $FunctionalProvider<
    PhotoUploadService,
    PhotoUploadService,
    PhotoUploadService> with $Provider<PhotoUploadService> {
  /// Background upload of the photos a publish declared (good-looking-web T18).
  /// keepAlive, so uploads outlive the words table (sad §8).
  PhotoUploadServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'photoUploadServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$photoUploadServiceHash();

  @$internal
  @override
  $ProviderElement<PhotoUploadService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhotoUploadService create(Ref ref) {
    return photoUploadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoUploadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoUploadService>(value),
    );
  }
}

String _$photoUploadServiceHash() =>
    r'8c9008e9902f73f6fe215aff73ac7796edf87107';

@ProviderFor(collectionById)
final collectionByIdProvider = CollectionByIdFamily._();

final class CollectionByIdProvider extends $FunctionalProvider<
        AsyncValue<WordCollection?>, WordCollection?, FutureOr<WordCollection?>>
    with $FutureModifier<WordCollection?>, $FutureProvider<WordCollection?> {
  CollectionByIdProvider._(
      {required CollectionByIdFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'collectionByIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionByIdHash();

  @override
  String toString() {
    return r'collectionByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WordCollection?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<WordCollection?> create(Ref ref) {
    final argument = this.argument as String;
    return collectionById(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionByIdHash() => r'ad2b3bf6ef382c136b9269914067acfeafcd7c90';

final class CollectionByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WordCollection?>, String> {
  CollectionByIdFamily._()
      : super(
          retry: null,
          name: r'collectionByIdProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  CollectionByIdProvider call(
    String collectionId,
  ) =>
      CollectionByIdProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'collectionByIdProvider';
}

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.

@ProviderFor(collectionLevel)
final collectionLevelProvider = CollectionLevelFamily._();

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.

final class CollectionLevelProvider extends $FunctionalProvider<
        AsyncValue<List<LevelItem>>, List<LevelItem>, Stream<List<LevelItem>>>
    with $FutureModifier<List<LevelItem>>, $StreamProvider<List<LevelItem>> {
  /// One level of the Collections screen (collections-screen T8): the folders
  /// and collections in [folderId], null being the top level, that are not in
  /// the bin, by order, re-emitted after every write.
  CollectionLevelProvider._(
      {required CollectionLevelFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'collectionLevelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionLevelHash();

  @override
  String toString() {
    return r'collectionLevelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<LevelItem>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<LevelItem>> create(Ref ref) {
    final argument = this.argument as String?;
    return collectionLevel(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionLevelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionLevelHash() => r'35c09f3e0dc5b9ca13c5d35021e6ce1ef3d65d15';

/// One level of the Collections screen (collections-screen T8): the folders
/// and collections in [folderId], null being the top level, that are not in
/// the bin, by order, re-emitted after every write.

final class CollectionLevelFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LevelItem>>, String?> {
  CollectionLevelFamily._()
      : super(
          retry: null,
          name: r'collectionLevelProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// One level of the Collections screen (collections-screen T8): the folders
  /// and collections in [folderId], null being the top level, that are not in
  /// the bin, by order, re-emitted after every write.

  CollectionLevelProvider call(
    String? folderId,
  ) =>
      CollectionLevelProvider._(argument: folderId, from: this);

  @override
  String toString() => r'collectionLevelProvider';
}

/// Every collection that is not in the bin, empty ones too, for the
/// Collections search and the tag counts (collection-tags ADR-0006); one
/// emission per burst of writes.

@ProviderFor(collectionSummaries)
final collectionSummariesProvider = CollectionSummariesProvider._();

/// Every collection that is not in the bin, empty ones too, for the
/// Collections search and the tag counts (collection-tags ADR-0006); one
/// emission per burst of writes.

final class CollectionSummariesProvider extends $FunctionalProvider<
        AsyncValue<List<CollectionSummary>>,
        List<CollectionSummary>,
        Stream<List<CollectionSummary>>>
    with
        $FutureModifier<List<CollectionSummary>>,
        $StreamProvider<List<CollectionSummary>> {
  /// Every collection that is not in the bin, empty ones too, for the
  /// Collections search and the tag counts (collection-tags ADR-0006); one
  /// emission per burst of writes.
  CollectionSummariesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionSummariesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<CollectionSummary>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<CollectionSummary>> create(Ref ref) {
    return collectionSummaries(ref);
  }
}

String _$collectionSummariesHash() =>
    r'e728a8708419084d7a2350ad47bd8d86dc8fb691';

/// The whole tag library, forgotten entries included (collection-tags
/// ADR-0009).

@ProviderFor(tagLibrary)
final tagLibraryProvider = TagLibraryProvider._();

/// The whole tag library, forgotten entries included (collection-tags
/// ADR-0009).

final class TagLibraryProvider extends $FunctionalProvider<
        AsyncValue<List<TagLibraryEntry>>,
        List<TagLibraryEntry>,
        Stream<List<TagLibraryEntry>>>
    with
        $FutureModifier<List<TagLibraryEntry>>,
        $StreamProvider<List<TagLibraryEntry>> {
  /// The whole tag library, forgotten entries included (collection-tags
  /// ADR-0009).
  TagLibraryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tagLibraryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tagLibraryHash();

  @$internal
  @override
  $StreamProviderElement<List<TagLibraryEntry>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<TagLibraryEntry>> create(Ref ref) {
    return tagLibrary(ref);
  }
}

String _$tagLibraryHash() => r'fa2e6b23b96de113752f004b78bf4e3279e69bc7';

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.

@ProviderFor(collectionName)
final collectionNameProvider = CollectionNameFamily._();

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.

final class CollectionNameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  /// The stored name of one collection (collections-screen T14): the main
  /// screen's title. Null before the backfill; callers show the date name.
  CollectionNameProvider._(
      {required CollectionNameFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'collectionNameProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionNameHash();

  @override
  String toString() {
    return r'collectionNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    final argument = this.argument as String;
    return collectionName(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionNameHash() => r'8a07f2bd9b41c3855b426acf2b30592f9ccd9978';

/// The stored name of one collection (collections-screen T14): the main
/// screen's title. Null before the backfill; callers show the date name.

final class CollectionNameFamily extends $Family
    with $FunctionalFamilyOverride<Stream<String?>, String> {
  CollectionNameFamily._()
      : super(
          retry: null,
          name: r'collectionNameProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The stored name of one collection (collections-screen T14): the main
  /// screen's title. Null before the backfill; callers show the date name.

  CollectionNameProvider call(
    String collectionId,
  ) =>
      CollectionNameProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'collectionNameProvider';
}

/// The stored name of collection [collectionId] with its [NameKind], for the
/// main screen's title (collection-naming).

@ProviderFor(collectionNaming)
final collectionNamingProvider = CollectionNamingFamily._();

/// The stored name of collection [collectionId] with its [NameKind], for the
/// main screen's title (collection-naming).

final class CollectionNamingProvider extends $FunctionalProvider<
        AsyncValue<
            ({
              NameKind kind,
              String? name,
            })?>,
        ({
          NameKind kind,
          String? name,
        })?,
        Stream<
            ({
              NameKind kind,
              String? name,
            })?>>
    with
        $FutureModifier<
            ({
              NameKind kind,
              String? name,
            })?>,
        $StreamProvider<
            ({
              NameKind kind,
              String? name,
            })?> {
  /// The stored name of collection [collectionId] with its [NameKind], for the
  /// main screen's title (collection-naming).
  CollectionNamingProvider._(
      {required CollectionNamingFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'collectionNamingProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionNamingHash();

  @override
  String toString() {
    return r'collectionNamingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<
      ({
        NameKind kind,
        String? name,
      })?> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<
      ({
        NameKind kind,
        String? name,
      })?> create(Ref ref) {
    final argument = this.argument as String;
    return collectionNaming(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionNamingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionNamingHash() => r'eacf5846b5e9db437f2f039634d17ff5f7715b0c';

/// The stored name of collection [collectionId] with its [NameKind], for the
/// main screen's title (collection-naming).

final class CollectionNamingFamily extends $Family
    with
        $FunctionalFamilyOverride<
            Stream<
                ({
                  NameKind kind,
                  String? name,
                })?>,
            String> {
  CollectionNamingFamily._()
      : super(
          retry: null,
          name: r'collectionNamingProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The stored name of collection [collectionId] with its [NameKind], for the
  /// main screen's title (collection-naming).

  CollectionNamingProvider call(
    String collectionId,
  ) =>
      CollectionNamingProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'collectionNamingProvider';
}

/// Every folder, binned ones too, for the Collections path and the tree.

@ProviderFor(collectionFolders)
final collectionFoldersProvider = CollectionFoldersProvider._();

/// Every folder, binned ones too, for the Collections path and the tree.

final class CollectionFoldersProvider extends $FunctionalProvider<
        AsyncValue<List<CollectionFolder>>,
        List<CollectionFolder>,
        Stream<List<CollectionFolder>>>
    with
        $FutureModifier<List<CollectionFolder>>,
        $StreamProvider<List<CollectionFolder>> {
  /// Every folder, binned ones too, for the Collections path and the tree.
  CollectionFoldersProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'collectionFoldersProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$collectionFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<CollectionFolder>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<CollectionFolder>> create(Ref ref) {
    return collectionFolders(ref);
  }
}

String _$collectionFoldersHash() => r'0201bdb7340183c54b86017aa80dc98dee5f1df7';

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `WordCollection` because it is not
/// session data and must never reach Isar (task-13), and `keepAlive` because
/// the Settings screen is the only writer while the input screen is the only
/// reader -- autoDispose would drop the value when Settings is popped.

@ProviderFor(DragMode)
final dragModeProvider = DragModeProvider._();

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `WordCollection` because it is not
/// session data and must never reach Isar (task-13), and `keepAlive` because
/// the Settings screen is the only writer while the input screen is the only
/// reader -- autoDispose would drop the value when Settings is popped.
final class DragModeProvider extends $NotifierProvider<DragMode, bool> {
  /// Whether the word list is in drag-and-drop (reorder) mode. A pure display
  /// preference: it lives here rather than on `WordCollection` because it is not
  /// session data and must never reach Isar (task-13), and `keepAlive` because
  /// the Settings screen is the only writer while the input screen is the only
  /// reader -- autoDispose would drop the value when Settings is popped.
  DragModeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dragModeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dragModeHash();

  @$internal
  @override
  DragMode create() => DragMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$dragModeHash() => r'6c8be31e69381c41da06163dfa7a77cfa9c1bb89';

/// Whether the word list is in drag-and-drop (reorder) mode. A pure display
/// preference: it lives here rather than on `WordCollection` because it is not
/// session data and must never reach Isar (task-13), and `keepAlive` because
/// the Settings screen is the only writer while the input screen is the only
/// reader -- autoDispose would drop the value when Settings is popped.

abstract class _$DragMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
/// switches once the stored value is read ([loaded]).

@ProviderFor(WordDetailModeNotifier)
final wordDetailModeProvider = WordDetailModeNotifierProvider._();

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
/// switches once the stored value is read ([loaded]).
final class WordDetailModeNotifierProvider
    extends $NotifierProvider<WordDetailModeNotifier, WordDetailMode> {
  /// The learner's word detail mode. Unlike drag mode it survives a restart, so
  /// it is persisted under one preferences key; it is still a display preference
  /// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
  /// switches once the stored value is read ([loaded]).
  WordDetailModeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'wordDetailModeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$wordDetailModeNotifierHash();

  @$internal
  @override
  WordDetailModeNotifier create() => WordDetailModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordDetailMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordDetailMode>(value),
    );
  }
}

String _$wordDetailModeNotifierHash() =>
    r'45973bab20f05a4640eaf6cb6cbd04bff4126d76';

/// The learner's word detail mode. Unlike drag mode it survives a restart, so
/// it is persisted under one preferences key; it is still a display preference
/// and never goes on `WordCollection`. Starts as [WordDetailMode.translation] and
/// switches once the stored value is read ([loaded]).

abstract class _$WordDetailModeNotifier extends $Notifier<WordDetailMode> {
  WordDetailMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WordDetailMode, WordDetailMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<WordDetailMode, WordDetailMode>,
        WordDetailMode,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The learn preset, enabled exercises and words per session; persisted like
/// [WordDetailModeNotifier]. Starts as Balanced / its set / all words and
/// switches once the stored values are read ([loaded]).

@ProviderFor(LearnSettingsNotifier)
final learnSettingsProvider = LearnSettingsNotifierProvider._();

/// The learn preset, enabled exercises and words per session; persisted like
/// [WordDetailModeNotifier]. Starts as Balanced / its set / all words and
/// switches once the stored values are read ([loaded]).
final class LearnSettingsNotifierProvider
    extends $NotifierProvider<LearnSettingsNotifier, LearnSettings> {
  /// The learn preset, enabled exercises and words per session; persisted like
  /// [WordDetailModeNotifier]. Starts as Balanced / its set / all words and
  /// switches once the stored values are read ([loaded]).
  LearnSettingsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'learnSettingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnSettingsNotifierHash();

  @$internal
  @override
  LearnSettingsNotifier create() => LearnSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearnSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearnSettings>(value),
    );
  }
}

String _$learnSettingsNotifierHash() =>
    r'6ba5822e47837e70ee80a57b34cf031f60e9867b';

/// The learn preset, enabled exercises and words per session; persisted like
/// [WordDetailModeNotifier]. Starts as Balanced / its set / all words and
/// switches once the stored values are read ([loaded]).

abstract class _$LearnSettingsNotifier extends $Notifier<LearnSettings> {
  LearnSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LearnSettings, LearnSettings>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LearnSettings, LearnSettings>,
        LearnSettings,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Whether a collection's learn session is split into its word groups
/// (AC-18); on by default, remembered per collection.

@ProviderFor(LearnSplitNotifier)
final learnSplitProvider = LearnSplitNotifierFamily._();

/// Whether a collection's learn session is split into its word groups
/// (AC-18); on by default, remembered per collection.
final class LearnSplitNotifierProvider
    extends $NotifierProvider<LearnSplitNotifier, bool> {
  /// Whether a collection's learn session is split into its word groups
  /// (AC-18); on by default, remembered per collection.
  LearnSplitNotifierProvider._(
      {required LearnSplitNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'learnSplitProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnSplitNotifierHash();

  @override
  String toString() {
    return r'learnSplitProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LearnSplitNotifier create() => LearnSplitNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearnSplitNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learnSplitNotifierHash() =>
    r'18a734f282d274061b2c06adec850ac1243c2c8d';

/// Whether a collection's learn session is split into its word groups
/// (AC-18); on by default, remembered per collection.

final class LearnSplitNotifierFamily extends $Family
    with $ClassFamilyOverride<LearnSplitNotifier, bool, bool, bool, String> {
  LearnSplitNotifierFamily._()
      : super(
          retry: null,
          name: r'learnSplitProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  /// Whether a collection's learn session is split into its word groups
  /// (AC-18); on by default, remembered per collection.

  LearnSplitNotifierProvider call(
    String collectionId,
  ) =>
      LearnSplitNotifierProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'learnSplitProvider';
}

/// Whether a collection's learn session is split into its word groups
/// (AC-18); on by default, remembered per collection.

abstract class _$LearnSplitNotifier extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get collectionId => _$args;

  bool build(
    String collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

/// Index of the session group a collection's learner played last, if any.

@ProviderFor(LearnLastGroupNotifier)
final learnLastGroupProvider = LearnLastGroupNotifierFamily._();

/// Index of the session group a collection's learner played last, if any.
final class LearnLastGroupNotifierProvider
    extends $NotifierProvider<LearnLastGroupNotifier, int?> {
  /// Index of the session group a collection's learner played last, if any.
  LearnLastGroupNotifierProvider._(
      {required LearnLastGroupNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'learnLastGroupProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$learnLastGroupNotifierHash();

  @override
  String toString() {
    return r'learnLastGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LearnLastGroupNotifier create() => LearnLastGroupNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearnLastGroupNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$learnLastGroupNotifierHash() =>
    r'5915809e9d038b59f145437d0a69fa3f0a88da30';

/// Index of the session group a collection's learner played last, if any.

final class LearnLastGroupNotifierFamily extends $Family
    with
        $ClassFamilyOverride<LearnLastGroupNotifier, int?, int?, int?, String> {
  LearnLastGroupNotifierFamily._()
      : super(
          retry: null,
          name: r'learnLastGroupProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  /// Index of the session group a collection's learner played last, if any.

  LearnLastGroupNotifierProvider call(
    String collectionId,
  ) =>
      LearnLastGroupNotifierProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'learnLastGroupProvider';
}

/// Index of the session group a collection's learner played last, if any.

abstract class _$LearnLastGroupNotifier extends $Notifier<int?> {
  late final _$args = ref.$arg as String;
  String get collectionId => _$args;

  int? build(
    String collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<int?, int?>, int?, Object?, Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

/// The speech recognition engine for Talk with AI's hold-to-talk, picked in
/// Learn settings (learn-redesign AC-28, ADR-0009 Amendment); persisted like
/// [LearnSettingsNotifier]. Starts as [SpeechEngine.speechToText].

@ProviderFor(SpeechEngineNotifier)
final speechEngineProvider = SpeechEngineNotifierProvider._();

/// The speech recognition engine for Talk with AI's hold-to-talk, picked in
/// Learn settings (learn-redesign AC-28, ADR-0009 Amendment); persisted like
/// [LearnSettingsNotifier]. Starts as [SpeechEngine.speechToText].
final class SpeechEngineNotifierProvider
    extends $NotifierProvider<SpeechEngineNotifier, SpeechEngine> {
  /// The speech recognition engine for Talk with AI's hold-to-talk, picked in
  /// Learn settings (learn-redesign AC-28, ADR-0009 Amendment); persisted like
  /// [LearnSettingsNotifier]. Starts as [SpeechEngine.speechToText].
  SpeechEngineNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'speechEngineProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$speechEngineNotifierHash();

  @$internal
  @override
  SpeechEngineNotifier create() => SpeechEngineNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpeechEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpeechEngine>(value),
    );
  }
}

String _$speechEngineNotifierHash() =>
    r'9666cc44621d443a55c3fce09692c94d71b6016d';

/// The speech recognition engine for Talk with AI's hold-to-talk, picked in
/// Learn settings (learn-redesign AC-28, ADR-0009 Amendment); persisted like
/// [LearnSettingsNotifier]. Starts as [SpeechEngine.speechToText].

abstract class _$SpeechEngineNotifier extends $Notifier<SpeechEngine> {
  SpeechEngine build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SpeechEngine, SpeechEngine>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<SpeechEngine, SpeechEngine>,
        SpeechEngine,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The hold-to-talk input of the engine picked in Learn settings (AC-25,
/// AC-28, ADR-0009); overridden with a fake in tests.

@ProviderFor(speechInput)
final speechInputProvider = SpeechInputProvider._();

/// The hold-to-talk input of the engine picked in Learn settings (AC-25,
/// AC-28, ADR-0009); overridden with a fake in tests.

final class SpeechInputProvider
    extends $FunctionalProvider<SpeechInput, SpeechInput, SpeechInput>
    with $Provider<SpeechInput> {
  /// The hold-to-talk input of the engine picked in Learn settings (AC-25,
  /// AC-28, ADR-0009); overridden with a fake in tests.
  SpeechInputProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'speechInputProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$speechInputHash();

  @$internal
  @override
  $ProviderElement<SpeechInput> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SpeechInput create(Ref ref) {
    return speechInput(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpeechInput value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpeechInput>(value),
    );
  }
}

String _$speechInputHash() => r'fe768665d4122671a2a0ab8a9717fbd1d2eb4e87';

/// The app's theme, picked on the App settings page (app-themes, owner
/// 2026-10-17); persisted like [WordDetailModeNotifier]. Starts as
/// [AppThemeId.classic] and switches once the stored value is read.

@ProviderFor(AppThemeNotifier)
final appThemeProvider = AppThemeNotifierProvider._();

/// The app's theme, picked on the App settings page (app-themes, owner
/// 2026-10-17); persisted like [WordDetailModeNotifier]. Starts as
/// [AppThemeId.classic] and switches once the stored value is read.
final class AppThemeNotifierProvider
    extends $NotifierProvider<AppThemeNotifier, AppThemeId> {
  /// The app's theme, picked on the App settings page (app-themes, owner
  /// 2026-10-17); persisted like [WordDetailModeNotifier]. Starts as
  /// [AppThemeId.classic] and switches once the stored value is read.
  AppThemeNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appThemeProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appThemeNotifierHash();

  @$internal
  @override
  AppThemeNotifier create() => AppThemeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeId value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeId>(value),
    );
  }
}

String _$appThemeNotifierHash() => r'6224233ff14b800d30acbad8a25b501db5c323f0';

/// The app's theme, picked on the App settings page (app-themes, owner
/// 2026-10-17); persisted like [WordDetailModeNotifier]. Starts as
/// [AppThemeId.classic] and switches once the stored value is read.

abstract class _$AppThemeNotifier extends $Notifier<AppThemeId> {
  AppThemeId build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeId, AppThemeId>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AppThemeId, AppThemeId>, AppThemeId, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// Adds an import's rows and dialogues, and scene pictures, to a published
/// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
/// uses it is `dialoguePushProvider`.

@ProviderFor(dialoguePushService)
final dialoguePushServiceProvider = DialoguePushServiceProvider._();

/// Adds an import's rows and dialogues, and scene pictures, to a published
/// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
/// uses it is `dialoguePushProvider`.

final class DialoguePushServiceProvider extends $FunctionalProvider<
    DialoguePushService,
    DialoguePushService,
    DialoguePushService> with $Provider<DialoguePushService> {
  /// Adds an import's rows and dialogues, and scene pictures, to a published
  /// session (get-words-from-subtitles-improvment ADR-0005); the outbox that
  /// uses it is `dialoguePushProvider`.
  DialoguePushServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dialoguePushServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dialoguePushServiceHash();

  @$internal
  @override
  $ProviderElement<DialoguePushService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DialoguePushService create(Ref ref) {
    return dialoguePushService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DialoguePushService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DialoguePushService>(value),
    );
  }
}

String _$dialoguePushServiceHash() =>
    r'9bb797404de35c446b3c7b4c3ae6d59018005bba';

/// The "Get dialogues from subtitles" switch in Settings
/// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
/// also asks for film dialogues. Persisted like the word detail mode; off
/// until the stored value is read ([loaded]).

@ProviderFor(DialoguesSettingNotifier)
final dialoguesSettingProvider = DialoguesSettingNotifierProvider._();

/// The "Get dialogues from subtitles" switch in Settings
/// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
/// also asks for film dialogues. Persisted like the word detail mode; off
/// until the stored value is read ([loaded]).
final class DialoguesSettingNotifierProvider
    extends $NotifierProvider<DialoguesSettingNotifier, bool> {
  /// The "Get dialogues from subtitles" switch in Settings
  /// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
  /// also asks for film dialogues. Persisted like the word detail mode; off
  /// until the stored value is read ([loaded]).
  DialoguesSettingNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dialoguesSettingProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dialoguesSettingNotifierHash();

  @$internal
  @override
  DialoguesSettingNotifier create() => DialoguesSettingNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$dialoguesSettingNotifierHash() =>
    r'79a0b0141cc70e6d14eb3a468af48a9fb1300bb6';

/// The "Get dialogues from subtitles" switch in Settings
/// (get-words-from-subtitles-improvment, SCR-03): whether a subtitle import
/// also asks for film dialogues. Persisted like the word detail mode; off
/// until the stored value is read ([loaded]).

abstract class _$DialoguesSettingNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of level and maximum, the "Update with
/// each import" switch, the translator and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.

@ProviderFor(SubtitleImportPrefsNotifier)
final subtitleImportPrefsProvider = SubtitleImportPrefsNotifierProvider._();

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of level and maximum, the "Update with
/// each import" switch, the translator and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.
final class SubtitleImportPrefsNotifierProvider extends $NotifierProvider<
    SubtitleImportPrefsNotifier, SubtitleImportPrefs> {
  /// The subtitle import values in Settings (words-from-subtitles, data-model.md
  /// Device preferences): one set of level and maximum, the "Update with
  /// each import" switch, the translator and the model. Persisted like the word detail mode;
  /// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
  /// values are read ([loaded]). A missing or unknown value keeps its default.
  SubtitleImportPrefsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'subtitleImportPrefsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$subtitleImportPrefsNotifierHash();

  @$internal
  @override
  SubtitleImportPrefsNotifier create() => SubtitleImportPrefsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleImportPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleImportPrefs>(value),
    );
  }
}

String _$subtitleImportPrefsNotifierHash() =>
    r'62a46bccde782750c8ef15315e616046294235bb';

/// The subtitle import values in Settings (words-from-subtitles, data-model.md
/// Device preferences): one set of level and maximum, the "Update with
/// each import" switch, the translator and the model. Persisted like the word detail mode;
/// starts at [SubtitleImportPrefs.firstLaunch] and switches once the stored
/// values are read ([loaded]). A missing or unknown value keeps its default.

abstract class _$SubtitleImportPrefsNotifier
    extends $Notifier<SubtitleImportPrefs> {
  SubtitleImportPrefs build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SubtitleImportPrefs, SubtitleImportPrefs>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<SubtitleImportPrefs, SubtitleImportPrefs>,
        SubtitleImportPrefs,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).

@ProviderFor(PhotoTabTopNotifier)
final photoTabTopProvider = PhotoTabTopNotifierProvider._();

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).
final class PhotoTabTopNotifierProvider
    extends $NotifierProvider<PhotoTabTopNotifier, double> {
  /// The photo tab's top, in logical pixels from the top of the main screen's
  /// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
  /// up or down and the height is kept across restarts (spec AC-14). A display
  /// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).
  PhotoTabTopNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'photoTabTopProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$photoTabTopNotifierHash();

  @$internal
  @override
  PhotoTabTopNotifier create() => PhotoTabTopNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$photoTabTopNotifierHash() =>
    r'64d44d57f4fa1cfe9a9043c6528efcacf16be923';

/// The photo tab's top, in logical pixels from the top of the main screen's
/// words page (side-bar-for-main-screen, sad §4). The learner drags the tab
/// up or down and the height is kept across restarts (spec AC-14). A display
/// preference: never on `WordCollection`. Clamped on use by the tab ([clamp]).

abstract class _$PhotoTabTopNotifier extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<double, double>, double, Object?, Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The Words settings' Liquid glass sliders (liquid-glass-tuning, owner
/// 2026-10-19), for the photo tab and the half-open panel. Persisted like
/// [WordDetailModeNotifier], one preferences key per slider; a display
/// preference, never on `WordCollection`. Starts at 100% and switches once
/// the stored values are read ([loaded]).

@ProviderFor(LiquidGlassTuningNotifier)
final liquidGlassTuningProvider = LiquidGlassTuningNotifierProvider._();

/// The Words settings' Liquid glass sliders (liquid-glass-tuning, owner
/// 2026-10-19), for the photo tab and the half-open panel. Persisted like
/// [WordDetailModeNotifier], one preferences key per slider; a display
/// preference, never on `WordCollection`. Starts at 100% and switches once
/// the stored values are read ([loaded]).
final class LiquidGlassTuningNotifierProvider
    extends $NotifierProvider<LiquidGlassTuningNotifier, LiquidGlassTuning> {
  /// The Words settings' Liquid glass sliders (liquid-glass-tuning, owner
  /// 2026-10-19), for the photo tab and the half-open panel. Persisted like
  /// [WordDetailModeNotifier], one preferences key per slider; a display
  /// preference, never on `WordCollection`. Starts at 100% and switches once
  /// the stored values are read ([loaded]).
  LiquidGlassTuningNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'liquidGlassTuningProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$liquidGlassTuningNotifierHash();

  @$internal
  @override
  LiquidGlassTuningNotifier create() => LiquidGlassTuningNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiquidGlassTuning value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiquidGlassTuning>(value),
    );
  }
}

String _$liquidGlassTuningNotifierHash() =>
    r'e3ec385b28a7cd33dd2c48d21cc9669fe6cae99a';

/// The Words settings' Liquid glass sliders (liquid-glass-tuning, owner
/// 2026-10-19), for the photo tab and the half-open panel. Persisted like
/// [WordDetailModeNotifier], one preferences key per slider; a display
/// preference, never on `WordCollection`. Starts at 100% and switches once
/// the stored values are read ([loaded]).

abstract class _$LiquidGlassTuningNotifier
    extends $Notifier<LiquidGlassTuning> {
  LiquidGlassTuning build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LiquidGlassTuning, LiquidGlassTuning>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LiquidGlassTuning, LiquidGlassTuning>,
        LiquidGlassTuning,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

/// The tags the learner applied from the Collections filter sheet, newest
/// first, at most [keep] (filter-sheet-pills, owner 2026-10-18). Persisted
/// like [WordDetailModeNotifier] under one preferences key, each entry
/// `kind|text`; they feed the sheet's Popular line ([quickTags]).

@ProviderFor(RecentFilterTagsNotifier)
final recentFilterTagsProvider = RecentFilterTagsNotifierProvider._();

/// The tags the learner applied from the Collections filter sheet, newest
/// first, at most [keep] (filter-sheet-pills, owner 2026-10-18). Persisted
/// like [WordDetailModeNotifier] under one preferences key, each entry
/// `kind|text`; they feed the sheet's Popular line ([quickTags]).
final class RecentFilterTagsNotifierProvider
    extends $NotifierProvider<RecentFilterTagsNotifier, List<QuickTag>> {
  /// The tags the learner applied from the Collections filter sheet, newest
  /// first, at most [keep] (filter-sheet-pills, owner 2026-10-18). Persisted
  /// like [WordDetailModeNotifier] under one preferences key, each entry
  /// `kind|text`; they feed the sheet's Popular line ([quickTags]).
  RecentFilterTagsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recentFilterTagsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recentFilterTagsNotifierHash();

  @$internal
  @override
  RecentFilterTagsNotifier create() => RecentFilterTagsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<QuickTag> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<QuickTag>>(value),
    );
  }
}

String _$recentFilterTagsNotifierHash() =>
    r'77536d2475125cb27b9f63ec9d2caef380839c1d';

/// The tags the learner applied from the Collections filter sheet, newest
/// first, at most [keep] (filter-sheet-pills, owner 2026-10-18). Persisted
/// like [WordDetailModeNotifier] under one preferences key, each entry
/// `kind|text`; they feed the sheet's Popular line ([quickTags]).

abstract class _$RecentFilterTagsNotifier extends $Notifier<List<QuickTag>> {
  List<QuickTag> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<QuickTag>, List<QuickTag>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<QuickTag>, List<QuickTag>>,
        List<QuickTag>,
        Object?,
        Object?>;
    return element.handleCreate(ref, build);
  }
}

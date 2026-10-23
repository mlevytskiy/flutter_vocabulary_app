// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$learningSessionHash() => r'f63cfee62230e202ce57c4fea4955f370c70d42f';

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

abstract class _$LearningSession
    extends BuildlessAutoDisposeNotifier<LearningSessionState> {
  late final String? collectionId;

  LearningSessionState build(
    String? collectionId,
  );
}

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.
///
/// Copied from [LearningSession].
@ProviderFor(LearningSession)
const learningSessionProvider = LearningSessionFamily();

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.
///
/// Copied from [LearningSession].
class LearningSessionFamily extends Family<LearningSessionState> {
  /// One learning session of a collection (learn-redesign ADR-0004; AC-02,
  /// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
  /// collection, as in `exerciseWords`.
  ///
  /// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
  /// exercise types per step, builds step 1's pages and shows the first one;
  /// steps 2 and 3 load in the background and are awaited when the first word
  /// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
  /// unused page of that step holding the word, rotating exercise types. AI
  /// data is fetched in batches of at most [batchSize] words. Leaving a
  /// session changes no box (AC-16); only finishing writes them, once.
  ///
  /// Copied from [LearningSession].
  const LearningSessionFamily();

  /// One learning session of a collection (learn-redesign ADR-0004; AC-02,
  /// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
  /// collection, as in `exerciseWords`.
  ///
  /// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
  /// exercise types per step, builds step 1's pages and shows the first one;
  /// steps 2 and 3 load in the background and are awaited when the first word
  /// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
  /// unused page of that step holding the word, rotating exercise types. AI
  /// data is fetched in batches of at most [batchSize] words. Leaving a
  /// session changes no box (AC-16); only finishing writes them, once.
  ///
  /// Copied from [LearningSession].
  LearningSessionProvider call(
    String? collectionId,
  ) {
    return LearningSessionProvider(
      collectionId,
    );
  }

  @override
  LearningSessionProvider getProviderOverride(
    covariant LearningSessionProvider provider,
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
  String? get name => r'learningSessionProvider';
}

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.
///
/// Copied from [LearningSession].
class LearningSessionProvider extends AutoDisposeNotifierProviderImpl<
    LearningSession, LearningSessionState> {
  /// One learning session of a collection (learn-redesign ADR-0004; AC-02,
  /// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
  /// collection, as in `exerciseWords`.
  ///
  /// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
  /// exercise types per step, builds step 1's pages and shows the first one;
  /// steps 2 and 3 load in the background and are awaited when the first word
  /// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
  /// unused page of that step holding the word, rotating exercise types. AI
  /// data is fetched in batches of at most [batchSize] words. Leaving a
  /// session changes no box (AC-16); only finishing writes them, once.
  ///
  /// Copied from [LearningSession].
  LearningSessionProvider(
    String? collectionId,
  ) : this._internal(
          () => LearningSession()..collectionId = collectionId,
          from: learningSessionProvider,
          name: r'learningSessionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$learningSessionHash,
          dependencies: LearningSessionFamily._dependencies,
          allTransitiveDependencies:
              LearningSessionFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  LearningSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
  }) : super.internal();

  final String? collectionId;

  @override
  LearningSessionState runNotifierBuild(
    covariant LearningSession notifier,
  ) {
    return notifier.build(
      collectionId,
    );
  }

  @override
  Override overrideWith(LearningSession Function() create) {
    return ProviderOverride(
      origin: this,
      override: LearningSessionProvider._internal(
        () => create()..collectionId = collectionId,
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
  AutoDisposeNotifierProviderElement<LearningSession, LearningSessionState>
      createElement() {
    return _LearningSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LearningSessionProvider &&
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
mixin LearningSessionRef
    on AutoDisposeNotifierProviderRef<LearningSessionState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;
}

class _LearningSessionProviderElement
    extends AutoDisposeNotifierProviderElement<LearningSession,
        LearningSessionState> with LearningSessionRef {
  _LearningSessionProviderElement(super.provider);

  @override
  String? get collectionId => (origin as LearningSessionProvider).collectionId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

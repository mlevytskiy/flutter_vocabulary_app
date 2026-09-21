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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

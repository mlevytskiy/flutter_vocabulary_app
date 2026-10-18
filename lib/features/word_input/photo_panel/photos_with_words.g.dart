// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photos_with_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sourcesWithWordsHash() => r'7d1f6385d6acb7722ff23218f0f4e43aecbad51c';

/// The current session's sources with words that the photo panel lists,
/// photos and sets mixed, oldest first by `takenAt` (sources added at the
/// same time keep the order of `WordCollection.sources`), derived in one pass over
/// the rows (sad §4). Only the current session is read, so another session's
/// sources never appear (spec AC-16); a row whose word is cleared does not
/// count (spec AC-15).
///
/// Copied from [sourcesWithWords].
@ProviderFor(sourcesWithWords)
final sourcesWithWordsProvider =
    AutoDisposeProvider<List<SourceWithWords>>.internal(
  sourcesWithWords,
  name: r'sourcesWithWordsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sourcesWithWordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SourcesWithWordsRef = AutoDisposeProviderRef<List<SourceWithWords>>;
String _$storedSourcesWithWordsHash() =>
    r'7dc6f9fe963f856154206a18a656c3d7ceabf201';

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

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).
///
/// Copied from [storedSourcesWithWords].
@ProviderFor(storedSourcesWithWords)
const storedSourcesWithWordsProvider = StoredSourcesWithWordsFamily();

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).
///
/// Copied from [storedSourcesWithWords].
class StoredSourcesWithWordsFamily extends Family<List<SourceWithWords>> {
  /// The sources with words of a stored collection, e.g. one the Words screen
  /// shows from History, read-only (words-photo-panel).
  ///
  /// Copied from [storedSourcesWithWords].
  const StoredSourcesWithWordsFamily();

  /// The sources with words of a stored collection, e.g. one the Words screen
  /// shows from History, read-only (words-photo-panel).
  ///
  /// Copied from [storedSourcesWithWords].
  StoredSourcesWithWordsProvider call(
    String collectionId,
  ) {
    return StoredSourcesWithWordsProvider(
      collectionId,
    );
  }

  @override
  StoredSourcesWithWordsProvider getProviderOverride(
    covariant StoredSourcesWithWordsProvider provider,
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
  String? get name => r'storedSourcesWithWordsProvider';
}

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).
///
/// Copied from [storedSourcesWithWords].
class StoredSourcesWithWordsProvider
    extends AutoDisposeProvider<List<SourceWithWords>> {
  /// The sources with words of a stored collection, e.g. one the Words screen
  /// shows from History, read-only (words-photo-panel).
  ///
  /// Copied from [storedSourcesWithWords].
  StoredSourcesWithWordsProvider(
    String collectionId,
  ) : this._internal(
          (ref) => storedSourcesWithWords(
            ref as StoredSourcesWithWordsRef,
            collectionId,
          ),
          from: storedSourcesWithWordsProvider,
          name: r'storedSourcesWithWordsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$storedSourcesWithWordsHash,
          dependencies: StoredSourcesWithWordsFamily._dependencies,
          allTransitiveDependencies:
              StoredSourcesWithWordsFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  StoredSourcesWithWordsProvider._internal(
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
    List<SourceWithWords> Function(StoredSourcesWithWordsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StoredSourcesWithWordsProvider._internal(
        (ref) => create(ref as StoredSourcesWithWordsRef),
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
  AutoDisposeProviderElement<List<SourceWithWords>> createElement() {
    return _StoredSourcesWithWordsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StoredSourcesWithWordsProvider &&
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
mixin StoredSourcesWithWordsRef
    on AutoDisposeProviderRef<List<SourceWithWords>> {
  /// The parameter `collectionId` of this provider.
  String get collectionId;
}

class _StoredSourcesWithWordsProviderElement
    extends AutoDisposeProviderElement<List<SourceWithWords>>
    with StoredSourcesWithWordsRef {
  _StoredSourcesWithWordsProviderElement(super.provider);

  @override
  String get collectionId =>
      (origin as StoredSourcesWithWordsProvider).collectionId;
}

String _$photosWithWordsHash() => r'0860e55a8b2da02dbdf17103901679a5f2f7d16b';

/// The current session's photos with words, oldest first: the photos of
/// [sourcesWithWords]. Full-open shows only these (spec AC-21).
///
/// Copied from [photosWithWords].
@ProviderFor(photosWithWords)
final photosWithWordsProvider =
    AutoDisposeProvider<List<PhotoWithWords>>.internal(
  photosWithWords,
  name: r'photosWithWordsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$photosWithWordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PhotosWithWordsRef = AutoDisposeProviderRef<List<PhotoWithWords>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

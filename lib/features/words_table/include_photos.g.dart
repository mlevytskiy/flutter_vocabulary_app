// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'include_photos.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$includePhotosHash() => r'c4b02b59ed32d72e34d0afb8cb50974335fc991e';

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

abstract class _$IncludePhotos extends BuildlessAutoDisposeNotifier<bool> {
  late final String? collectionId;

  bool build(
    String? collectionId,
  );
}

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.
///
/// Copied from [IncludePhotos].
@ProviderFor(IncludePhotos)
const includePhotosProvider = IncludePhotosFamily();

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.
///
/// Copied from [IncludePhotos].
class IncludePhotosFamily extends Family<bool> {
  /// The "Include photos (N)" switch, now in the Words screen's settings
  /// (words-photo-panel): on until switched off, for the Words screen of
  /// [collectionId] (null: the current collection). Not saved: it lives while
  /// that Words screen does, which watches it, as it did in its `State`.
  /// Sets (import-from-quizlet) are not behind it: they are always sent.
  ///
  /// Copied from [IncludePhotos].
  const IncludePhotosFamily();

  /// The "Include photos (N)" switch, now in the Words screen's settings
  /// (words-photo-panel): on until switched off, for the Words screen of
  /// [collectionId] (null: the current collection). Not saved: it lives while
  /// that Words screen does, which watches it, as it did in its `State`.
  /// Sets (import-from-quizlet) are not behind it: they are always sent.
  ///
  /// Copied from [IncludePhotos].
  IncludePhotosProvider call(
    String? collectionId,
  ) {
    return IncludePhotosProvider(
      collectionId,
    );
  }

  @override
  IncludePhotosProvider getProviderOverride(
    covariant IncludePhotosProvider provider,
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
  String? get name => r'includePhotosProvider';
}

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.
///
/// Copied from [IncludePhotos].
class IncludePhotosProvider
    extends AutoDisposeNotifierProviderImpl<IncludePhotos, bool> {
  /// The "Include photos (N)" switch, now in the Words screen's settings
  /// (words-photo-panel): on until switched off, for the Words screen of
  /// [collectionId] (null: the current collection). Not saved: it lives while
  /// that Words screen does, which watches it, as it did in its `State`.
  /// Sets (import-from-quizlet) are not behind it: they are always sent.
  ///
  /// Copied from [IncludePhotos].
  IncludePhotosProvider(
    String? collectionId,
  ) : this._internal(
          () => IncludePhotos()..collectionId = collectionId,
          from: includePhotosProvider,
          name: r'includePhotosProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$includePhotosHash,
          dependencies: IncludePhotosFamily._dependencies,
          allTransitiveDependencies:
              IncludePhotosFamily._allTransitiveDependencies,
          collectionId: collectionId,
        );

  IncludePhotosProvider._internal(
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
  bool runNotifierBuild(
    covariant IncludePhotos notifier,
  ) {
    return notifier.build(
      collectionId,
    );
  }

  @override
  Override overrideWith(IncludePhotos Function() create) {
    return ProviderOverride(
      origin: this,
      override: IncludePhotosProvider._internal(
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
  AutoDisposeNotifierProviderElement<IncludePhotos, bool> createElement() {
    return _IncludePhotosProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncludePhotosProvider && other.collectionId == collectionId;
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
mixin IncludePhotosRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;
}

class _IncludePhotosProviderElement
    extends AutoDisposeNotifierProviderElement<IncludePhotos, bool>
    with IncludePhotosRef {
  _IncludePhotosProviderElement(super.provider);

  @override
  String? get collectionId => (origin as IncludePhotosProvider).collectionId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

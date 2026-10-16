// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fill_the_gaps_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fillTheGapsHash() => r'10d500db80a34c553ce0dc6a1da27987b5425faf';

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

abstract class _$FillTheGaps
    extends BuildlessAutoDisposeAsyncNotifier<FillState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<FillState> build(
    String? collectionId,
    String groupId,
  );
}

/// See also [FillTheGaps].
@ProviderFor(FillTheGaps)
const fillTheGapsProvider = FillTheGapsFamily();

/// See also [FillTheGaps].
class FillTheGapsFamily extends Family<AsyncValue<FillState>> {
  /// See also [FillTheGaps].
  const FillTheGapsFamily();

  /// See also [FillTheGaps].
  FillTheGapsProvider call(
    String? collectionId,
    String groupId,
  ) {
    return FillTheGapsProvider(
      collectionId,
      groupId,
    );
  }

  @override
  FillTheGapsProvider getProviderOverride(
    covariant FillTheGapsProvider provider,
  ) {
    return call(
      provider.collectionId,
      provider.groupId,
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
  String? get name => r'fillTheGapsProvider';
}

/// See also [FillTheGaps].
class FillTheGapsProvider
    extends AutoDisposeAsyncNotifierProviderImpl<FillTheGaps, FillState> {
  /// See also [FillTheGaps].
  FillTheGapsProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => FillTheGaps()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: fillTheGapsProvider,
          name: r'fillTheGapsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$fillTheGapsHash,
          dependencies: FillTheGapsFamily._dependencies,
          allTransitiveDependencies:
              FillTheGapsFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  FillTheGapsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.collectionId,
    required this.groupId,
  }) : super.internal();

  final String? collectionId;
  final String groupId;

  @override
  FutureOr<FillState> runNotifierBuild(
    covariant FillTheGaps notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(FillTheGaps Function() create) {
    return ProviderOverride(
      origin: this,
      override: FillTheGapsProvider._internal(
        () => create()
          ..collectionId = collectionId
          ..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        collectionId: collectionId,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<FillTheGaps, FillState>
      createElement() {
    return _FillTheGapsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FillTheGapsProvider &&
        other.collectionId == collectionId &&
        other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, collectionId.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FillTheGapsRef on AutoDisposeAsyncNotifierProviderRef<FillState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _FillTheGapsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FillTheGaps, FillState>
    with FillTheGapsRef {
  _FillTheGapsProviderElement(super.provider);

  @override
  String? get collectionId => (origin as FillTheGapsProvider).collectionId;
  @override
  String get groupId => (origin as FillTheGapsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

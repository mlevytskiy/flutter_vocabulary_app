// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fill_the_gaps_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fillTheGapsHash() => r'a2005b1c5382abb031324606728c21a3096a60b2';

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
  late final String? sessionId;
  late final String groupId;

  FutureOr<FillState> build(
    String? sessionId,
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
    String? sessionId,
    String groupId,
  ) {
    return FillTheGapsProvider(
      sessionId,
      groupId,
    );
  }

  @override
  FillTheGapsProvider getProviderOverride(
    covariant FillTheGapsProvider provider,
  ) {
    return call(
      provider.sessionId,
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
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => FillTheGaps()
            ..sessionId = sessionId
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
          sessionId: sessionId,
          groupId: groupId,
        );

  FillTheGapsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
    required this.groupId,
  }) : super.internal();

  final String? sessionId;
  final String groupId;

  @override
  FutureOr<FillState> runNotifierBuild(
    covariant FillTheGaps notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(FillTheGaps Function() create) {
    return ProviderOverride(
      origin: this,
      override: FillTheGapsProvider._internal(
        () => create()
          ..sessionId = sessionId
          ..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
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
        other.sessionId == sessionId &&
        other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FillTheGapsRef on AutoDisposeAsyncNotifierProviderRef<FillState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _FillTheGapsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FillTheGaps, FillState>
    with FillTheGapsRef {
  _FillTheGapsProviderElement(super.provider);

  @override
  String? get sessionId => (origin as FillTheGapsProvider).sessionId;
  @override
  String get groupId => (origin as FillTheGapsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

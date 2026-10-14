// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remember_or_not_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rememberOrNotHash() => r'd0d2a66af1e9d46495c882d2e2adf751b08e45f1';

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

abstract class _$RememberOrNot
    extends BuildlessAutoDisposeAsyncNotifier<RememberState> {
  late final String? sessionId;
  late final String groupId;

  FutureOr<RememberState> build(
    String? sessionId,
    String groupId,
  );
}

/// See also [RememberOrNot].
@ProviderFor(RememberOrNot)
const rememberOrNotProvider = RememberOrNotFamily();

/// See also [RememberOrNot].
class RememberOrNotFamily extends Family<AsyncValue<RememberState>> {
  /// See also [RememberOrNot].
  const RememberOrNotFamily();

  /// See also [RememberOrNot].
  RememberOrNotProvider call(
    String? sessionId,
    String groupId,
  ) {
    return RememberOrNotProvider(
      sessionId,
      groupId,
    );
  }

  @override
  RememberOrNotProvider getProviderOverride(
    covariant RememberOrNotProvider provider,
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
  String? get name => r'rememberOrNotProvider';
}

/// See also [RememberOrNot].
class RememberOrNotProvider
    extends AutoDisposeAsyncNotifierProviderImpl<RememberOrNot, RememberState> {
  /// See also [RememberOrNot].
  RememberOrNotProvider(
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => RememberOrNot()
            ..sessionId = sessionId
            ..groupId = groupId,
          from: rememberOrNotProvider,
          name: r'rememberOrNotProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$rememberOrNotHash,
          dependencies: RememberOrNotFamily._dependencies,
          allTransitiveDependencies:
              RememberOrNotFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  RememberOrNotProvider._internal(
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
  FutureOr<RememberState> runNotifierBuild(
    covariant RememberOrNot notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(RememberOrNot Function() create) {
    return ProviderOverride(
      origin: this,
      override: RememberOrNotProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<RememberOrNot, RememberState>
      createElement() {
    return _RememberOrNotProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RememberOrNotProvider &&
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
mixin RememberOrNotRef on AutoDisposeAsyncNotifierProviderRef<RememberState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _RememberOrNotProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<RememberOrNot,
        RememberState> with RememberOrNotRef {
  _RememberOrNotProviderElement(super.provider);

  @override
  String? get sessionId => (origin as RememberOrNotProvider).sessionId;
  @override
  String get groupId => (origin as RememberOrNotProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

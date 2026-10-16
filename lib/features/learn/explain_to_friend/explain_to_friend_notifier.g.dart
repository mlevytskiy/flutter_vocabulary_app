// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explain_to_friend_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$explainToFriendHash() => r'96edc3b1b644f8613576de34f6a288d523e870c7';

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

abstract class _$ExplainToFriend
    extends BuildlessAutoDisposeAsyncNotifier<ExplainState> {
  late final String? collectionId;
  late final String groupId;

  FutureOr<ExplainState> build(
    String? collectionId,
    String groupId,
  );
}

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.
///
/// Copied from [ExplainToFriend].
@ProviderFor(ExplainToFriend)
const explainToFriendProvider = ExplainToFriendFamily();

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.
///
/// Copied from [ExplainToFriend].
class ExplainToFriendFamily extends Family<AsyncValue<ExplainState>> {
  /// The explain-to-friend exam of one group (learn-explain-to-friend). No
  /// Worker data: only the group's words are read. Each final Type word records
  /// its result through [examResultSinkProvider] at once (S-55); friend answers
  /// are shown in the summary only (S-64); nothing else is saved.
  ///
  /// Copied from [ExplainToFriend].
  const ExplainToFriendFamily();

  /// The explain-to-friend exam of one group (learn-explain-to-friend). No
  /// Worker data: only the group's words are read. Each final Type word records
  /// its result through [examResultSinkProvider] at once (S-55); friend answers
  /// are shown in the summary only (S-64); nothing else is saved.
  ///
  /// Copied from [ExplainToFriend].
  ExplainToFriendProvider call(
    String? collectionId,
    String groupId,
  ) {
    return ExplainToFriendProvider(
      collectionId,
      groupId,
    );
  }

  @override
  ExplainToFriendProvider getProviderOverride(
    covariant ExplainToFriendProvider provider,
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
  String? get name => r'explainToFriendProvider';
}

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.
///
/// Copied from [ExplainToFriend].
class ExplainToFriendProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ExplainToFriend, ExplainState> {
  /// The explain-to-friend exam of one group (learn-explain-to-friend). No
  /// Worker data: only the group's words are read. Each final Type word records
  /// its result through [examResultSinkProvider] at once (S-55); friend answers
  /// are shown in the summary only (S-64); nothing else is saved.
  ///
  /// Copied from [ExplainToFriend].
  ExplainToFriendProvider(
    String? collectionId,
    String groupId,
  ) : this._internal(
          () => ExplainToFriend()
            ..collectionId = collectionId
            ..groupId = groupId,
          from: explainToFriendProvider,
          name: r'explainToFriendProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$explainToFriendHash,
          dependencies: ExplainToFriendFamily._dependencies,
          allTransitiveDependencies:
              ExplainToFriendFamily._allTransitiveDependencies,
          collectionId: collectionId,
          groupId: groupId,
        );

  ExplainToFriendProvider._internal(
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
  FutureOr<ExplainState> runNotifierBuild(
    covariant ExplainToFriend notifier,
  ) {
    return notifier.build(
      collectionId,
      groupId,
    );
  }

  @override
  Override overrideWith(ExplainToFriend Function() create) {
    return ProviderOverride(
      origin: this,
      override: ExplainToFriendProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ExplainToFriend, ExplainState>
      createElement() {
    return _ExplainToFriendProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExplainToFriendProvider &&
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
mixin ExplainToFriendRef on AutoDisposeAsyncNotifierProviderRef<ExplainState> {
  /// The parameter `collectionId` of this provider.
  String? get collectionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _ExplainToFriendProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ExplainToFriend,
        ExplainState> with ExplainToFriendRef {
  _ExplainToFriendProviderElement(super.provider);

  @override
  String? get collectionId => (origin as ExplainToFriendProvider).collectionId;
  @override
  String get groupId => (origin as ExplainToFriendProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

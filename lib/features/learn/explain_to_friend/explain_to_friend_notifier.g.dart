// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explain_to_friend_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$explainToFriendHash() => r'aebfe74b5cc50971851dfa963cc1431ad2efa482';

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
  late final String? sessionId;
  late final String groupId;

  FutureOr<ExplainState> build(
    String? sessionId,
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
    String? sessionId,
    String groupId,
  ) {
    return ExplainToFriendProvider(
      sessionId,
      groupId,
    );
  }

  @override
  ExplainToFriendProvider getProviderOverride(
    covariant ExplainToFriendProvider provider,
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
    String? sessionId,
    String groupId,
  ) : this._internal(
          () => ExplainToFriend()
            ..sessionId = sessionId
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
          sessionId: sessionId,
          groupId: groupId,
        );

  ExplainToFriendProvider._internal(
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
  FutureOr<ExplainState> runNotifierBuild(
    covariant ExplainToFriend notifier,
  ) {
    return notifier.build(
      sessionId,
      groupId,
    );
  }

  @override
  Override overrideWith(ExplainToFriend Function() create) {
    return ProviderOverride(
      origin: this,
      override: ExplainToFriendProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ExplainToFriend, ExplainState>
      createElement() {
    return _ExplainToFriendProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExplainToFriendProvider &&
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
mixin ExplainToFriendRef on AutoDisposeAsyncNotifierProviderRef<ExplainState> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _ExplainToFriendProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ExplainToFriend,
        ExplainState> with ExplainToFriendRef {
  _ExplainToFriendProviderElement(super.provider);

  @override
  String? get sessionId => (origin as ExplainToFriendProvider).sessionId;
  @override
  String get groupId => (origin as ExplainToFriendProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

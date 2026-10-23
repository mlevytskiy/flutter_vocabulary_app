// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explain_to_friend_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.

@ProviderFor(ExplainToFriend)
final explainToFriendProvider = ExplainToFriendFamily._();

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.
final class ExplainToFriendProvider
    extends $AsyncNotifierProvider<ExplainToFriend, ExplainState> {
  /// The explain-to-friend exam of one group (learn-explain-to-friend). No
  /// Worker data: only the group's words are read. Each final Type word records
  /// its result through [examResultSinkProvider] at once (S-55); friend answers
  /// are shown in the summary only (S-64); nothing else is saved.
  ExplainToFriendProvider._(
      {required ExplainToFriendFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'explainToFriendProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$explainToFriendHash();

  @override
  String toString() {
    return r'explainToFriendProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ExplainToFriend create() => ExplainToFriend();

  @override
  bool operator ==(Object other) {
    return other is ExplainToFriendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$explainToFriendHash() => r'71c75b89a539c943f034b1925cf580224931f030';

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.

final class ExplainToFriendFamily extends $Family
    with
        $ClassFamilyOverride<
            ExplainToFriend,
            AsyncValue<ExplainState>,
            ExplainState,
            FutureOr<ExplainState>,
            (
              String?,
              String,
            )> {
  ExplainToFriendFamily._()
      : super(
          retry: null,
          name: r'explainToFriendProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The explain-to-friend exam of one group (learn-explain-to-friend). No
  /// Worker data: only the group's words are read. Each final Type word records
  /// its result through [examResultSinkProvider] at once (S-55); friend answers
  /// are shown in the summary only (S-64); nothing else is saved.

  ExplainToFriendProvider call(
    String? collectionId,
    String groupId,
  ) =>
      ExplainToFriendProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'explainToFriendProvider';
}

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.

abstract class _$ExplainToFriend extends $AsyncNotifier<ExplainState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<ExplainState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ExplainState>, ExplainState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ExplainState>, ExplainState>,
        AsyncValue<ExplainState>,
        Object?,
        Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args.$1,
              _$args.$2,
            ));
  }
}

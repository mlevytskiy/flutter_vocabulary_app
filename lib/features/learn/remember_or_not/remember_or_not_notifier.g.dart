// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remember_or_not_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RememberOrNot)
final rememberOrNotProvider = RememberOrNotFamily._();

final class RememberOrNotProvider
    extends $AsyncNotifierProvider<RememberOrNot, RememberState> {
  RememberOrNotProvider._(
      {required RememberOrNotFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'rememberOrNotProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$rememberOrNotHash();

  @override
  String toString() {
    return r'rememberOrNotProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  RememberOrNot create() => RememberOrNot();

  @override
  bool operator ==(Object other) {
    return other is RememberOrNotProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rememberOrNotHash() => r'9eb977dbc5b8e2d4044a937d858c83b4eff97f34';

final class RememberOrNotFamily extends $Family
    with
        $ClassFamilyOverride<
            RememberOrNot,
            AsyncValue<RememberState>,
            RememberState,
            FutureOr<RememberState>,
            (
              String?,
              String,
            )> {
  RememberOrNotFamily._()
      : super(
          retry: null,
          name: r'rememberOrNotProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  RememberOrNotProvider call(
    String? collectionId,
    String groupId,
  ) =>
      RememberOrNotProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'rememberOrNotProvider';
}

abstract class _$RememberOrNot extends $AsyncNotifier<RememberState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<RememberState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RememberState>, RememberState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<RememberState>, RememberState>,
        AsyncValue<RememberState>,
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

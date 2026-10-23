// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fill_the_gaps_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FillTheGaps)
final fillTheGapsProvider = FillTheGapsFamily._();

final class FillTheGapsProvider
    extends $AsyncNotifierProvider<FillTheGaps, FillState> {
  FillTheGapsProvider._(
      {required FillTheGapsFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'fillTheGapsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$fillTheGapsHash();

  @override
  String toString() {
    return r'fillTheGapsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  FillTheGaps create() => FillTheGaps();

  @override
  bool operator ==(Object other) {
    return other is FillTheGapsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fillTheGapsHash() => r'5c4b61af0c0b54d1b7053e9c5caebf201e4697bd';

final class FillTheGapsFamily extends $Family
    with
        $ClassFamilyOverride<
            FillTheGaps,
            AsyncValue<FillState>,
            FillState,
            FutureOr<FillState>,
            (
              String?,
              String,
            )> {
  FillTheGapsFamily._()
      : super(
          retry: null,
          name: r'fillTheGapsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  FillTheGapsProvider call(
    String? collectionId,
    String groupId,
  ) =>
      FillTheGapsProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'fillTheGapsProvider';
}

abstract class _$FillTheGaps extends $AsyncNotifier<FillState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<FillState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FillState>, FillState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<FillState>, FillState>,
        AsyncValue<FillState>,
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

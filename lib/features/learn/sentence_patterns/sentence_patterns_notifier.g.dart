// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_patterns_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SentencePatterns)
final sentencePatternsProvider = SentencePatternsFamily._();

final class SentencePatternsProvider
    extends $AsyncNotifierProvider<SentencePatterns, PatternsState> {
  SentencePatternsProvider._(
      {required SentencePatternsFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'sentencePatternsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sentencePatternsHash();

  @override
  String toString() {
    return r'sentencePatternsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SentencePatterns create() => SentencePatterns();

  @override
  bool operator ==(Object other) {
    return other is SentencePatternsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sentencePatternsHash() => r'391e22e964727b20d186cd6ba46493451df125e7';

final class SentencePatternsFamily extends $Family
    with
        $ClassFamilyOverride<
            SentencePatterns,
            AsyncValue<PatternsState>,
            PatternsState,
            FutureOr<PatternsState>,
            (
              String?,
              String,
            )> {
  SentencePatternsFamily._()
      : super(
          retry: null,
          name: r'sentencePatternsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  SentencePatternsProvider call(
    String? collectionId,
    String groupId,
  ) =>
      SentencePatternsProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'sentencePatternsProvider';
}

abstract class _$SentencePatterns extends $AsyncNotifier<PatternsState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<PatternsState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PatternsState>, PatternsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PatternsState>, PatternsState>,
        AsyncValue<PatternsState>,
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

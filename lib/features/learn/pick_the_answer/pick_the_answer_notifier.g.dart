// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pick_the_answer_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.

@ProviderFor(PickTheAnswer)
final pickTheAnswerProvider = PickTheAnswerFamily._();

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.
final class PickTheAnswerProvider
    extends $AsyncNotifierProvider<PickTheAnswer, PickState> {
  /// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
  /// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
  /// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
  /// the round.
  PickTheAnswerProvider._(
      {required PickTheAnswerFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'pickTheAnswerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$pickTheAnswerHash();

  @override
  String toString() {
    return r'pickTheAnswerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  PickTheAnswer create() => PickTheAnswer();

  @override
  bool operator ==(Object other) {
    return other is PickTheAnswerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pickTheAnswerHash() => r'796bae0102beb20dd24fd14e04829df6815e3ca6';

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.

final class PickTheAnswerFamily extends $Family
    with
        $ClassFamilyOverride<
            PickTheAnswer,
            AsyncValue<PickState>,
            PickState,
            FutureOr<PickState>,
            (
              String?,
              String,
            )> {
  PickTheAnswerFamily._()
      : super(
          retry: null,
          name: r'pickTheAnswerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
  /// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
  /// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
  /// the round.

  PickTheAnswerProvider call(
    String? collectionId,
    String groupId,
  ) =>
      PickTheAnswerProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'pickTheAnswerProvider';
}

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.

abstract class _$PickTheAnswer extends $AsyncNotifier<PickState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<PickState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PickState>, PickState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PickState>, PickState>,
        AsyncValue<PickState>,
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

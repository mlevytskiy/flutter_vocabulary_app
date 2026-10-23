// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.

@ProviderFor(Quiz)
final quizProvider = QuizFamily._();

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.
final class QuizProvider extends $AsyncNotifierProvider<Quiz, QuizState> {
  /// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
  /// questions. Each final answer records the word's result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  /// Auto-disposed, so leaving the screen forgets the attempt.
  QuizProvider._(
      {required QuizFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'quizProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$quizHash();

  @override
  String toString() {
    return r'quizProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  Quiz create() => Quiz();

  @override
  bool operator ==(Object other) {
    return other is QuizProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$quizHash() => r'9fcd67f7fa881c70d72efb82841bc3e5393e296c';

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.

final class QuizFamily extends $Family
    with
        $ClassFamilyOverride<
            Quiz,
            AsyncValue<QuizState>,
            QuizState,
            FutureOr<QuizState>,
            (
              String?,
              String,
            )> {
  QuizFamily._()
      : super(
          retry: null,
          name: r'quizProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
  /// questions. Each final answer records the word's result through
  /// [examResultSinkProvider] at once (S-55); nothing else is saved.
  /// Auto-disposed, so leaving the screen forgets the attempt.

  QuizProvider call(
    String? collectionId,
    String groupId,
  ) =>
      QuizProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'quizProvider';
}

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.

abstract class _$Quiz extends $AsyncNotifier<QuizState> {
  late final _$args = ref.$arg as (
    String?,
    String,
  );
  String? get collectionId => _$args.$1;
  String get groupId => _$args.$2;

  FutureOr<QuizState> build(
    String? collectionId,
    String groupId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<QuizState>, QuizState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<QuizState>, QuizState>,
        AsyncValue<QuizState>,
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [collectionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.

@ProviderFor(exerciseWords)
final exerciseWordsProvider = ExerciseWordsFamily._();

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [collectionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.

final class ExerciseWordsProvider extends $FunctionalProvider<
        AsyncValue<
            ({
              List<WordPair> group,
              List<WordPair> others,
            })>,
        ({
          List<WordPair> group,
          List<WordPair> others,
        }),
        FutureOr<
            ({
              List<WordPair> group,
              List<WordPair> others,
            })>>
    with
        $FutureModifier<
            ({
              List<WordPair> group,
              List<WordPair> others,
            })>,
        $FutureProvider<
            ({
              List<WordPair> group,
              List<WordPair> others,
            })> {
  /// The words of one exercise (learn-kit S-08): the selected group's words to
  /// learn in group order, and the same session's other words to learn (for
  /// wrong options, D-15). A null [collectionId] is the current session, an id a
  /// History session (AC-05). No other session is read. Which words are usable
  /// is each exercise's own rule. Read-only: nothing here writes the session.
  ExerciseWordsProvider._(
      {required ExerciseWordsFamily super.from,
      required (
        String?,
        String,
      )
          super.argument})
      : super(
          retry: null,
          name: r'exerciseWordsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$exerciseWordsHash();

  @override
  String toString() {
    return r'exerciseWordsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<
      ({
        List<WordPair> group,
        List<WordPair> others,
      })> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<
      ({
        List<WordPair> group,
        List<WordPair> others,
      })> create(Ref ref) {
    final argument = this.argument as (
      String?,
      String,
    );
    return exerciseWords(
      ref,
      argument.$1,
      argument.$2,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseWordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseWordsHash() => r'886db8572add36cc8a25120314adc0758537a537';

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [collectionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.

final class ExerciseWordsFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<
                ({
                  List<WordPair> group,
                  List<WordPair> others,
                })>,
            (
              String?,
              String,
            )> {
  ExerciseWordsFamily._()
      : super(
          retry: null,
          name: r'exerciseWordsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The words of one exercise (learn-kit S-08): the selected group's words to
  /// learn in group order, and the same session's other words to learn (for
  /// wrong options, D-15). A null [collectionId] is the current session, an id a
  /// History session (AC-05). No other session is read. Which words are usable
  /// is each exercise's own rule. Read-only: nothing here writes the session.

  ExerciseWordsProvider call(
    String? collectionId,
    String groupId,
  ) =>
      ExerciseWordsProvider._(argument: (
        collectionId,
        groupId,
      ), from: this);

  @override
  String toString() => r'exerciseWordsProvider';
}

/// The film dialogues of the session an exercise reads, same session choice as
/// [exerciseWords] (null = current, id = History). S-31.

@ProviderFor(exerciseDialogues)
final exerciseDialoguesProvider = ExerciseDialoguesFamily._();

/// The film dialogues of the session an exercise reads, same session choice as
/// [exerciseWords] (null = current, id = History). S-31.

final class ExerciseDialoguesProvider extends $FunctionalProvider<
        AsyncValue<List<FilmDialogue>>,
        List<FilmDialogue>,
        FutureOr<List<FilmDialogue>>>
    with
        $FutureModifier<List<FilmDialogue>>,
        $FutureProvider<List<FilmDialogue>> {
  /// The film dialogues of the session an exercise reads, same session choice as
  /// [exerciseWords] (null = current, id = History). S-31.
  ExerciseDialoguesProvider._(
      {required ExerciseDialoguesFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'exerciseDialoguesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$exerciseDialoguesHash();

  @override
  String toString() {
    return r'exerciseDialoguesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<FilmDialogue>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<FilmDialogue>> create(Ref ref) {
    final argument = this.argument as String?;
    return exerciseDialogues(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseDialoguesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseDialoguesHash() => r'729bd94e949a3df00dfcbee562d3e0c8ffcd571c';

/// The film dialogues of the session an exercise reads, same session choice as
/// [exerciseWords] (null = current, id = History). S-31.

final class ExerciseDialoguesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<FilmDialogue>>, String?> {
  ExerciseDialoguesFamily._()
      : super(
          retry: null,
          name: r'exerciseDialoguesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The film dialogues of the session an exercise reads, same session choice as
  /// [exerciseWords] (null = current, id = History). S-31.

  ExerciseDialoguesProvider call(
    String? collectionId,
  ) =>
      ExerciseDialoguesProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'exerciseDialoguesProvider';
}

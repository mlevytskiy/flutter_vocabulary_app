// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$exerciseWordsHash() => r'fd8217e051ba179e0c938922738ebb2eec976670';

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

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [sessionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.
///
/// Copied from [exerciseWords].
@ProviderFor(exerciseWords)
const exerciseWordsProvider = ExerciseWordsFamily();

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [sessionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.
///
/// Copied from [exerciseWords].
class ExerciseWordsFamily extends Family<
    AsyncValue<({List<WordPair> group, List<WordPair> others})>> {
  /// The words of one exercise (learn-kit S-08): the selected group's words to
  /// learn in group order, and the same session's other words to learn (for
  /// wrong options, D-15). A null [sessionId] is the current session, an id a
  /// History session (AC-05). No other session is read. Which words are usable
  /// is each exercise's own rule. Read-only: nothing here writes the session.
  ///
  /// Copied from [exerciseWords].
  const ExerciseWordsFamily();

  /// The words of one exercise (learn-kit S-08): the selected group's words to
  /// learn in group order, and the same session's other words to learn (for
  /// wrong options, D-15). A null [sessionId] is the current session, an id a
  /// History session (AC-05). No other session is read. Which words are usable
  /// is each exercise's own rule. Read-only: nothing here writes the session.
  ///
  /// Copied from [exerciseWords].
  ExerciseWordsProvider call(
    String? sessionId,
    String groupId,
  ) {
    return ExerciseWordsProvider(
      sessionId,
      groupId,
    );
  }

  @override
  ExerciseWordsProvider getProviderOverride(
    covariant ExerciseWordsProvider provider,
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
  String? get name => r'exerciseWordsProvider';
}

/// The words of one exercise (learn-kit S-08): the selected group's words to
/// learn in group order, and the same session's other words to learn (for
/// wrong options, D-15). A null [sessionId] is the current session, an id a
/// History session (AC-05). No other session is read. Which words are usable
/// is each exercise's own rule. Read-only: nothing here writes the session.
///
/// Copied from [exerciseWords].
class ExerciseWordsProvider extends AutoDisposeFutureProvider<
    ({List<WordPair> group, List<WordPair> others})> {
  /// The words of one exercise (learn-kit S-08): the selected group's words to
  /// learn in group order, and the same session's other words to learn (for
  /// wrong options, D-15). A null [sessionId] is the current session, an id a
  /// History session (AC-05). No other session is read. Which words are usable
  /// is each exercise's own rule. Read-only: nothing here writes the session.
  ///
  /// Copied from [exerciseWords].
  ExerciseWordsProvider(
    String? sessionId,
    String groupId,
  ) : this._internal(
          (ref) => exerciseWords(
            ref as ExerciseWordsRef,
            sessionId,
            groupId,
          ),
          from: exerciseWordsProvider,
          name: r'exerciseWordsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$exerciseWordsHash,
          dependencies: ExerciseWordsFamily._dependencies,
          allTransitiveDependencies:
              ExerciseWordsFamily._allTransitiveDependencies,
          sessionId: sessionId,
          groupId: groupId,
        );

  ExerciseWordsProvider._internal(
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
  Override overrideWith(
    FutureOr<({List<WordPair> group, List<WordPair> others})> Function(
            ExerciseWordsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExerciseWordsProvider._internal(
        (ref) => create(ref as ExerciseWordsRef),
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
  AutoDisposeFutureProviderElement<
      ({List<WordPair> group, List<WordPair> others})> createElement() {
    return _ExerciseWordsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseWordsProvider &&
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
mixin ExerciseWordsRef on AutoDisposeFutureProviderRef<
    ({List<WordPair> group, List<WordPair> others})> {
  /// The parameter `sessionId` of this provider.
  String? get sessionId;

  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _ExerciseWordsProviderElement extends AutoDisposeFutureProviderElement<
    ({List<WordPair> group, List<WordPair> others})> with ExerciseWordsRef {
  _ExerciseWordsProviderElement(super.provider);

  @override
  String? get sessionId => (origin as ExerciseWordsProvider).sessionId;
  @override
  String get groupId => (origin as ExerciseWordsProvider).groupId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

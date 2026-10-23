// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photos_with_words.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current session's sources with words that the photo panel lists,
/// photos and sets mixed, oldest first by `takenAt` (sources added at the
/// same time keep the order of `WordCollection.sources`), derived in one pass over
/// the rows (sad §4). Only the current session is read, so another session's
/// sources never appear (spec AC-16); a row whose word is cleared does not
/// count (spec AC-15).

@ProviderFor(sourcesWithWords)
final sourcesWithWordsProvider = SourcesWithWordsProvider._();

/// The current session's sources with words that the photo panel lists,
/// photos and sets mixed, oldest first by `takenAt` (sources added at the
/// same time keep the order of `WordCollection.sources`), derived in one pass over
/// the rows (sad §4). Only the current session is read, so another session's
/// sources never appear (spec AC-16); a row whose word is cleared does not
/// count (spec AC-15).

final class SourcesWithWordsProvider extends $FunctionalProvider<
    List<SourceWithWords>,
    List<SourceWithWords>,
    List<SourceWithWords>> with $Provider<List<SourceWithWords>> {
  /// The current session's sources with words that the photo panel lists,
  /// photos and sets mixed, oldest first by `takenAt` (sources added at the
  /// same time keep the order of `WordCollection.sources`), derived in one pass over
  /// the rows (sad §4). Only the current session is read, so another session's
  /// sources never appear (spec AC-16); a row whose word is cleared does not
  /// count (spec AC-15).
  SourcesWithWordsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sourcesWithWordsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sourcesWithWordsHash();

  @$internal
  @override
  $ProviderElement<List<SourceWithWords>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<SourceWithWords> create(Ref ref) {
    return sourcesWithWords(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SourceWithWords> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SourceWithWords>>(value),
    );
  }
}

String _$sourcesWithWordsHash() => r'23b871103b7b7174775aa97de45e74781277db7d';

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).

@ProviderFor(storedSourcesWithWords)
final storedSourcesWithWordsProvider = StoredSourcesWithWordsFamily._();

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).

final class StoredSourcesWithWordsProvider extends $FunctionalProvider<
    List<SourceWithWords>,
    List<SourceWithWords>,
    List<SourceWithWords>> with $Provider<List<SourceWithWords>> {
  /// The sources with words of a stored collection, e.g. one the Words screen
  /// shows from History, read-only (words-photo-panel).
  StoredSourcesWithWordsProvider._(
      {required StoredSourcesWithWordsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'storedSourcesWithWordsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$storedSourcesWithWordsHash();

  @override
  String toString() {
    return r'storedSourcesWithWordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<SourceWithWords>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<SourceWithWords> create(Ref ref) {
    final argument = this.argument as String;
    return storedSourcesWithWords(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SourceWithWords> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SourceWithWords>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StoredSourcesWithWordsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$storedSourcesWithWordsHash() =>
    r'0d61e6d77fe23706a7b3e69c05501594d215c5c3';

/// The sources with words of a stored collection, e.g. one the Words screen
/// shows from History, read-only (words-photo-panel).

final class StoredSourcesWithWordsFamily extends $Family
    with $FunctionalFamilyOverride<List<SourceWithWords>, String> {
  StoredSourcesWithWordsFamily._()
      : super(
          retry: null,
          name: r'storedSourcesWithWordsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The sources with words of a stored collection, e.g. one the Words screen
  /// shows from History, read-only (words-photo-panel).

  StoredSourcesWithWordsProvider call(
    String collectionId,
  ) =>
      StoredSourcesWithWordsProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'storedSourcesWithWordsProvider';
}

/// The current session's photos with words, oldest first: the photos of
/// [sourcesWithWords]. Full-open shows only these (spec AC-21).

@ProviderFor(photosWithWords)
final photosWithWordsProvider = PhotosWithWordsProvider._();

/// The current session's photos with words, oldest first: the photos of
/// [sourcesWithWords]. Full-open shows only these (spec AC-21).

final class PhotosWithWordsProvider extends $FunctionalProvider<
    List<PhotoWithWords>,
    List<PhotoWithWords>,
    List<PhotoWithWords>> with $Provider<List<PhotoWithWords>> {
  /// The current session's photos with words, oldest first: the photos of
  /// [sourcesWithWords]. Full-open shows only these (spec AC-21).
  PhotosWithWordsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'photosWithWordsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$photosWithWordsHash();

  @$internal
  @override
  $ProviderElement<List<PhotoWithWords>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<PhotoWithWords> create(Ref ref) {
    return photosWithWords(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PhotoWithWords> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PhotoWithWords>>(value),
    );
  }
}

String _$photosWithWordsHash() => r'0860e55a8b2da02dbdf17103901679a5f2f7d16b';

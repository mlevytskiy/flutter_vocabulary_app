// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'include_photos.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.

@ProviderFor(IncludePhotos)
final includePhotosProvider = IncludePhotosFamily._();

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.
final class IncludePhotosProvider
    extends $NotifierProvider<IncludePhotos, bool> {
  /// The "Include photos (N)" switch, now in the Words screen's settings
  /// (words-photo-panel): on until switched off, for the Words screen of
  /// [collectionId] (null: the current collection). Not saved: it lives while
  /// that Words screen does, which watches it, as it did in its `State`.
  /// Sets (import-from-quizlet) are not behind it: they are always sent.
  IncludePhotosProvider._(
      {required IncludePhotosFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'includePhotosProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$includePhotosHash();

  @override
  String toString() {
    return r'includePhotosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IncludePhotos create() => IncludePhotos();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IncludePhotosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$includePhotosHash() => r'c4b02b59ed32d72e34d0afb8cb50974335fc991e';

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.

final class IncludePhotosFamily extends $Family
    with $ClassFamilyOverride<IncludePhotos, bool, bool, bool, String?> {
  IncludePhotosFamily._()
      : super(
          retry: null,
          name: r'includePhotosProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The "Include photos (N)" switch, now in the Words screen's settings
  /// (words-photo-panel): on until switched off, for the Words screen of
  /// [collectionId] (null: the current collection). Not saved: it lives while
  /// that Words screen does, which watches it, as it did in its `State`.
  /// Sets (import-from-quizlet) are not behind it: they are always sent.

  IncludePhotosProvider call(
    String? collectionId,
  ) =>
      IncludePhotosProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'includePhotosProvider';
}

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.

abstract class _$IncludePhotos extends $Notifier<bool> {
  late final _$args = ref.$arg as String?;
  String? get collectionId => _$args;

  bool build(
    String? collectionId,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    return element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

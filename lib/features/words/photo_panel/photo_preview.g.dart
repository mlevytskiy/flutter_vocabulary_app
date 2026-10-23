// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_preview.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The photo panel's read-ahead, shared with the Notes page it opens; it
/// lives while either watches it (owner, 2026-10-15).

@ProviderFor(photoPreloader)
final photoPreloaderProvider = PhotoPreloaderProvider._();

/// The photo panel's read-ahead, shared with the Notes page it opens; it
/// lives while either watches it (owner, 2026-10-15).

final class PhotoPreloaderProvider
    extends $FunctionalProvider<PhotoPreloader, PhotoPreloader, PhotoPreloader>
    with $Provider<PhotoPreloader> {
  /// The photo panel's read-ahead, shared with the Notes page it opens; it
  /// lives while either watches it (owner, 2026-10-15).
  PhotoPreloaderProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'photoPreloaderProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$photoPreloaderHash();

  @$internal
  @override
  $ProviderElement<PhotoPreloader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhotoPreloader create(Ref ref) {
    return photoPreloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoPreloader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoPreloader>(value),
    );
  }
}

String _$photoPreloaderHash() => r'42ed242e511d15dc84362b11a54026514c7cf1dc';

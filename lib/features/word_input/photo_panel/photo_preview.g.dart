// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_preview.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$photoPreloaderHash() => r'42ed242e511d15dc84362b11a54026514c7cf1dc';

/// The photo panel's read-ahead, shared with the Notes page it opens; it
/// lives while either watches it (owner, 2026-10-15).
///
/// Copied from [photoPreloader].
@ProviderFor(photoPreloader)
final photoPreloaderProvider = AutoDisposeProvider<PhotoPreloader>.internal(
  photoPreloader,
  name: r'photoPreloaderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$photoPreloaderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PhotoPreloaderRef = AutoDisposeProviderRef<PhotoPreloader>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

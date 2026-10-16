// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recycle_bin_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$binItemsHash() => r'9820486e00f85d28517697c63679d463d43e1dae';

/// The recycle bin's items (SCR-08), newest deleted first, with the days left
/// counted from now; re-emitted after every write.
///
/// Copied from [binItems].
@ProviderFor(binItems)
final binItemsProvider = AutoDisposeStreamProvider<List<BinItemView>>.internal(
  binItems,
  name: r'binItemsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$binItemsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BinItemsRef = AutoDisposeStreamProviderRef<List<BinItemView>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

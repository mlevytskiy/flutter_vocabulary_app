// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recycle_bin_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The recycle bin's items (SCR-08), newest deleted first, with the days left
/// counted from now; re-emitted after every write.

@ProviderFor(binItems)
final binItemsProvider = BinItemsProvider._();

/// The recycle bin's items (SCR-08), newest deleted first, with the days left
/// counted from now; re-emitted after every write.

final class BinItemsProvider extends $FunctionalProvider<
        AsyncValue<List<BinItemView>>,
        List<BinItemView>,
        Stream<List<BinItemView>>>
    with
        $FutureModifier<List<BinItemView>>,
        $StreamProvider<List<BinItemView>> {
  /// The recycle bin's items (SCR-08), newest deleted first, with the days left
  /// counted from now; re-emitted after every write.
  BinItemsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'binItemsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$binItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<BinItemView>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<BinItemView>> create(Ref ref) {
    return binItems(ref);
  }
}

String _$binItemsHash() => r'9820486e00f85d28517697c63679d463d43e1dae';

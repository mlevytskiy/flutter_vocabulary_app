import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/models/translation_result.dart';
import 'translation_options_content.dart';

/// Translation dots button: unlike the Translation icon, this sits
/// *outside* the Translation field (a plain sibling in the outer Row, not
/// overlaid via Positioned) and is always visible -- no focus or length
/// gating, and no loading state of its own.
///
/// Its appearance tracks the dictionary it can actually show: full (solid)
/// dots when [options] holds a block, empty (outlined) dots when it does not.
/// The state is derived here from [options] rather than passed in as a second
/// flag, so solid dots can never disagree with an empty popup -- see
/// docs/lightning_icon_rules.md.
///
/// Tapping always opens the "more options" popup, including on empty dots: the
/// popup shows the block when there is one and an update icon that loads it
/// when there is not. Empty dots used to be a no-op, which left no way to reach
/// that popup from a row whose cached block had been dropped.
class TranslationDotsButton extends StatelessWidget {
  /// Google's dictionary block for this row, if the last translate left one.
  final TranslationResult? options;

  /// Whether the row's Word field holds enough text to look a block up.
  final bool canLoadOptions;

  final CustomPopupMenuController controller;
  final ValueChanged<String> onSelectTranslation;

  /// Fetches the block for the row's current Word field. Owned by the screen.
  final Future<TranslationResult?> Function() onLoadTranslations;

  /// Fired at the moment the popup opens, before its overlay is laid out. The
  /// screen uses it to drop the keyboard so the popup gets the full height
  /// between the app bar and the bottom of the screen (otherwise its body --
  /// including the close button at the bottom -- can be squeezed under the
  /// keyboard). Only the dots use this; the lightning icons must keep focus.
  final VoidCallback onOpen;

  /// Fired by the popup's own close icon. The screen hides that row's menu, at
  /// the same predictable point the open path uses, rather than leaving the tap
  /// to the package's outside-tap detection -- which keys off a menu rectangle
  /// the package only refreshes during layout. Owned by the screen.
  final VoidCallback onClose;

  const TranslationDotsButton({
    super.key,
    required this.controller,
    required this.onSelectTranslation,
    required this.onLoadTranslations,
    required this.onOpen,
    required this.onClose,
    this.options,
    this.canLoadOptions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = options?.hasDictionary ?? false;
    final dotIcon = isFilled ? Icons.circle : Icons.circle_outlined;
    final dotColor = Colors.purple[600];
    final dotsIcon = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(dotIcon, size: 6, color: dotColor),
        const SizedBox(height: 3),
        Icon(dotIcon, size: 6, color: dotColor),
        const SizedBox(height: 3),
        Icon(dotIcon, size: 6, color: dotColor),
      ],
    );

    // Same 22px-wide footprint and zero extra padding around the dots in both
    // appearances, so the solid/outlined flip never shifts the row's layout.
    return SizedBox(
      width: 22,
      child: CustomPopupMenu(
        controller: controller,
        pressType: PressType.singleClick,
        // Fires on every visibility change; unfocus only when opening, so the
        // keyboard is already gone before the overlay measures its height.
        menuOnChange: (isShowing) {
          if (isShowing) onOpen();
        },
        showArrow: true,
        arrowColor: Colors.black87,
        arrowSize: 10,
        barrierColor: Colors.transparent,
        verticalMargin: 6,
        menuBuilder: () {
          final maxWidth = MediaQuery.of(context).size.width * 0.7;

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.black87,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: 420,
                ),
                child: TranslationOptionsContent(
                  options: options,
                  canLoad: canLoadOptions,
                  onLoadTranslations: onLoadTranslations,
                  onSelectTranslation: (text) {
                    onClose();
                    onSelectTranslation(text);
                  },
                  onClose: onClose,
                ),
              ),
            ),
          );
        },
        child: Center(child: dotsIcon),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import 'definition_options_content.dart';
import 'open_dots_menu.dart';

/// Definition dots button (definition-mode, spec AC-08): the definition
/// counterpart of `TranslationDotsButton`, built the same way — outside the
/// field, always visible, solid dots when senses are stored and outlined dots
/// when not, same 22 px footprint, same popup package and close handling.
/// Tapping opens the senses list; with nothing stored the list offers a load
/// icon.
class DefinitionDotsButton extends StatelessWidget {
  final List<String>? senses;
  final bool canLoadSenses;
  final CustomPopupMenuController controller;
  final ValueChanged<String> onSelectSense;
  final Future<List<String>?> Function() onLoadSenses;

  /// Fired as the popup opens, so the screen can drop the keyboard first.
  final VoidCallback onOpen;

  /// Fired by the popup's own close icon; the screen hides the menu.
  final VoidCallback onClose;

  const DefinitionDotsButton({
    super.key,
    required this.controller,
    required this.onSelectSense,
    required this.onLoadSenses,
    required this.onOpen,
    required this.onClose,
    this.senses,
    this.canLoadSenses = true,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = senses?.isNotEmpty ?? false;
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

    return SizedBox(
      width: 22,
      child: CustomPopupMenu(
        // The package binds its controller once, in initState. Keying on the
        // controller rebuilds it when the screen hands this row a new one, so
        // the menu openDotsMenu shows is the one this widget listens to.
        key: ObjectKey(controller),
        controller: controller,
        pressType: PressType.singleClick,
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
                constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 420),
                child: DefinitionOptionsContent(
                  senses: senses,
                  canLoad: canLoadSenses,
                  onLoadSenses: onLoadSenses,
                  onSelectSense: (sense) {
                    onClose();
                    onSelectSense(sense);
                  },
                  onClose: onClose,
                ),
              ),
            ),
          );
        },
        // The tap is handled here rather than by the package's own InkWell, so
        // the menu can wait for the keyboard to finish closing -- see
        // openDotsMenu.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openDotsMenu(context, controller, onOpen),
          child: Center(child: dotsIcon),
        ),
      ),
    );
  }
}

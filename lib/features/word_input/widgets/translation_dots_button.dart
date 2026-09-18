import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/models/translation_result.dart';
import 'translation_options_content.dart';

/// Translation dots button: unlike the Translation icon, this sits
/// *outside* the Translation field (a plain sibling in the outer Row, not
/// overlaid via Positioned) and is always visible -- no focus or length
/// gating, and no loading state of its own. It tracks [isFilled]: empty
/// (outlined) dots by default, full (solid) dots once a translate has
/// produced multiple options for this row -- including while a translate
/// request is in flight, the dots just stay in their current (empty or
/// full) state and flip once the request resolves; the Translation icon's
/// own overlay slot is what shows the loading spinner. Tapping empty dots
/// does nothing for now; tapping full dots opens the "more options" popup,
/// which shows [options] -- Google's dictionary block, already fetched by
/// the lightning action, so no second request is made here.
class TranslationDotsButton extends StatelessWidget {
  final bool isFilled;
  final TranslationResult? options;
  final CustomPopupMenuController controller;
  final ValueChanged<String> onSelectTranslation;

  const TranslationDotsButton({
    super.key,
    required this.isFilled,
    required this.controller,
    required this.onSelectTranslation,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
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

    // Both branches below share the same 22px-wide footprint and zero
    // extra padding around the dots, so toggling `isFilled` never shifts
    // the row's layout.
    if (isFilled) {
      return SizedBox(
        width: 22,
        child: CustomPopupMenu(
          controller: controller,
          pressType: PressType.singleClick,
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
                    onSelectTranslation: (text) {
                      controller.hideMenu();
                      onSelectTranslation(text);
                    },
                    onClose: controller.hideMenu,
                  ),
                ),
              ),
            );
          },
          child: Center(child: dotsIcon),
        ),
      );
    }

    // Empty -- nothing to do yet, so tapping is a no-op.
    return SizedBox(
      width: 22,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        icon: dotsIcon,
        onPressed: null,
      ),
    );
  }
}

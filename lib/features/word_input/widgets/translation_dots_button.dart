import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

/// Translation dots button: unlike the Translation icon, this sits
/// *outside* the Translation field (a plain sibling in the outer Row, not
/// overlaid via Positioned) and is always visible -- no focus or length
/// gating, and no loading state of its own. It tracks [isFilled]: empty
/// (outlined) dots by default, full (solid) dots once a translate has
/// produced multiple options for this row -- including while a translate
/// request is in flight, the dots just stay in their current (empty or
/// full) state and flip once the request resolves; the Translation icon's
/// own overlay slot is what shows the loading spinner. Tapping empty dots
/// does nothing for now; tapping full dots opens the "more options" popup.
class TranslationDotsButton extends StatelessWidget {
  final bool isFilled;
  final CustomPopupMenuController controller;
  final ValueChanged<String> onSelectTranslation;

  const TranslationDotsButton({
    super.key,
    required this.isFilled,
    required this.controller,
    required this.onSelectTranslation,
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
            final translations = [
              'лололололо лолололо переклад 1',
              'переклад 2',
              'переклад 3',
            ];
            var selectedItems = List<bool>.generate(translations.length, (_) => false);

            return StatefulBuilder(
              builder: (context, setMenuState) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Material(
                    color: Colors.black87,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < translations.length; i++)
                              InkWell(
                                onTap: () {
                                  controller.hideMenu();
                                  onSelectTranslation(translations[i]);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Checkbox(
                                          value: selectedItems[i],
                                          onChanged: (bool? value) {
                                            setMenuState(() {
                                              selectedItems[i] = value ?? false;
                                            });
                                          },
                                          activeColor: Colors.amber[600],
                                          checkColor: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          translations[i],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                          softWrap: true,
                                          maxLines: null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const Divider(color: Colors.white24, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Colors.white70,
                                    iconSize: 24,
                                    onPressed: () {
                                      controller.hideMenu();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    color: Colors.amber[600],
                                    iconSize: 24,
                                    onPressed: () {
                                      final selected = <String>[];
                                      for (int i = 0; i < translations.length; i++) {
                                        if (selectedItems[i]) {
                                          selected.add(translations[i]);
                                        }
                                      }

                                      if (selected.isNotEmpty) {
                                        controller.hideMenu();
                                        onSelectTranslation(selected.join(', '));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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

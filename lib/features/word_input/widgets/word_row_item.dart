import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/widgets/synced_text_field_row.dart';
import 'translation_dots_button.dart';

/// One row of the word-input list: the Word/Translation field pair, their
/// lightning icons, the drag handle (in drag mode), the remove button, and
/// the translation dots button. The screen still owns every parallel
/// per-row list (controllers, focus nodes, flags) and passes this widget
/// the index-th entry of each -- see word_input_screen.dart's `_buildItem`
/// call sites.
class WordRowItem extends StatelessWidget {
  final int index;
  final bool isDragMode;
  final TextEditingController wordController;
  final TextEditingController translationController;
  final FocusNode wordFocusNode;
  final FocusNode translationFocusNode;
  final bool isLoadingWordTranslation;
  final bool isLoadingTranslation;
  final bool shouldShowWordIcon;
  final bool shouldShowTranslationIcon;
  final bool hasTranslationOptions;
  final CustomPopupMenuController popupController;
  final VoidCallback onRemove;
  final VoidCallback onFillWordWithAI;
  final VoidCallback onFillWithAI;
  final ValueChanged<String> onSelectTranslation;

  const WordRowItem({
    super.key,
    required this.index,
    required this.isDragMode,
    required this.wordController,
    required this.translationController,
    required this.wordFocusNode,
    required this.translationFocusNode,
    required this.isLoadingWordTranslation,
    required this.isLoadingTranslation,
    required this.shouldShowWordIcon,
    required this.shouldShowTranslationIcon,
    required this.hasTranslationOptions,
    required this.popupController,
    required this.onRemove,
    required this.onFillWordWithAI,
    required this.onFillWithAI,
    required this.onSelectTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final dragHandle = isDragMode
        ? ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 32,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.drag_indicator,
                  color: const Color(0xFF7F77DD),
                  size: 32,
                ),
              ),
            ),
          )
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.only(top: 4, right: 8, bottom: 12, left: 8),
      decoration: BoxDecoration(
        color: const Color(0x57d9c1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Верхній рядок: кнопка видалення
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 16,
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    color: const Color(0xFFa883ca),
                    onPressed: onRemove,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Row з drag handle та Stack з полями
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (dragHandle != null) ...[
                dragHandle,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Must match the `spacing` passed to SyncedTextFieldRow
                    // below, so the Word icon's right edge lines up with the
                    // boundary between the Word and Translation fields (same
                    // padding pattern the Translation icon uses on the
                    // stack's own right edge).
                    const fieldSpacing = 16.0;
                    final wordFieldRightEdge =
                        (constraints.maxWidth - fieldSpacing) / 2;
                    return Stack(
                  children: [
                    SyncedTextFieldRow(
                      leftController: wordController,
                      rightController: translationController,
                      leftLabel: 'Word',
                      rightLabel: 'Translation',
                      leftHint: 'Word',
                      rightHint: 'Translation',
                      leftFocusNode: wordFocusNode,
                      rightFocusNode: translationFocusNode,
                      spacing: fieldSpacing,
                    ),
                    if (isLoadingWordTranslation || shouldShowWordIcon)
                      Positioned(
                        top: 2,
                        // End of the Word field, mirroring the Translation
                        // icon's `right: 2` (see docs/lightning_icon_rules.md).
                        right: constraints.maxWidth - wordFieldRightEdge + 2,
                        child: isLoadingWordTranslation
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.electric_bolt),
                                  color: Colors.purple[600],
                                  iconSize: 28,
                                  tooltip: 'AI Translate (to Word)',
                                  onPressed: onFillWordWithAI,
                                ),
                              ),
                      ),
                    if (isLoadingTranslation || shouldShowTranslationIcon)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: isLoadingTranslation
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.electric_bolt),
                                  color: Colors.purple[600],
                                  iconSize: 28,
                                  tooltip: 'AI Translate',
                                  onPressed: onFillWithAI,
                                ),
                              ),
                      ),
                  ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              TranslationDotsButton(
                isFilled: hasTranslationOptions,
                controller: popupController,
                onSelectTranslation: onSelectTranslation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

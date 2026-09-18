import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/models/translation_result.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../../core/widgets/synced_text_field_row.dart';
import 'pronunciation_buttons.dart';
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
  final bool shouldShowPronunciation;
  final bool hasTranslationOptions;

  /// Google's dictionary block for this row, shown inside the dots popup.
  /// Null until a translate produced one (and dropped again when the Word
  /// field changes) -- the popup then shows its placeholder message.
  final TranslationResult? translationOptions;
  final CustomPopupMenuController popupController;
  final VoidCallback onRemove;
  final VoidCallback onFillWordWithAI;
  final VoidCallback onFillWithAI;
  final ValueChanged<String> onSelectTranslation;
  final ValueChanged<Accent> onSpeak;

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
    required this.shouldShowPronunciation,
    required this.hasTranslationOptions,
    required this.popupController,
    this.translationOptions,
    required this.onRemove,
    required this.onFillWordWithAI,
    required this.onFillWithAI,
    required this.onSelectTranslation,
    required this.onSpeak,
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

    // Same layout constants the fields' own LayoutBuilder below uses, plus
    // the ones needed to project the Word field's right edge up into the
    // top strip: the drag handle (when present) and the dots button sit to
    // the left/right of the Expanded(fields) below, so the top strip needs
    // to account for them too to land the flags at the same X as the Word
    // field's own right corner.
    const dragHandleSlot = 40.0; // 32 handle + 8 spacing, only when isDragMode
    const dotsButtonSlot = 26.0; // 22 dots button + 4 spacing
    const fieldSpacing = 16.0;
    const flagsWidth = 52.0; // two 26px accent buttons, no gap

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.only(top: 4, right: 8, bottom: 12, left: 8),
      decoration: BoxDecoration(
        color: const Color(0x57d9c1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final dragHandleWidth = isDragMode ? dragHandleSlot : 0.0;
          final fieldsAreaWidth =
              cardConstraints.maxWidth - dragHandleWidth - dotsButtonSlot;
          final wordFieldWidth = (fieldsAreaWidth - fieldSpacing) / 2;
          // The Word field's right edge, measured from the card's own left
          // edge -- the same coordinate space the top strip's Row uses.
          final topStripWordFieldRightEdge = dragHandleWidth + wordFieldWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Верхній рядок: pronunciation flags (aligned under the Word
              // field's right edge) + кнопка видалення (right). Reuses this
              // existing 26px-tall strip above the fields instead of adding a
              // new row -- the flags never grow the card.
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    SizedBox(
                      width: (topStripWordFieldRightEdge - flagsWidth)
                          .clamp(0.0, double.infinity),
                    ),
                    SizedBox(
                      width: flagsWidth,
                      child: shouldShowPronunciation
                          ? PronunciationButtons(onSpeak: onSpeak)
                          : null,
                    ),
                    const Spacer(),
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
                        // stack's own right edge). `fieldSpacing` comes from the
                        // outer LayoutBuilder, which the top strip also reads.
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
                                right: constraints.maxWidth -
                                    wordFieldRightEdge +
                                    2,
                                child: isLoadingWordTranslation
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5),
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
                            if (isLoadingTranslation ||
                                shouldShowTranslationIcon)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: isLoadingTranslation
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5),
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
                    options: translationOptions,
                    controller: popupController,
                    onSelectTranslation: onSelectTranslation,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/models/translation_result.dart';
import '../../../core/providers.dart' show WordDetailMode;
import '../../../core/services/pronunciation_service.dart';
import '../../../core/widgets/synced_text_field_row.dart';
import 'definition_dots_button.dart';
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

  /// definition-mode: which detail fields the row shows. Translation mode is
  /// the pre-feature row, untouched; definition mode stacks Word over
  /// Definition at full width; both keeps the translation row and adds the
  /// Definition underneath (spec AC-02..AC-04).
  final WordDetailMode detailMode;
  final TextEditingController definitionController;
  final FocusNode definitionFocusNode;

  /// The Definition lightning (spec AC-05): its spinner, whether it shows
  /// (see `shouldShowDefinitionIcon`), and the lookup it triggers.
  final bool isLoadingDefinition;
  final bool shouldShowDefinitionIcon;
  final VoidCallback onFillDefinition;

  /// The definition dots popup (spec AC-08): the senses stored for this row,
  /// its popup controller, the lookup it can trigger, and what a picked sense
  /// does. Built only where the Definition field is shown.
  final List<String>? definitionSenses;
  final bool canLoadDefinitionSenses;
  final CustomPopupMenuController? definitionPopupController;
  final Future<List<String>?> Function()? onLoadDefinitionSenses;
  final ValueChanged<String>? onSelectDefinition;
  final VoidCallback? onCloseDefinitionOptions;
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

  /// Google's dictionary block for this row, shown inside the dots popup. Null
  /// until a translate produced one, and dropped again when the Word field
  /// changes -- the popup then offers its update icon instead. The dots button
  /// derives its solid/outlined state from this same value.
  final TranslationResult? translationOptions;

  /// Whether the Word field holds enough text for a dictionary lookup.
  final bool canLoadTranslationOptions;

  /// Loads the dictionary block for this row's current Word field. The screen
  /// owns the request; the popup renders what comes back.
  final Future<TranslationResult?> Function() onLoadTranslations;
  final CustomPopupMenuController popupController;

  /// Called when the dots popup opens, so the screen can drop the keyboard
  /// before the popup is laid out. Not wired to the lightning icons -- their
  /// visibility depends on the row keeping focus.
  final VoidCallback onOpenTranslationOptions;

  /// Closes the dots popup from its own close icon. Owned by the screen, so
  /// the menu is hidden at one predictable point rather than left to the popup
  /// package's outside-tap detection.
  final VoidCallback onCloseTranslationOptions;
  final VoidCallback onRemove;
  final VoidCallback onFillWordWithAI;
  final VoidCallback onFillWithAI;
  final ValueChanged<String> onSelectTranslation;
  final ValueChanged<Accent> onSpeak;

  const WordRowItem({
    super.key,
    required this.index,
    this.detailMode = WordDetailMode.translation,
    required this.definitionController,
    required this.definitionFocusNode,
    this.isLoadingDefinition = false,
    this.shouldShowDefinitionIcon = false,
    required this.onFillDefinition,
    this.definitionSenses,
    this.canLoadDefinitionSenses = true,
    this.definitionPopupController,
    this.onLoadDefinitionSenses,
    this.onSelectDefinition,
    this.onCloseDefinitionOptions,
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
    required this.popupController,
    required this.onLoadTranslations,
    required this.onOpenTranslationOptions,
    required this.onCloseTranslationOptions,
    this.translationOptions,
    this.canLoadTranslationOptions = true,
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
            child: const SizedBox(
              width: 32,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.drag_indicator,
                  color: Color(0xFF7F77DD),
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
          // In definition mode the Word field spans the whole fields area.
          final definitionOnly = detailMode == WordDetailMode.definition;
          // The Word field's right edge, measured from the card's own left
          // edge -- the same coordinate space the top strip's Row uses.
          final topStripWordFieldRightEdge = dragHandleWidth +
              (definitionOnly ? fieldsAreaWidth : wordFieldWidth);

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
              if (definitionOnly)
                _buildDefinitionOnlyRow(context, dragHandle)
              else ...[
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
                              if (isLoadingWordTranslation ||
                                  shouldShowWordIcon)
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
                                            icon:
                                                const Icon(Icons.electric_bolt),
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
                                            icon:
                                                const Icon(Icons.electric_bolt),
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
                      options: translationOptions,
                      canLoadOptions: canLoadTranslationOptions,
                      onLoadTranslations: onLoadTranslations,
                      controller: popupController,
                      onSelectTranslation: onSelectTranslation,
                      onOpen: onOpenTranslationOptions,
                      onClose: onCloseTranslationOptions,
                    ),
                  ],
                ),
                if (detailMode == WordDetailMode.both) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.only(left: dragHandleWidth),
                    child: _definitionFieldWithDots(context),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  /// Definition mode (spec AC-03): Word on top, Definition underneath, both
  /// across the full fields area. No Translation field, no translation dots
  /// and no Word lightning -- there is no translation to translate from. The
  /// right-hand slot stays reserved so the fields keep the same width as in
  /// the other modes.
  Widget _buildDefinitionOnlyRow(BuildContext context, Widget? dragHandle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dragHandle != null) ...[
          dragHandle,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _detailField(context,
                        controller: wordController,
                        focusNode: wordFocusNode,
                        label: 'Word',
                        minLines: 1),
                  ),
                  // The dots slot of the Definition line below, so both
                  // fields keep the same width.
                  const SizedBox(width: 26),
                ],
              ),
              const SizedBox(height: 12),
              _definitionFieldWithDots(context),
            ],
          ),
        ),
      ],
    );
  }

  /// The Definition field and, beside it, its dots button -- the same 4 px gap
  /// and 22 px slot the Translation field's dots use.
  Widget _definitionFieldWithDots(BuildContext context) {
    final controller = definitionPopupController;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _definitionFieldWithIcon(context)),
        const SizedBox(width: 4),
        if (controller != null)
          DefinitionDotsButton(
            senses: definitionSenses,
            canLoadSenses: canLoadDefinitionSenses,
            controller: controller,
            onLoadSenses: onLoadDefinitionSenses ?? () async => null,
            onSelectSense: onSelectDefinition ?? (_) {},
            onOpen: onOpenTranslationOptions,
            onClose: onCloseDefinitionOptions ?? () {},
          )
        else
          const SizedBox(width: 22),
      ],
    );
  }

  /// The Definition field with its lightning overlaid on the top-right
  /// corner, the same slot and look as the Translation icon.
  Widget _definitionFieldWithIcon(BuildContext context) {
    return Stack(
      children: [
        _detailField(context,
            controller: definitionController,
            focusNode: definitionFocusNode,
            label: 'Definition',
            minLines: 2),
        if (isLoadingDefinition || shouldShowDefinitionIcon)
          Positioned(
            top: 2,
            right: 2,
            child: isLoadingDefinition
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
                      tooltip: 'Look up definition',
                      onPressed: onFillDefinition,
                    ),
                  ),
          ),
      ],
    );
  }

  /// A full-width field styled exactly like `SyncedTextFieldRow`'s fields
  /// (outline border, 12/16 padding, bodyLarge with a forced strut).
  Widget _detailField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required int minLines,
  }) {
    final style =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      minLines: minLines,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        labelText: label,
        hintText: label,
        border: const OutlineInputBorder(borderSide: BorderSide(width: 1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        isDense: false,
      ),
    );
  }
}

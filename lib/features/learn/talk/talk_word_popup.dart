import 'package:flutter/material.dart';

import '../../../core/models/definition_result.dart';
import '../../../core/models/translation_result.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart' show WordDetailMode;
import '../../../core/theme/app_theme.dart';
import '../../words/widgets/definition_options_content.dart';
import '../../words/widgets/translation_options_content.dart';

/// What a tap on a talk word opens (talk-screen-b, owner 2026-10-24): the
/// word and its saved translation (and definition, when the word detail mode
/// shows definitions) over the Words screen's own popup content — the
/// dictionary block, or the senses in definition mode. Read-only: picking a
/// translation or a sense only closes it; a missing block can still be
/// loaded, but is not stored.
class TalkWordPopup extends StatelessWidget {
  const TalkWordPopup({
    super.key,
    required this.word,
    required this.mode,
    required this.onLoadTranslations,
    required this.onLoadSenses,
    required this.onClose,
  });

  final WordPair word;
  final WordDetailMode mode;
  final Future<TranslationResult?> Function() onLoadTranslations;
  final Future<List<String>?> Function() onLoadSenses;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final on = AppDecor.of(context).onPopup;
    final translation = word.translation.trim();
    final definition = word.definition.trim();
    final senses = DefinitionResult.decodeSenses(word.definitionOptionsJson);
    final canLoad = word.word.trim().length >= 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(word.word, style: TextStyle(color: on, fontSize: 17, fontWeight: FontWeight.w700)),
              if (mode != WordDetailMode.definition && translation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(translation, style: TextStyle(color: on.withAlpha(0xD9), fontSize: 15)),
              ],
              if (mode != WordDetailMode.translation && definition.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(definition,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: on.withAlpha(0xB3), fontSize: 13)),
              ],
            ],
          ),
        ),
        Divider(color: on.withAlpha(0x3D), height: 1),
        Flexible(
          child: mode == WordDetailMode.definition
              ? DefinitionOptionsContent(
                  senses: senses.isEmpty ? null : senses,
                  canLoad: canLoad,
                  onLoadSenses: onLoadSenses,
                  onSelectSense: (_) => onClose(),
                  onClose: onClose,
                )
              : TranslationOptionsContent(
                  options: word.translationOptions,
                  canLoad: canLoad,
                  onLoadTranslations: onLoadTranslations,
                  onSelectTranslation: (_) => onClose(),
                  onClose: onClose,
                ),
        ),
      ],
    );
  }
}

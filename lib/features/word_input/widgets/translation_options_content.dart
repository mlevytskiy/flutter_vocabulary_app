import 'package:flutter/material.dart';

import '../../../core/models/translation_result.dart';

/// Content of the "more options" popup opened from the Translation dots
/// button once it's solid (see docs/lightning_icon_rules.md) -- Google's
/// dictionary block grouped by part of speech, with tappable chips that fill
/// the Translation field.
///
/// The data comes from the same single request the lightning action already
/// made ([TranslationResult.dictionary]); opening the popup never hits the
/// network.
class TranslationOptionsContent extends StatelessWidget {
  /// The dictionary the lightning action fetched, if it did. Null shows a
  /// placeholder message instead of an empty body -- the smart-swap path
  /// makes the dots solid without one.
  final TranslationResult? options;
  final ValueChanged<String> onSelectTranslation;
  final VoidCallback onClose;

  const TranslationOptionsContent({
    super.key,
    required this.onSelectTranslation,
    required this.onClose,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            // The popup panel already owns the primary controller.
            primary: false,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _buildBody(),
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
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final google = _buildGoogleSection();
    if (google != null) return google;
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Tap the lightning icon to load translations.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  /// The dictionary block: one section per part of speech in priority order
  /// (noun, verb, adjective, adverb, other), each word a tappable chip that
  /// fills the Translation field.
  Widget? _buildGoogleSection() {
    final info = options;
    if (info == null || !info.hasDictionary) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in info.dictionaryByPriority) ...[
          _SectionHeader(entry.pos.toUpperCase()),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in entry.words)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelectTranslation(w.word),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      w.word,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

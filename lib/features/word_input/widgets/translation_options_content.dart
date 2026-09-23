import 'package:flutter/material.dart';

import '../../../core/models/translation_result.dart';

/// Content of the "more options" popup opened from the Translation dots
/// button (see docs/lightning_icon_rules.md) -- Google's dictionary block
/// grouped by part of speech, with tappable chips that fill the Translation
/// field.
///
/// The chips come from [options]: the dictionary the last translate brought
/// back, handed to the popup so opening it costs no second request. When there
/// is no block to show -- the row was never translated, or the Word field
/// changed since the last translate, which drops the cached block -- the popup
/// offers an update icon and loads the block for whatever the Word field holds
/// now. There is no dead-end "tap the lightning icon" message any more.
///
/// This is a [StatefulWidget] on purpose: the popup is rendered into an
/// overlay, so it cannot rely on the screen's `setState` reaching it. It awaits
/// [onLoadTranslations] itself and re-renders from the result, while the screen
/// stays the one that performs the request and stores it.
class TranslationOptionsContent extends StatefulWidget {
  /// The dictionary already cached for this row, if any. Null means no
  /// translate has produced one, or the Word field changed since one did.
  final TranslationResult? options;

  /// Whether the Word field holds enough text to look up. Below the bar the
  /// update icon is present but refuses, rather than sending an empty query.
  final bool canLoad;

  /// Loads the dictionary for the row's current Word field and returns it, or
  /// null when the request failed or found nothing. The screen owns the
  /// request; the popup only renders what comes back.
  final Future<TranslationResult?> Function() onLoadTranslations;

  final ValueChanged<String> onSelectTranslation;
  final VoidCallback onClose;

  const TranslationOptionsContent({
    super.key,
    required this.onLoadTranslations,
    required this.onSelectTranslation,
    required this.onClose,
    this.options,
    this.canLoad = true,
  });

  @override
  State<TranslationOptionsContent> createState() =>
      _TranslationOptionsContentState();
}

class _TranslationOptionsContentState extends State<TranslationOptionsContent> {
  /// What the update-icon tap brought back, if anything. Preferred over
  /// [TranslationOptionsContent.options] so the popup can show its own result
  /// immediately, without waiting for a rebuild from the screen underneath.
  TranslationResult? _fetched;

  bool _busy = false;

  /// Set once a load came back empty, so the popup explains why the icon is
  /// still there instead of looking like the tap did nothing.
  String? _notice;

  TranslationResult? get _effectiveOptions => _fetched ?? widget.options;

  Future<void> _load() async {
    if (_busy || !widget.canLoad) return;

    setState(() {
      _busy = true;
      _notice = null;
    });

    final result = await widget.onLoadTranslations();
    if (!mounted) return;

    setState(() {
      _busy = false;
      _fetched = result;
      _notice = (result == null || !result.hasDictionary)
          ? 'No extra translations for this word.'
          : null;
    });
  }

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
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final info = _effectiveOptions;
    if (info != null && info.hasDictionary) return _buildGoogleSection(info);
    return _buildLoadPrompt();
  }

  /// No block to show: an update icon that fetches one, plus a line saying
  /// which of the two reasons applies.
  Widget _buildLoadPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              color: Colors.white70,
              iconSize: 28,
              tooltip: 'Load translations',
              onPressed: widget.canLoad ? _load : null,
            ),
          const SizedBox(height: 8),
          Text(
            _notice ??
                (widget.canLoad
                    ? 'No translations loaded yet. Tap to load.'
                    : 'Type a word to load translations.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// The dictionary block: one section per part of speech in priority order
  /// (noun, verb, adjective, adverb, other), each word a tappable chip that
  /// fills the Translation field.
  Widget _buildGoogleSection(TranslationResult info) {
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
                  onTap: () => widget.onSelectTranslation(w.word),
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

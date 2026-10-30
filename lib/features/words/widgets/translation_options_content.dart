import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/translation_result.dart';
import '../../../core/models/word_origin.dart';

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

  /// The row's context and what it is (word-context AC-13): shown in italic,
  /// read-only, under the options; nothing when empty or [ContextKind.none].
  final String contextText;
  final ContextKind contextKind;

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
    this.contextText = '',
    this.contextKind = ContextKind.none,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_buildBody(), _buildContext(context)],
            ),
          ),
        ),
        Divider(color: _on(context).withAlpha(0x3D), height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                color: _on(context).withAlpha(0xB3),
                iconSize: 24,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The row's context, read-only (word-context AC-13).
  Widget _buildContext(BuildContext context) {
    final text = widget.contextText.trim();
    if (text.isEmpty || widget.contextKind == ContextKind.none) {
      return const SizedBox.shrink();
    }
    final ai = widget.contextKind == ContextKind.ai;
    final decor = AppDecor.of(context);
    final muted = _on(context).withAlpha(0x62);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        key: const Key('popup-context'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ai) ...[
                Icon(Icons.auto_awesome, size: 12, color: decor.aiAccent),
                const SizedBox(width: 4),
              ],
              Text(
                ai ? 'written by AI' : 'from the source',
                style: TextStyle(
                  color: ai ? decor.aiAccent : muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              color: _on(context),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _on(context).withAlpha(0xB3),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              color: _on(context).withAlpha(0xB3),
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
            style: TextStyle(color: _on(context).withAlpha(0xB3)),
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
                      color: _on(context).withAlpha(0x1F),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      w.word,
                      style: TextStyle(color: _on(context), fontSize: 15),
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
        style: TextStyle(
          color: _on(context).withAlpha(0x62),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The text and lines on the three dots' menu (app-themes).
Color _on(BuildContext context) => AppDecor.of(context).onPopup;

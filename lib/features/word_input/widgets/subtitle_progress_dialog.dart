import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/vocab_word.dart';
import 'subtitle_poster.dart';

/// The words the phone picked, each with its context, for the progress cards.
typedef SubtitlePickedWords = ({List<String> words, Map<String, String> contexts});

/// How a subtitle progress dialog ended.
sealed class SubtitleProgressOutcome {
  const SubtitleProgressOutcome();
}

/// The translations arrived; [words] are what the translator returned.
class SubtitleProgressDone extends SubtitleProgressOutcome {
  const SubtitleProgressDone(this.words);
  final List<VocabWord> words;
}

/// The translation failed with [error].
class SubtitleProgressFailed extends SubtitleProgressOutcome {
  const SubtitleProgressFailed(this.error);
  final Object error;
}

/// Cancel or Back.
class SubtitleProgressCancelled extends SubtitleProgressOutcome {
  const SubtitleProgressCancelled();
}

/// How long the filled pager takes to scroll on to the last card.
const Duration subtitleCardsScrollFor = Duration(seconds: 2);

/// The subtitle import's progress dialog, built like the Quizlet one
/// (quizlet_progress_dialog.dart): the film's poster and title over a pager of
/// skeleton cards while the file downloads and the phone picks the words
/// ([picked]), then one card per picked word, each with its context line and a
/// skeleton bar in place of the translation. The learner can swipe through them while [translated] runs;
/// once it completes the cards show the translator's words and the pager
/// scrolls on from the current card to the last in [subtitleCardsScrollFor]
/// before the dialog closes. A failure closes it at once. It cannot be
/// dismissed by the barrier, so the session cannot change underneath (AC-16);
/// Cancel and Back end it as a cancel.
Future<SubtitleProgressOutcome> showSubtitleProgressDialog(
  BuildContext context, {
  required String fileName,
  String? title,
  String? imageUrl,
  required Future<SubtitlePickedWords> picked,
  required Future<List<VocabWord>> translated,
}) async {
  // They may fail before the dialog has built and listened (a file with no
  // words fails at once); the dialog still sees the error when it listens.
  picked.ignore();
  translated.ignore();
  final outcome = await showDialog<SubtitleProgressOutcome>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => _SubtitleProgressDialog(
      fileName: fileName,
      title: title,
      imageUrl: imageUrl,
      picked: picked,
      translated: translated,
    ),
  );
  return outcome ?? const SubtitleProgressCancelled();
}

class _SubtitleProgressDialog extends StatefulWidget {
  const _SubtitleProgressDialog({
    required this.fileName,
    this.title,
    this.imageUrl,
    required this.picked,
    required this.translated,
  });

  final String fileName;
  final String? title;
  final String? imageUrl;
  final Future<SubtitlePickedWords> picked;
  final Future<List<VocabWord>> translated;

  @override
  State<_SubtitleProgressDialog> createState() => _SubtitleProgressDialogState();
}

class _SubtitleProgressDialogState extends State<_SubtitleProgressDialog> with SingleTickerProviderStateMixin {
  static const double _pagerHeight = 220;

  final _pages = PageController(viewportFraction: 0.82);

  // The skeletons' soft pulse.
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  /// The picked words, once the file is read.
  SubtitlePickedWords? _picked;

  /// The translator's words, once they arrive.
  List<VocabWord>? _translated;

  // Set once the dialog has been popped, so a late translation does not pop
  // what is below it.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    widget.picked.then((picked) {
      if (mounted && !_closed) setState(() => _picked = picked);
    }, onError: (Object _) {}); // the translation fails with it and closes the dialog
    widget.translated.then(_arrived, onError: (Object error) => _close(SubtitleProgressFailed(error)));
  }

  Future<void> _arrived(List<VocabWord> words) async {
    if (_closed || !mounted) return;
    if (words.isEmpty) {
      _close(const SubtitleProgressDone([]));
      return;
    }
    final at = _pages.hasClients && _pages.page != null ? _pages.page!.round() : 0;
    setState(() => _translated = words);
    _pulse.stop();
    await WidgetsBinding.instance.endOfFrame;
    if (_closed || !mounted) return;
    final last = words.length - 1;
    if (_pages.hasClients && at > last) _pages.jumpToPage(last);
    if (_pages.hasClients && last > 0 && at < last) {
      await _pages.animateToPage(last, duration: subtitleCardsScrollFor, curve: Curves.easeInOut);
    } else {
      await Future<void>.delayed(subtitleCardsScrollFor);
    }
    _close(SubtitleProgressDone(words));
  }

  void _close(SubtitleProgressOutcome outcome) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context, rootNavigator: true).pop(outcome);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translated = _translated;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(const SubtitleProgressCancelled());
      },
      child: AlertDialog(
        title: Text(_picked == null
            ? 'Reading the subtitles…'
            : translated == null
                ? 'Translating the words…'
                : 'Translated'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SubtitlePoster(widget.imageUrl),
                  if (widget.imageUrl != null) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? widget.fileName,
                          key: const Key('subtitle-file-name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.title != null)
                          Text(widget.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SizedBox(
                height: _pagerHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: _pager(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _close(const SubtitleProgressCancelled()),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// The words pager: the picked words with skeleton translations, then the
  /// translator's words.
  Widget _pager(BuildContext context) {
    final translated = _translated;
    final picked = _picked;
    final count = translated?.length ?? picked?.words.length ?? 3;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const Key('subtitle-cards'),
            controller: _pages,
            itemCount: count,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
              child: picked == null
                  ? _skeletonCard(context)
                  : translated == null
                      ? _card(context, word: picked.words[i], line: picked.contexts[picked.words[i]])
                      : _card(
                          context,
                          word: translated[i].word,
                          translation: translated[i].translation ?? '',
                          line: translated[i].context,
                        ),
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: picked == null
              ? null
              : AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) {
                    final page = _pages.hasClients && _pages.page != null ? _pages.page!.round() : 0;
                    return Text(
                      '${(page + 1).clamp(1, count)} / $count',
                      key: const Key('subtitle-cards-position'),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// One word's card; a skeleton bar stands for the translation until it is
  /// known ([translation] null). [line] is the word's context line.
  Widget _card(BuildContext context, {required String word, String? translation, String? line}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: translation == null ? const Key('subtitle-card-skeleton') : const Key('subtitle-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(word, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge),
          const SizedBox(height: 10),
          SizedBox(
            height: 22,
            child: Center(
              child: translation == null
                  ? _bone(width: 120, height: 14)
                  : Text(
                      translation,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(color: scheme.primary),
                    ),
            ),
          ),
          if (line != null && line.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '“$line”',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// A card while the file is still being read: skeleton word, translation and context.
  Widget _skeletonCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('subtitle-card-loading'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bone(width: 110, height: 18),
          const SizedBox(height: 16),
          _bone(width: 120, height: 14),
          const SizedBox(height: 16),
          _bone(width: 160, height: 10),
          const SizedBox(height: 8),
          _bone(width: 120, height: 10),
        ],
      ),
    );
  }

  /// One grey skeleton bar, softly pulsing.
  Widget _bone({required double width, required double height}) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.08 + 0.08 * _pulse.value),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

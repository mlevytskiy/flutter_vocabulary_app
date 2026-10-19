import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/subtitle_search_service.dart';
import 'subtitle_import_dialog.dart' show SubtitleSource;
import 'subtitle_poster.dart';

/// What the learner reads when finding a subtitle file fails.
abstract final class SubtitleSearchMessages {
  static const unavailable = "Subtitles couldn't be found right now. Try again, or choose a file.";
  static const downloadLimit = "Today's subtitle downloads are used up. Try again tomorrow, or choose a file.";
  static const tooLarge = 'This file is too large. The largest file accepted is 1 MB.';
  static const notFound = 'This subtitle file is gone. Pick another one.';
  static const nothingFound = 'Nothing found. Try another name.';
  static const hint = 'Type a film or series name, then search. Pick a suggestion to choose a season and episode.';

  static String of(SubtitleSearchError error) => switch (error) {
        SubtitleSearchError.unavailable => unavailable,
        SubtitleSearchError.downloadLimit => downloadLimit,
        SubtitleSearchError.tooLarge => tooLarge,
        SubtitleSearchError.notFound => notFound,
      };
}

/// Finds an English subtitle file by film or series name (OpenSubtitles,
/// through the Worker): a name field that suggests films and series, with
/// their posters, as the learner types — picking a series offers an optional
/// season and episode — and the matching files. Picking a suggestion, a season
/// or an episode searches at once; a typed name needs Search. A tap on a file
/// closes the dialog at once with its title and poster while it downloads, so
/// the import can start without waiting. Resolves with the file, or null when
/// closed.
Future<SubtitleSource?> showSubtitleSearchDialog(BuildContext context, {required SubtitleSearchService service}) =>
    showDialog<SubtitleSource>(
      context: context,
      builder: (context) => _SubtitleSearchDialog(service: service),
    );

class _SubtitleSearchDialog extends StatefulWidget {
  const _SubtitleSearchDialog({required this.service});

  final SubtitleSearchService service;

  @override
  State<_SubtitleSearchDialog> createState() => _SubtitleSearchDialogState();
}

class _SubtitleSearchDialogState extends State<_SubtitleSearchDialog> {
  /// Wait after the last key before asking for suggestions.
  static const _suggestAfter = Duration(milliseconds: 400);
  static const _suggestFromChars = 3;

  final _query = TextEditingController();
  Timer? _suggestTimer;

  /// Films and series suggested for the typed name.
  List<SubtitleTitle> _suggestions = const [];

  /// The suggestion picked, and for a series the season and episode (null: any).
  SubtitleTitle? _picked;
  int? _season;
  int? _episode;

  List<SubtitleSearchResult>? _results;
  bool _searching = false;

  /// Counts searches, so only the latest one's answer is shown when a season
  /// or episode is changed while an earlier search is still running.
  int _searchCount = 0;

  String? _error;

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  bool get _canSearch => _picked != null || _query.text.trim().length >= 2;

  /// Typing drops a picked suggestion and asks for new ones once the learner pauses.
  void _typed(String text) {
    setState(() {
      if (_picked != null && text != _picked!.label) {
        _picked = null;
        _season = null;
        _episode = null;
      }
    });
    _suggestTimer?.cancel();
    if (_picked != null || text.trim().length < _suggestFromChars) {
      setState(() => _suggestions = const []);
      return;
    }
    _suggestTimer = Timer(_suggestAfter, () => _suggest(text));
  }

  Future<void> _suggest(String text) async {
    try {
      final titles = await widget.service.titles(text);
      // Only for what is still typed, and never over a picked suggestion.
      if (!mounted || _query.text != text || _picked != null) return;
      setState(() => _suggestions = titles);
    } on SubtitleSearchException catch (e) {
      debugPrint('SUBTITLES: suggestions: $e'); // suggestions only help; the search still works
    }
  }

  void _pick(SubtitleTitle title) {
    _suggestTimer?.cancel();
    _query.text = title.label;
    _query.selection = TextSelection.collapsed(offset: title.label.length);
    setState(() {
      _picked = title;
      _season = null;
      _episode = null;
      _suggestions = const [];
    });
    _search();
  }

  Future<void> _search() async {
    if (!_canSearch) return;
    FocusScope.of(context).unfocus();
    _suggestTimer?.cancel();
    setState(() {
      _searching = true;
      _error = null;
      _suggestions = const [];
    });
    final count = ++_searchCount;
    bool latest() => mounted && count == _searchCount;
    try {
      final results = await widget.service.search(_query.text, title: _picked, season: _season, episode: _episode);
      if (latest()) setState(() => _results = results);
    } on SubtitleSearchException catch (e) {
      debugPrint('SUBTITLES: $e');
      if (latest()) setState(() => _error = SubtitleSearchMessages.of(e.error));
    } finally {
      if (latest()) setState(() => _searching = false);
    }
  }

  /// Picks [result]: its download starts and the dialog closes at once; a
  /// failed download shows when the import starts reading it.
  void _choose(SubtitleSearchResult result) {
    final release = result.release.isEmpty ? 'subtitles' : result.release;
    Navigator.pop(
      context,
      SubtitleSource(
        fileName: RegExp(r'\.(srt|vtt)$', caseSensitive: false).hasMatch(release) ? release : '$release.srt',
        bytes: widget.service.download(result.fileId).then((file) => file.bytes),
        title: result.label,
        imageUrl: result.imageUrl ?? _picked?.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Find subtitles'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('subtitle-search-query'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Film or series name',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _canSearch ? _search : null,
                ),
              ),
              onChanged: _typed,
              onSubmitted: (_) => _search(),
            ),
            if (_picked?.series ?? false) _seasonAndEpisode(context),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            Flexible(child: _body(context)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// The optional season and episode of a picked series.
  Widget _seasonAndEpisode(BuildContext context) {
    final seasons = _picked!.seasons;
    final episodes = seasons.where((s) => s.season == _season).firstOrNull?.episodes ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Text('Season'),
          const SizedBox(width: 8),
          DropdownButton<int?>(
            key: const Key('subtitle-search-season'),
            value: _season,
            onChanged: (season) {
              setState(() {
                _season = season;
                _episode = null;
              });
              _search();
            },
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              for (final s in seasons) DropdownMenuItem(value: s.season, child: Text('${s.season}')),
            ],
          ),
          const SizedBox(width: 16),
          const Text('Episode'),
          const SizedBox(width: 8),
          DropdownButton<int?>(
            key: const Key('subtitle-search-episode'),
            value: _episode,
            onChanged: _season == null
                ? null
                : (episode) {
                    setState(() => _episode = episode);
                    _search();
                  },
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              for (var e = 1; e <= episodes; e++) DropdownMenuItem(value: e, child: Text('$e')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_suggestions.isNotEmpty && !_searching) {
      return ListView(
        key: const Key('subtitle-search-suggestions'),
        shrinkWrap: true,
        children: [
          for (final t in _suggestions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 48,
                height: 72,
                child: t.imageUrl == null
                    ? Icon(t.series ? Icons.tv : Icons.movie_outlined)
                    : SubtitlePoster(t.imageUrl, width: 48, height: 72),
              ),
              title: Text(t.label),
              subtitle: Text(t.series
                  ? 'Series · ${t.seasons.length} ${t.seasons.length == 1 ? 'season' : 'seasons'}'
                  : 'Film'),
              onTap: () => _pick(t),
            ),
        ],
      );
    }
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final results = _results;
    if (results == null) return const Text(SubtitleSearchMessages.hint);
    if (results.isEmpty) return const Text(SubtitleSearchMessages.nothingFound);
    final small = Theme.of(context).textTheme.bodySmall;
    return ListView.builder(
      key: const Key('subtitle-search-results'),
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SubtitlePoster(r.imageUrl ?? _picked?.imageUrl, width: 48, height: 72),
          title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [r.release, '${r.downloads} downloads', if (r.hearingImpaired) 'for the hard of hearing'].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
          trailing: const Icon(Icons.download),
          onTap: () => _choose(r),
        );
      },
    );
  }
}

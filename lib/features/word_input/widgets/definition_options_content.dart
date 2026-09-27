import 'package:flutter/material.dart';

/// Content of the popup opened from the definition dots button
/// (definition-mode, spec AC-08): the dictionary's short senses for the row's
/// Word, each one tappable to become the definition. Mirrors
/// `TranslationOptionsContent`: when no senses are stored it offers a load
/// icon, awaits [onLoadSenses] itself (the popup lives in an overlay the
/// screen's setState cannot reach) and re-renders from the result.
class DefinitionOptionsContent extends StatefulWidget {
  /// Senses already stored for this row, if any.
  final List<String>? senses;

  /// Whether the Word field holds enough text to look up.
  final bool canLoad;

  /// Looks the senses up for the row's current Word and returns them — empty
  /// when the dictionary has none, null when it could not be reached. The
  /// screen owns the request.
  final Future<List<String>?> Function() onLoadSenses;

  final ValueChanged<String> onSelectSense;
  final VoidCallback onClose;

  const DefinitionOptionsContent({
    super.key,
    required this.onLoadSenses,
    required this.onSelectSense,
    required this.onClose,
    this.senses,
    this.canLoad = true,
  });

  @override
  State<DefinitionOptionsContent> createState() =>
      _DefinitionOptionsContentState();
}

class _DefinitionOptionsContentState extends State<DefinitionOptionsContent> {
  List<String>? _fetched;
  bool _busy = false;
  String? _notice;

  List<String> get _senses => _fetched ?? widget.senses ?? const [];

  Future<void> _load() async {
    if (_busy || !widget.canLoad) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final result = await widget.onLoadSenses();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _fetched = result;
      _notice = result == null
          ? 'Definitions are temporarily unavailable.'
          : result.isEmpty
              ? 'No definitions found for this word.'
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
            primary: false,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _senses.isEmpty ? _buildLoadPrompt() : _buildSenses(),
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
              tooltip: 'Load definitions',
              onPressed: widget.canLoad ? _load : null,
            ),
          const SizedBox(height: 8),
          Text(
            _notice ??
                (widget.canLoad
                    ? 'No definitions loaded yet. Tap to load.'
                    : 'Type a word to load definitions.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// One tappable card per sense, numbered in the dictionary's order.
  Widget _buildSenses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _senses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onSelectSense(_senses[i]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 15)),
                    Expanded(
                      child: Text(
                        _senses[i],
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

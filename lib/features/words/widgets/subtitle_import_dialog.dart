import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/subtitle_import_options.dart';
import 'subtitle_poster.dart';

/// A subtitle file for the import: chosen on the phone, or found by name —
/// then [bytes] may still be downloading, so Start never waits for it, and
/// [title] and [imageUrl] name the film and show its poster.
class SubtitleSource {
  SubtitleSource({required this.fileName, required this.bytes, this.title, this.imageUrl}) {
    // Marks a failure as seen, so a source dropped before Start never reports
    // an unhandled error; the import still sees it when it awaits [bytes].
    bytes.ignore();
  }

  /// A file chosen on the phone.
  factory SubtitleSource.file(XFile file) => SubtitleSource(fileName: file.name, bytes: file.readAsBytes());

  final String fileName;
  final Future<Uint8List> bytes;

  /// "My Brilliant Friend · S01E04 · Dissolving Margins", for a found file.
  final String? title;
  final String? imageUrl;
}

/// What Start in the import dialog hands to the import flow.
class SubtitleImportRequest {
  const SubtitleImportRequest({
    required this.fileName,
    required this.bytes,
    required this.level,
    required this.maximum,
    this.title,
    this.imageUrl,
  });

  final String fileName;

  /// The file's bytes; still downloading for a file found by name.
  final Future<Uint8List> bytes;
  final EnglishLevel level;
  final int maximum;

  /// The film's title and poster, for a file found by name.
  final String? title;
  final String? imageUrl;

  /// The file's extension, lower case, without the dot ('' when it has none).
  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }
}

/// The largest subtitle file the app accepts (spec §6: exactly 1 MB, AC-11).
const maxSubtitleFileBytes = 1048576;

/// The import dialog (words-from-subtitles SCR-02, sad §6 F1): a subtitle
/// file, the level and the maximum, opened with [initial] from
/// Settings. Resolves with the request on Start, or null when closed.
/// [pickFile] opens the phone's file chooser (SCR-03); it has no type filter
/// because `.srt` has no reliable MIME type on Android (sad §4) — the
/// extension is checked when the file is read after Start (F3).
/// [findByName], when given, offers "Find by name" beside "Choose file": it
/// finds a subtitle file by film name and hands it back at once, with its
/// title and poster, while it downloads — Start does not wait for it.
Future<SubtitleImportRequest?> showSubtitleImportDialog(
  BuildContext context, {
  required SubtitleImportPrefs initial,
  Future<XFile?> Function()? pickFile,
  Future<SubtitleSource?> Function(BuildContext context)? findByName,
}) {
  return showDialog<SubtitleImportRequest>(
    context: context,
    builder: (context) =>
        _SubtitleImportDialog(initial: initial, pickFile: pickFile ?? openFile, findByName: findByName),
  );
}

class _SubtitleImportDialog extends StatefulWidget {
  const _SubtitleImportDialog({required this.initial, required this.pickFile, this.findByName});

  final SubtitleImportPrefs initial;
  final Future<XFile?> Function() pickFile;
  final Future<SubtitleSource?> Function(BuildContext context)? findByName;

  @override
  State<_SubtitleImportDialog> createState() => _SubtitleImportDialogState();
}

class _SubtitleImportDialogState extends State<_SubtitleImportDialog> {
  late EnglishLevel _level = widget.initial.level;
  late int? _maximum = widget.initial.maximum;
  late final _maximumController = TextEditingController(text: '${widget.initial.maximum}');

  SubtitleSource? _source;
  String? _fileError;

  @override
  void dispose() {
    _maximumController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final file = await widget.pickFile();
    if (file == null || !mounted) return; // cancelled: the dialog stays as it was
    final tooLarge = await file.length() > maxSubtitleFileBytes;
    if (!mounted) return;
    setState(() {
      _source = tooLarge ? null : SubtitleSource.file(file);
      _fileError = tooLarge ? 'This file is too large. The largest file accepted is 1 MB.' : null;
    });
  }

  /// A file found by name comes back at once; the Worker checks its size.
  Future<void> _findByName() async {
    final source = await widget.findByName!(context);
    if (source == null || !mounted) return;
    setState(() {
      _source = source;
      _fileError = null;
    });
  }

  void _start() {
    final source = _source!;
    Navigator.pop(
      context,
      SubtitleImportRequest(
        fileName: source.fileName,
        bytes: source.bytes,
        level: _level,
        maximum: _maximum!,
        title: source.title,
        imageUrl: source.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maximumValid = _maximum != null && SubtitleImportPrefs.isValidMaximum(_maximum!);
    final canStart = _source != null && maximumValid;
    return AlertDialog(
      title: const Text('Words from subtitles'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.subtitles),
                    label: const Text('Choose file'),
                    onPressed: _chooseFile,
                  ),
                  if (widget.findByName != null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Find by name'),
                      onPressed: _findByName,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _chosen(context),
              if (_fileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_fileError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('My English level'),
                trailing: DropdownButton<EnglishLevel>(
                  value: _level,
                  onChanged: (level) {
                    if (level != null) setState(() => _level = level);
                  },
                  items: [
                    for (final level in EnglishLevel.values)
                      DropdownMenuItem(value: level, child: Text(level.label)),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Word maximum'),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('import-maximum'),
                    controller: _maximumController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      errorText: maximumValid ? null : 'The maximum must be from 1 to 100',
                      errorMaxLines: 2,
                    ),
                    onChanged: (text) => setState(() => _maximum = int.tryParse(text)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canStart ? _start : null,
          child: const Text('Start'),
        ),
      ],
    );
  }

  /// The chosen file's name — for a file found by name, its poster and title
  /// above the file's name.
  Widget _chosen(BuildContext context) {
    final source = _source;
    if (source == null) return const Text('No file chosen');
    final name = Text(source.fileName, maxLines: 2, overflow: TextOverflow.ellipsis);
    if (source.title == null && source.imageUrl == null) return name;
    return Row(
      children: [
        SubtitlePoster(source.imageUrl),
        if (source.imageUrl != null) const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (source.title != null)
                Text(source.title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              DefaultTextStyle.merge(style: Theme.of(context).textTheme.bodySmall, child: name),
            ],
          ),
        ),
      ],
    );
  }
}

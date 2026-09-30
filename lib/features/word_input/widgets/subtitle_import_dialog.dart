import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/subtitle_import_options.dart';

/// What Start in the import dialog hands to the import flow.
class SubtitleImportRequest {
  const SubtitleImportRequest({
    required this.fileName,
    required this.bytes,
    required this.purpose,
    required this.level,
    required this.maximum,
  });

  final String fileName;
  final Uint8List bytes;
  final ImportPurpose purpose;
  final EnglishLevel level;
  final int maximum;

  /// The file's extension, lower case, without the dot ('' when it has none).
  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }
}

/// The largest subtitle file the app accepts (spec §6: exactly 1 MB, AC-11).
const maxSubtitleFileBytes = 1048576;

/// The import dialog (words-from-subtitles SCR-02, sad §6 F1): a subtitle
/// file, the purpose, the level and the maximum, opened with [initial] from
/// Settings. Resolves with the request on Start, or null when closed.
/// [pickFile] opens the phone's file chooser (SCR-03); it has no type filter
/// because `.srt` has no reliable MIME type on Android (sad §4) — the
/// extension is checked when the file is read after Start (F3).
Future<SubtitleImportRequest?> showSubtitleImportDialog(
  BuildContext context, {
  required SubtitleImportPrefs initial,
  Future<XFile?> Function()? pickFile,
}) {
  return showDialog<SubtitleImportRequest>(
    context: context,
    builder: (context) => _SubtitleImportDialog(initial: initial, pickFile: pickFile ?? openFile),
  );
}

class _SubtitleImportDialog extends StatefulWidget {
  const _SubtitleImportDialog({required this.initial, required this.pickFile});

  final SubtitleImportPrefs initial;
  final Future<XFile?> Function() pickFile;

  @override
  State<_SubtitleImportDialog> createState() => _SubtitleImportDialogState();
}

class _SubtitleImportDialogState extends State<_SubtitleImportDialog> {
  late ImportPurpose _purpose = widget.initial.purpose;
  late EnglishLevel _level = widget.initial.level;
  late int? _maximum = widget.initial.maximum;
  late final _maximumController = TextEditingController(text: '${widget.initial.maximum}');

  XFile? _file;
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
    setState(() {
      _file = tooLarge ? null : file;
      _fileError = tooLarge ? 'This file is too large. The largest file accepted is 1 MB.' : null;
    });
  }

  Future<void> _start() async {
    final bytes = await _file!.readAsBytes();
    if (!mounted) return;
    Navigator.pop(
      context,
      SubtitleImportRequest(
        fileName: _file!.name,
        bytes: bytes,
        purpose: _purpose,
        level: _level,
        maximum: _maximum!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maximumValid = _maximum != null && SubtitleImportPrefs.isValidMaximum(_maximum!);
    final canStart = _file != null && maximumValid;
    return AlertDialog(
      title: const Text('Words from subtitles'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.subtitles),
                    label: const Text('Choose file'),
                    onPressed: _chooseFile,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _file?.name ?? 'No file chosen',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_fileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_fileError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              RadioGroup<ImportPurpose>(
                groupValue: _purpose,
                onChanged: (purpose) {
                  if (purpose != null) setState(() => _purpose = purpose);
                },
                child: Column(
                  children: [
                    for (final purpose in ImportPurpose.values)
                      RadioListTile<ImportPurpose>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(purpose.label),
                        value: purpose,
                      ),
                  ],
                ),
              ),
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
}

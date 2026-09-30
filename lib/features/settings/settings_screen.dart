import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subtitle_import_options.dart';
import '../../core/providers.dart';

/// Preferences for the app: the drag-and-drop mode toggle that used to be an
/// `IconButton` in the input screen's AppBar (task-13, reversing part of
/// task-10), the word detail mode — translation, definition or both
/// (definition-mode), and the subtitle import values, the "Update with each
/// import" switch and the subtitle model (words-from-subtitles, SCR-06).
///
/// The mode itself is not stored here -- it is `dragModeProvider`, read by the
/// input screen and written by this switch, so the two screens cannot disagree
/// (rule 2, docs/architecture.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDragMode = ref.watch(dragModeProvider);
    final detailMode = ref.watch(wordDetailModeProvider);
    final subtitle = ref.watch(subtitleImportPrefsProvider);
    final subtitleNotifier = ref.read(subtitleImportPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.drag_indicator),
            title: const Text('Drag and Drop мод'),
            subtitle: const Text('Reorder the words by dragging a row'),
            value: isDragMode,
            onChanged: (_) => ref.read(dragModeProvider.notifier).toggle(),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.translate),
            title: Text('Word details'),
            subtitle: Text('What each word row shows, exports and shares'),
          ),
          RadioGroup<WordDetailMode>(
            groupValue: detailMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(wordDetailModeProvider.notifier).set(mode);
              }
            },
            child: const Column(
              children: [
                RadioListTile<WordDetailMode>(
                  title: Text('Translation'),
                  value: WordDetailMode.translation,
                ),
                RadioListTile<WordDetailMode>(
                  title: Text('Definition'),
                  value: WordDetailMode.definition,
                ),
                RadioListTile<WordDetailMode>(
                  title: Text('Translation + definition'),
                  value: WordDetailMode.both,
                ),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.subtitles),
            title: Text('Subtitle import'),
            subtitle: Text('What the import dialog starts with'),
          ),
          RadioGroup<ImportPurpose>(
            groupValue: subtitle.purpose,
            onChanged: (purpose) {
              if (purpose != null) subtitleNotifier.setPurpose(purpose);
            },
            child: Column(
              children: [
                for (final purpose in ImportPurpose.values)
                  RadioListTile<ImportPurpose>(
                    title: Text(purpose.label),
                    value: purpose,
                  ),
              ],
            ),
          ),
          ListTile(
            title: const Text('English level'),
            trailing: DropdownButton<EnglishLevel>(
              value: subtitle.level,
              onChanged: (level) {
                if (level != null) subtitleNotifier.setLevel(level);
              },
              items: [
                for (final level in EnglishLevel.values)
                  DropdownMenuItem(value: level, child: Text(level.label)),
              ],
            ),
          ),
          ListTile(
            title: const Text('Word maximum'),
            trailing: SizedBox(
              width: 120,
              child: _MaximumField(
                value: subtitle.maximum,
                onValid: subtitleNotifier.setMaximum,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Update with each import'),
            subtitle: const Text('Starting an import saves its purpose, level and maximum here'),
            value: subtitle.updateEachImport,
            onChanged: subtitleNotifier.setUpdateEachImport,
          ),
          ListTile(
            title: const Text('AI model'),
            subtitle: const Text('Picks the subtitle words'),
            trailing: DropdownButton<SubtitleModel>(
              value: subtitle.model,
              onChanged: (model) {
                if (model != null) subtitleNotifier.setModel(model);
              },
              items: [
                for (final model in SubtitleModel.values)
                  DropdownMenuItem(value: model, child: Text(model.label)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The word maximum as a number field: a value outside 1–100 (or no value) is
/// shown as an error and not saved (AC-09). Controller and error stay in
/// widget State (rule 2).
class _MaximumField extends StatefulWidget {
  const _MaximumField({required this.value, required this.onValid});

  final int value;
  final Future<bool> Function(int) onValid;

  @override
  State<_MaximumField> createState() => _MaximumFieldState();
}

class _MaximumFieldState extends State<_MaximumField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  String? _error;

  @override
  void didUpdateWidget(_MaximumField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value arrives after the first build; show it unless the
    // learner is mid-edit with an invalid value.
    if (_error == null && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final value = int.tryParse(text);
    if (value == null || !SubtitleImportPrefs.isValidMaximum(value)) {
      setState(() => _error = 'The maximum must be from 1 to 100');
      return;
    }
    setState(() => _error = null);
    widget.onValid(value);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('subtitle-maximum'),
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.end,
      decoration: InputDecoration(errorText: _error, errorMaxLines: 2),
      onChanged: _changed,
    );
  }
}

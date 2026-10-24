import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subtitle_import_options.dart';
import '../../core/providers.dart';
import '../learn/entry/speech_engine_section.dart';
import '../words/photo_panel/looks/edge_glass.dart';

/// Preferences for the app: the drag-and-drop mode toggle that used to be an
/// `IconButton` in the input screen's AppBar (task-13, reversing part of
/// task-10), the word detail mode — translation, definition or both
/// (definition-mode), and the subtitle import values, the "Update with each
/// import" switch and the subtitle model (words-from-subtitles, SCR-06), and
/// the "Get dialogues from subtitles" switch (get-words-from-subtitles-improvment,
/// SCR-03). Where the photo panel's glass is liquid (iOS with shaders), a
/// Liquid glass section comes first (liquid-glass-tuning, owner 2026-10-19).
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
    final dialogues = ref.watch(dialoguesSettingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          if (EdgeGlass.liquidDrawn) ...[
            const LiquidGlassSection(),
            const Divider(),
          ],
          const SpeechEngineSection(),
          const Divider(),
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
            title: const Text('Rank words repeated close together higher'),
            subtitle: const Text('A word used again within 2 lines counts extra; off ranks by how often a word is used'),
            value: subtitle.boostCloseRepeats,
            onChanged: subtitleNotifier.setBoostCloseRepeats,
          ),
          SwitchListTile(
            title: const Text('Remove names'),
            subtitle: const Text('Skip words that are never written in lower case and look like names'),
            value: subtitle.removeNames,
            onChanged: subtitleNotifier.setRemoveNames,
          ),
          SwitchListTile(
            title: const Text('Update with each import'),
            subtitle: const Text('Starting an import saves its level and maximum here'),
            value: subtitle.updateEachImport,
            onChanged: subtitleNotifier.setUpdateEachImport,
          ),
          ListTile(
            title: const Text('Translate with'),
            subtitle: const Text('Google: free, no definitions or dialogues'),
            trailing: DropdownButton<SubtitleTranslator>(
              value: subtitle.translator,
              onChanged: (translator) {
                if (translator != null) subtitleNotifier.setTranslator(translator);
              },
              items: [
                for (final translator in SubtitleTranslator.values)
                  DropdownMenuItem(value: translator, child: Text(translator.label)),
              ],
            ),
          ),
          ListTile(
            title: const Text('AI model'),
            subtitle: const Text('Translates the subtitle words when AI is chosen'),
            trailing: DropdownButton<SubtitleModel>(
              key: const Key('subtitle-ai-model'),
              value: subtitle.model,
              onChanged: (model) {
                if (model != null) subtitleNotifier.setModel(model);
              },
              items: [
                for (final model in SubtitleModel.offeredBy(SubtitleTranslator.ai))
                  DropdownMenuItem(value: model, child: Text(model.label)),
              ],
            ),
          ),
          ListTile(
            title: const Text('OpenCode model'),
            subtitle: const Text('Translates the subtitle words when AI via OpenCode is chosen'),
            trailing: DropdownButton<SubtitleModel>(
              key: const Key('subtitle-opencode-model'),
              value: subtitle.opencodeModel,
              onChanged: (model) {
                if (model != null) subtitleNotifier.setOpencodeModel(model);
              },
              items: [
                for (final model in SubtitleModel.offeredBy(SubtitleTranslator.opencode))
                  DropdownMenuItem(value: model, child: Text(model.label)),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Get dialogues from subtitles'),
            subtitle: const Text('Only when an AI translates'),
            value: dialogues,
            onChanged: ref.read(dialoguesSettingProvider.notifier).set,
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

/// The Liquid glass section (liquid-glass-tuning, owner 2026-10-19): how
/// wide the bending band along the photo tab's and the half-open panel's
/// edge is, how far it bends and how much it blurs, each in percent of the
/// looks' own values, and Reset back to 100%.
class LiquidGlassSection extends ConsumerWidget {
  const LiquidGlassSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuning = ref.watch(liquidGlassTuningProvider);
    final notifier = ref.read(liquidGlassTuningProvider.notifier);
    Widget slider(String label, double value, ({double min, double max}) range,
            LiquidGlassTuning Function(double) withValue) =>
        _PercentSlider(
          label: label,
          value: value,
          min: range.min,
          max: range.max,
          onChanged: (v) => notifier.set(withValue(v)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: const Text('Liquid glass'),
          subtitle: const Text('The photo tab and panel'),
          trailing: TextButton(
            onPressed: tuning == LiquidGlassTuningNotifier.asDesigned
                ? null
                : notifier.reset,
            child: const Text('Reset'),
          ),
        ),
        slider('Thickness', tuning.thickness,
            LiquidGlassTuningNotifier.thicknessRange,
            (v) => (thickness: v, bending: tuning.bending, blur: tuning.blur)),
        slider('Bending', tuning.bending, LiquidGlassTuningNotifier.bendingRange,
            (v) => (thickness: tuning.thickness, bending: v, blur: tuning.blur)),
        slider('Blur', tuning.blur, LiquidGlassTuningNotifier.blurRange,
            (v) => (thickness: tuning.thickness, bending: tuning.bending, blur: v)),
      ],
    );
  }
}

/// One slider of [LiquidGlassSection], in 10% steps, with its percentage.
class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = '${(value * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 0),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 10).round(),
              label: percent,
              semanticFormatterCallback: (_) => '$label $percent',
              onChanged: (v) => onChanged((v * 10).round() / 10),
            ),
          ),
          SizedBox(
              width: 48, child: Text(percent, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

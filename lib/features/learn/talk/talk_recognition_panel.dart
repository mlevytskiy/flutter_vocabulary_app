import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../core/services/speech_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../words/photo_panel/looks/edge_glass.dart';

/// The recognition tab and its panel.
const talkRecognitionTabKey = ValueKey('talk-recognition-tab');
const talkRecognitionPanelKey = ValueKey('talk-recognition-panel');

/// How speech is recognised, shown on the Talk screen (owner, 2026-10-24):
/// a glass tab stuck to the right edge, like the Words screen's photo tab
/// ([EdgeGlass], look A's glass), with the mode's icon — a cloud while the
/// phone's recognizer may use Apple's or Google's servers, a phone while it
/// must stay on the phone. A tap opens a glass panel with the engine, the
/// mode (switchable for speech_to_text; speech_to_text_pro has no on-device
/// mode) and the language.
class TalkRecognitionTab extends StatefulWidget {
  const TalkRecognitionTab({
    super.key,
    required this.engine,
    required this.onDevice,
    required this.onEngine,
    required this.onOnDevice,
  });

  final SpeechEngine engine;

  /// The on-device setting; speech_to_text_pro ignores it.
  final bool onDevice;
  final ValueChanged<SpeechEngine> onEngine;
  final ValueChanged<bool> onOnDevice;

  /// Whether the mode in use keeps speech on the phone.
  static bool onPhone(SpeechEngine engine, bool onDevice) => engine == SpeechEngine.speechToText && onDevice;

  @override
  State<TalkRecognitionTab> createState() => _TalkRecognitionTabState();
}

class _TalkRecognitionTabState extends State<TalkRecognitionTab> {
  bool _open = false;

  // Look A's glass (side-bar-for-main-screen), so both tabs read as one family.
  static const _tabGlass = LiquidGlassSettings(
    thickness: 16,
    blur: 3,
    glassColor: Color(0x38FFFFFF),
    lightIntensity: .7,
    saturation: 1.6,
    refractiveIndex: 1.25,
    chromaticAberration: .02,
  );
  static const _panelGlass = LiquidGlassSettings(
    thickness: 26,
    blur: 9,
    glassColor: Color(0x4DFFFFFF),
    lightIntensity: .65,
    ambientStrength: .15,
    saturation: 1.6,
    refractiveIndex: 1.2,
    chromaticAberration: .015,
  );

  static const tabSize = Size(52, 58);
  static const panelSize = Size(286, 392);

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final scheme = Theme.of(context).colorScheme;
    final onPhone = TalkRecognitionTab.onPhone(widget.engine, widget.onDevice);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topRight,
      child: _open
          ? SizedBox.fromSize(
              key: talkRecognitionPanelKey,
              size: panelSize,
              child: EdgeGlass(
                settings: _panelGlass.copyWith(glassColor: decor.glassPanel),
                radius: 26,
                flare: 20,
                child: Material(type: MaterialType.transparency, child: _panel(context)),
              ),
            )
          : Semantics(
              button: true,
              label: onPhone ? 'Speech recognition: on the phone' : 'Speech recognition: online allowed',
              child: GestureDetector(
                key: talkRecognitionTabKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = true),
                child: SizedBox.fromSize(
                  size: tabSize,
                  child: EdgeGlass(
                    settings: _tabGlass.copyWith(glassColor: decor.glassTab),
                    radius: 16,
                    flare: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(onPhone ? Icons.smartphone_rounded : Icons.cloud_outlined,
                              size: 22, color: scheme.primary),
                          const SizedBox(height: 2),
                          Text(
                            onPhone ? 'Phone' : 'Online',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSurface),
                            textScaler: TextScaler.noScaling,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _panel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final pro = widget.engine == SpeechEngine.speechToTextPro;
    final onPhone = TalkRecognitionTab.onPhone(widget.engine, widget.onDevice);
    final small = theme.textTheme.bodySmall?.copyWith(color: decor.muted, height: 1.3);

    Widget mode({required bool phone, required String title, required String note}) {
      final selected = onPhone == phone;
      final enabled = !pro || !phone;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled && !selected ? () => widget.onOnDevice(phone) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20, color: selected ? scheme.primary : decor.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(note, style: small),
                ]),
              ),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(onPhone ? Icons.smartphone_rounded : Icons.cloud_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Speech recognition',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _open = false),
              ),
            ]),
            Text('Engine', style: small),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              for (final e in SpeechEngine.values)
                ChoiceChip(
                  label: Text(e.label, style: const TextStyle(fontSize: 12)),
                  selected: widget.engine == e,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => widget.onEngine(e),
                ),
            ]),
            const SizedBox(height: 8),
            Text('Mode', style: small),
            mode(
              phone: false,
              title: 'Online allowed',
              note: 'Apple or Google may use their servers when you are online. Usually more accurate.',
            ),
            mode(
              phone: true,
              title: 'On the phone only',
              note: pro
                  ? 'Not available with speech_to_text_pro.'
                  : 'Speech never leaves the phone and works offline. Often less accurate.',
            ),
            const SizedBox(height: 4),
            Text('Language: English (US)', style: small),
          ],
        ),
      ),
    );
  }
}

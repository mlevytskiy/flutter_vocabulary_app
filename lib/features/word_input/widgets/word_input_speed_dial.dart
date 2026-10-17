import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../../core/theme/app_theme.dart';

import 'quizlet_logo_icon.dart';

/// The word-input screen's floating speed-dial FAB: take a photo (green),
/// import words from subtitles (words-from-subtitles, dark grey) or from a
/// Quizlet set (import-from-quizlet, blue, in Screenshot's old place).
/// Settings is not here -- it has its own bottom-left button on the screen
/// (task-13), so this dial carries the capture actions only.
class WordInputSpeedDial extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onFromSubtitles;
  final VoidCallback onImportFromQuizlet;

  const WordInputSpeedDial({
    super.key,
    required this.onTakePhoto,
    required this.onFromSubtitles,
    required this.onImportFromQuizlet,
  });

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: decor.fab,
      foregroundColor: decor.onFab,
      activeBackgroundColor: decor.fabActive,
      activeForegroundColor: decor.onFab,
      visible: true,
      closeManually: false,
      curve: Curves.bounceIn,
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      elevation: 8.0,
      shape: const CircleBorder(),
      children: [
        SpeedDialChild(
          child: const Icon(Icons.camera_alt),
          label: 'Get words from photo',
          backgroundColor: decor.dialPhoto,
          foregroundColor: decor.onDial,
          onTap: onTakePhoto,
        ),
        SpeedDialChild(
          child: const Icon(Icons.closed_caption),
          label: 'From subtitles',
          backgroundColor: decor.dialSubtitles,
          foregroundColor: decor.onDial,
          onTap: onFromSubtitles,
        ),
        SpeedDialChild(
          child: const QuizletLogoIcon(),
          label: 'Import from Quizlet',
          backgroundColor: decor.dialQuizlet,
          foregroundColor: decor.onDial,
          onTap: onImportFromQuizlet,
        ),
      ],
    );
  }
}

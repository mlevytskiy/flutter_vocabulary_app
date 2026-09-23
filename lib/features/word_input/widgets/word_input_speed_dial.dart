import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

/// The word-input screen's floating speed-dial FAB: take a photo, take a
/// screenshot, or open the Settings screen.
class WordInputSpeedDial extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onScreenshot;
  final VoidCallback onSettings;

  const WordInputSpeedDial({
    super.key,
    required this.onTakePhoto,
    required this.onScreenshot,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.red[700],
      activeForegroundColor: Colors.white,
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
          label: 'Take Photo',
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          onTap: onTakePhoto,
        ),
        SpeedDialChild(
          child: const Icon(Icons.screenshot),
          label: 'Screenshot',
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          onTap: onScreenshot,
        ),
        SpeedDialChild(
          child: const Icon(Icons.settings),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          onTap: onSettings,
        ),
      ],
    );
  }
}

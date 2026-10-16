import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

/// The Collections screen's plus button, styled like the main screen's
/// `WordInputSpeedDial`: New folder and New collection.
class CollectionsSpeedDial extends StatelessWidget {
  const CollectionsSpeedDial({
    super.key,
    required this.onNewFolder,
    required this.onNewCollection,
  });

  final VoidCallback onNewFolder;
  final VoidCallback onNewCollection;

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
          child: const Icon(Icons.create_new_folder_outlined),
          label: 'New folder',
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          onTap: onNewFolder,
        ),
        SpeedDialChild(
          child: const Icon(Icons.library_add_outlined),
          label: 'New collection',
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          onTap: onNewCollection,
        ),
      ],
    );
  }
}

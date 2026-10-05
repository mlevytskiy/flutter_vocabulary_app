import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Asks where the photo for "Get words from photo" comes from: Camera or
/// Gallery (photo-from-gallery sad §4, AC-01). Returns `null` when the
/// learner closes the dialog by tapping outside it or going back (AC-05).
/// It is a dialog, not a route (CLAUDE.md rule 1).
Future<ImageSource?> showPhotoSourceDialog(BuildContext context) {
  return showDialog<ImageSource>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Get words from photo'),
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Camera'),
          onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Gallery'),
          onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
        ),
      ],
    ),
  );
}

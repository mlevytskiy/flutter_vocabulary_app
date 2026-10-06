import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Asks where the photo for "Get words from photo" comes from: Camera or
/// Photos (photo-from-gallery sad §4, AC-01), as two bordered cards side by
/// side, each an icon above its name. Returns `null` when the learner closes
/// the dialog by tapping outside it or going back (AC-05).
/// It is a dialog, not a route (CLAUDE.md rule 1).
Future<ImageSource?> showPhotoSourceDialog(BuildContext context) {
  return showDialog<ImageSource>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Get words from photo'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SourceCard(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
              ),
            ),
            Expanded(
              child: _SourceCard(
                icon: Icons.photo_library,
                label: 'Photos',
                onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 0,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: scheme.primary),
              const SizedBox(height: 10),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

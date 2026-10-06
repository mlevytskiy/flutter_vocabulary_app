import 'package:flutter/material.dart';

import 'exercises.dart';

/// The placeholder for an exercise that is not ready yet (learn-part-step-1,
/// SCR-04). Only reached from Start, which offers available exercises only.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final name = exercises
        .firstWhere(
          (e) => e.id == exerciseId,
          orElse: () => exercises.first,
        )
        .name;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Coming soon — this exercise is not ready yet.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to exercises'),
            ),
          ],
        ),
      ),
    );
  }
}

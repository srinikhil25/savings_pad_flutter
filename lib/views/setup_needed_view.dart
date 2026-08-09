import 'package:flutter/material.dart';

/// Shown when Firebase.initializeApp fails — almost always because
/// `flutterfire configure` has not been run yet.
///
/// A screen with instructions is far better than a crash, especially when the
/// app is being demonstrated live.
class SetupNeededView extends StatelessWidget {
  const SetupNeededView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Firebase is not configured',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    'Run these once in the project root, then restart the app:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _Code('dart pub global activate flutterfire_cli'),
                  const SizedBox(height: 8),
                  _Code('flutterfire configure'),
                  const SizedBox(height: 20),
                  Text('Details', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

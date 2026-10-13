import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Blok pesan error inline dengan tombol retry. Dipakai bersama oleh
/// Beranda, Cari, dan Detail. liveRegion membuat pesan terumumkan ke
/// screen reader tanpa perlu fokus.
class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ResepinSpacing.lg),
        decoration: ResepinDecorations.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 24,
              color: ResepinColors.destructive,
            ),
            const SizedBox(height: ResepinSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: ResepinSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

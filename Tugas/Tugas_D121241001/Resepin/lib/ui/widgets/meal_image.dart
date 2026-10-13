import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Gambar resep dari TheMealDB dengan placeholder loading, fallback gagal
/// muat, dan retry sungguhan (request ulang), tanpa dependensi tambahan.
/// Widget mengisi ukuran parent — kartu memakai AspectRatio agar layout
/// tidak bergeser.
class MealImage extends StatefulWidget {
  const MealImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  /// Null/kosong berarti API tidak menyediakan gambar: tampil placeholder
  /// tanpa tombol retry (tidak ada yang bisa di-retry).
  final String? url;
  final BoxFit fit;

  /// Label untuk screen reader. Kosongkan bila nama resep sudah tampil
  /// sebagai teks di dekat gambar (maka gambar cukup dekoratif).
  final String? semanticLabel;

  @override
  State<MealImage> createState() => _MealImageState();
}

class _MealImageState extends State<MealImage> {
  int _attempt = 0;

  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return const _ImageFallback(message: null);
    }

    // Key berubah tiap retry agar Image memulai request baru; error tidak
    // di-cache oleh ImageCache sehingga attempt berikutnya benar-benar
    // mengunduh ulang.
    return Image.network(
      url,
      key: ValueKey('$url#$_attempt'),
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ImageFallback(message: null);
      },
      errorBuilder: (context, error, stackTrace) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 140 || constraints.maxHeight < 100;
            return _ImageFallback(
              message: compact ? null : 'Gambar gagal dimuat',
              onRetry: _retry,
            );
          },
        );
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = message == null;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.restaurant_outlined,
          size: compact ? 20 : 28,
          color: ResepinColors.borderStrong,
        ),
        if (!compact) ...[
          const SizedBox(height: ResepinSpacing.sm),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (!compact && onRetry != null) ...[
          const SizedBox(height: ResepinSpacing.xs),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ],
    );

    final box = Container(
      color: ResepinColors.imagePlaceholder,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ResepinSpacing.sm),
      child: content,
    );

    if (onRetry == null) return box;

    // Kotak kecil tidak muat tombol: seluruh kotak jadi target retry,
    // diberi label semantics agar tetap terbaca screen reader.
    return Semantics(
      button: true,
      label: 'Muat ulang gambar',
      child: GestureDetector(onTap: onRetry, child: box),
    );
  }
}

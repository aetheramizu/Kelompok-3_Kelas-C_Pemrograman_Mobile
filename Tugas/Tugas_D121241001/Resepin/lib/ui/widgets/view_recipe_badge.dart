import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Label kecil "Lihat resep" yang ditempatkan di sudut gambar kartu,
/// sebagai penanda bahwa kartu dapat diketuk. Ukurannya sengaja mungil
/// agar tidak menutupi foto; hanya sudut kecil yang tertutup.
///
/// Skala teks dibatasi 1.3: label ini murni penanda afinitas, sementara
/// judul resep tetap mengikuti skala teks pengguna secara penuh.
class ViewRecipeBadge extends StatelessWidget {
  const ViewRecipeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ResepinSpacing.sm,
          vertical: ResepinSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: ResepinColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(ResepinRadius.chip),
          border: Border.all(color: ResepinColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lihat resep',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: ResepinColors.primaryStrong,
              ),
            ),
            SizedBox(width: ResepinSpacing.xs),
            Icon(
              Icons.arrow_forward,
              size: 14,
              color: ResepinColors.primaryStrong,
            ),
          ],
        ),
      ),
    );
  }
}

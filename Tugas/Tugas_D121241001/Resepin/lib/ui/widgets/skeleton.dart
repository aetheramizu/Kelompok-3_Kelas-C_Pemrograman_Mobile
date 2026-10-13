import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Blok skeleton polos tanpa animasi maupun dependensi tambahan. Proporsinya
/// harus mengikuti konten yang direpresentasikan agar layout tidak bergeser
/// saat data asli tiba.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = ResepinRadius.card,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ResepinColors.imagePlaceholder,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

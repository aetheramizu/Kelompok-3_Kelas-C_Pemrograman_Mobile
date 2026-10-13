import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ResepinApp());
}

/// Aplikasi Resepin — penemuan resep berbasis TheMealDB API.
class ResepinApp extends StatelessWidget {
  const ResepinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resepin',
      debugShowCheckedModeBanner: false,
      theme: buildResepinTheme(),
      home: const MainShell(),
    );
  }
}

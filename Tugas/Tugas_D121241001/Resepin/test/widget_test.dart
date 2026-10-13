import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resepin/main.dart';

void main() {
  // Di lingkungan test tidak ada jaringan: request API gagal cepat dan
  // layar menampilkan state error-nya. Assertion hanya mengunci elemen
  // statis (header, navigasi) agar test tetap deterministik.
  testWidgets('Beranda menampilkan header dan navigasi bawah', (tester) async {
    await tester.pumpWidget(const ResepinApp());
    await tester.pump();

    expect(find.text('Resepin'), findsOneWidget);
    expect(find.text('Mau masak apa hari ini?'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Cari'), findsOneWidget);
  });

  testWidgets('Berpindah tab menampilkan layar Cari', (tester) async {
    await tester.pumpWidget(const ResepinApp());
    await tester.pump();

    await tester.tap(find.text('Cari'));
    await tester.pump();

    expect(find.text('Cari resep'), findsOneWidget);
    expect(find.text('Mau masak apa hari ini?'), findsNothing);
  });

  testWidgets('Pencarian submit-driven: kosong diabaikan, gagal menawarkan '
      'retry, dan kata kunci bertahan', (tester) async {
    await tester.pumpWidget(const ResepinApp());
    await tester.pump();

    await tester.tap(find.text('Cari'));
    await tester.pump();

    // State bantuan awal.
    expect(find.textContaining('Ketik nama masakan'), findsOneWidget);

    // Submit whitespace: tetap di state awal, tidak ada request.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.textContaining('Ketik nama masakan'), findsOneWidget);

    // Query valid: request berjalan lalu gagal (tanpa jaringan di test)
    // → state error dengan retry, dan kata kunci tetap di field.
    await tester.enterText(find.byType(TextField), 'soup');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('soup'), findsOneWidget);
  });
}

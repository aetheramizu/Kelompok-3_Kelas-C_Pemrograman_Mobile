import 'dart:io';

double hitungDiskon(double subtotal) {
  if (subtotal > 200000) {
    return subtotal * 0.10; // Diskon 10%
  } else if (subtotal > 100000) {
    return subtotal * 0.05; // Diskon 5%
  }

  return 0;
}

void main() {
  // Input jumlah jenis barang
  stdout.write("Masukkan jumlah jenis barang: ");
  int n = int.parse(stdin.readLineSync()!);

  List<String> namaBarang = [];
  List<double> hargaBarang = [];
  List<int> jumlahBarang = [];

  double subtotal = 0;

  // Input data setiap barang
  for (int i = 0; i < n; i++) {
    print("\nBarang ke-${i + 1}");

    stdout.write("Nama barang   : ");
    String nama = stdin.readLineSync()!;

    stdout.write("Harga barang  : ");
    double harga = double.parse(stdin.readLineSync()!);

    stdout.write("Jumlah barang : ");
    int jumlah = int.parse(stdin.readLineSync()!);

    namaBarang.add(nama);
    hargaBarang.add(harga);
    jumlahBarang.add(jumlah);

    // Menambahkan total harga barang ke subtotal
    subtotal += harga * jumlah;
  }

  // Menghitung diskon dan total pembayaran
  double diskon = hitungDiskon(subtotal);
  double totalPembayaran = subtotal - diskon;

  // Output
  print("\n========== KERANJANG BELANJA ==========");

  for (int i = 0; i < n; i++) {
    double totalBarang = hargaBarang[i] * jumlahBarang[i];

    print(
      "${i + 1}. ${namaBarang[i]} | "
      "Rp${hargaBarang[i].toStringAsFixed(0)} x "
      "${jumlahBarang[i]} = "
      "Rp${totalBarang.toStringAsFixed(0)}"
    );
  }

  print("---------------------------------------");
  print("Subtotal          : Rp${subtotal.toStringAsFixed(0)}");
  print("Diskon            : Rp${diskon.toStringAsFixed(0)}");
  print("Total Pembayaran  : Rp${totalPembayaran.toStringAsFixed(0)}");
  print("=======================================");
}
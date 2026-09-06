void main() {
  // 01 Menyimpan daftar harga (katalog produk)
  Map<String, double> daftarHarga = {
    'Buku Tulis': 5000.0,
    'Pensil': 2000.0,
    'Penghapus': 1000.0,
    'Penggaris': 3000.0,
    'Tas Sekolah': 150000.0,
  };

  // 02 Menyimpan daftar belanjaan (nama barang dan jumlah)
  Map<String, int> daftarBelanjaan = {
    'Buku Tulis': 5,
    'Pensil': 3,
    'Tas Sekolah': 1,
  };

  print('=== Struk Belanja ===');
  
  // Menghitung subtotal dari daftar belanjaan
  double subtotal = hitungSubtotal(daftarHarga, daftarBelanjaan);
  
  // 03 Menentukan case diskon belanjaan
  double persentaseDiskon = tentukanDiskon(subtotal);
  double nilaiDiskon = subtotal * persentaseDiskon;
  
  // Menghitung total akhir
  double totalPembayaran = subtotal - nilaiDiskon;
  
  // 04 Menampilkan total akhir belanjaan
  print('-----------------------------');
  print('Subtotal         : Rp ${subtotal.toStringAsFixed(0)}');
  print('Diskon (${(persentaseDiskon * 100).toStringAsFixed(0)}%)     : Rp ${nilaiDiskon.toStringAsFixed(0)}');
  print('Total Pembayaran : Rp ${totalPembayaran.toStringAsFixed(0)}');
}

// Function untuk menghitung subtotal menggunakan loop dan operator
double hitungSubtotal(Map<String, double> harga, Map<String, int> belanjaan) {
  double subtotal = 0;
  
  // Menggunakan loop untuk iterasi setiap item di daftar belanjaan
  belanjaan.forEach((barang, jumlah) {
    if (harga.containsKey(barang)) {
      double hargaSatuan = harga[barang]!;
      double totalHargaBarang = hargaSatuan * jumlah;
      subtotal += totalHargaBarang; // Menggunakan operator +=
      
      print('$barang (x$jumlah) : Rp ${totalHargaBarang.toStringAsFixed(0)}');
    } else {
      print('$barang tidak ditemukan di daftar harga!');
    }
  });
  
  return subtotal;
}

// Function untuk menentukan diskon menggunakan if / else if / else dan comparison operator
double tentukanDiskon(double subtotal) {
  // Aturan diskon berdasarkan total belanja
  if (subtotal >= 100000) {
    return 0.15; // Diskon 15% jika belanja >= 100.000
  } else if (subtotal >= 50000) {
    return 0.10; // Diskon 10% jika belanja >= 50.000
  } else if (subtotal >= 20000) {
    return 0.05; // Diskon 5% jika belanja >= 20.000
  } else {
    return 0.0;  // Tidak ada diskon
  }
}

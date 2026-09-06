void main() {
  List<Map<String, dynamic>> keranjangBelanja = [
    {'nama': 'Smartphone 5G', 'harga': 3500000, 'jumlah': 1},
    {'nama': 'TWS Earbuds', 'harga': 450000, 'jumlah': 2},
    {'nama': 'Kabel Data Type-C', 'harga': 75000, 'jumlah': 3},
    {'nama': 'Powerbank 10000mAh', 'harga': 250000, 'jumlah': 1},
  ];

  // Memanggil function untuk memproses keranjang belanja
  prosesPembayaran(keranjangBelanja);
}

// Function utama untuk mengolah perhitungan (Subtotal & Total Akhir)
void prosesPembayaran(List<Map<String, dynamic>> keranjang) {
  double subtotal = 0;

  print('=== DAFTAR PRODUK ELEKTRONIK ===');
  
  // Loop untuk mengatur alur program dan menampilkan daftar produk
  for (var item in keranjang) {
    String nama = item['nama'];
    int harga = item['harga'];
    int jumlah = item['jumlah'];
    
    // Operator matematika untuk menghitung total per item
    double totalPerItem = (harga * jumlah).toDouble();
    subtotal += totalPerItem; // Menambahkan ke subtotal

    print('- $nama (x$jumlah) \t: Rp $totalPerItem');
  }

  // Memanggil function untuk menentukan case diskon
  double diskon = hitungDiskon(subtotal);
  
  // Menghitung total akhir pembayaran
  double totalAkhir = subtotal - diskon;

  // Menampilkan subtotal, diskon, dan total akhir pada output
  print('\n=== RINGKASAN TRANSAKSI ===');
  print('Subtotal Belanja  : Rp $subtotal');
  print('Potongan Diskon   : Rp $diskon');
  print('-----------------------------');
  print('TOTAL PEMBAYARAN  : Rp $totalAkhir');
}

// Function khusus untuk menentukan diskon belanjaan
double hitungDiskon(double totalBelanja) {
  double nilaiDiskon = 0;

  // Menggunakan if / else if / else dan operator comparison
  // Ketentuan diskon disesuaikan untuk rentang harga barang elektronik:
  
  if (totalBelanja >= 4000000) {
    // Diskon 10% jika belanja di atas atau sama dengan 4 Juta
    nilaiDiskon = totalBelanja * 0.10;
    print('\n>> Hore! Anda mendapat diskon 10% (Belanja >= Rp 4.000.000) <<');
  } else if (totalBelanja >= 1500000) {
    // Diskon 5% jika belanja di atas atau sama dengan 1,5 Juta
    nilaiDiskon = totalBelanja * 0.05;
    print('\n>> Selamat! Anda mendapat diskon 5% (Belanja >= Rp 1.500.000) <<');
  } else {
    // Tidak ada diskon
    nilaiDiskon = 0;
    print('\n>> Belum ada diskon untuk nominal belanja ini. <<');
  }

  return nilaiDiskon;
}
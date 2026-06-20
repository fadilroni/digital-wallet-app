import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class Transaksi {
  String id;
  double nominal;
  String catatan;
  String tipe;
  String kategori;
  String akun;
  DateTime tanggal;

  Transaksi({
    required this.id,
    required this.nominal,
    required this.catatan,
    required this.tipe,
    required this.kategori,
    required this.akun,
    required this.tanggal,
  });
}

// STRUKTUR UNTUK ASSET CRYPTO
class Asset {
  String id;
  String symbol;
  String name;
  double quantity;
  double buyPrice; // rata-rata harga beli dalam IDR

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.buyPrice,
  });
}

class CryptoMaster {
  final String symbol;
  final String name;

  const CryptoMaster({required this.symbol, required this.name});
}

const List<CryptoMaster> cryptoList = [
  CryptoMaster(symbol: 'BTC', name: 'Bitcoin'),
  CryptoMaster(symbol: 'ETH', name: 'Ethereum'),
  CryptoMaster(symbol: 'USDT', name: 'Tether USD'),
  CryptoMaster(symbol: 'BNB', name: 'BNB'),
  CryptoMaster(symbol: 'SOL', name: 'Solana'),
  CryptoMaster(symbol: 'XRP', name: 'XRP'),
  CryptoMaster(symbol: 'ADA', name: 'Cardano'),
  CryptoMaster(symbol: 'DOGE', name: 'Dogecoin'),
  CryptoMaster(symbol: 'TRX', name: 'Tron'),
  CryptoMaster(symbol: 'POL', name: 'Polygon (POL)'),
  CryptoMaster(symbol: 'DOT', name: 'Polkadot'),
  CryptoMaster(symbol: 'AVAX', name: 'Avalanche'),
  CryptoMaster(symbol: 'LINK', name: 'Chainlink'),
  CryptoMaster(symbol: 'LTC', name: 'Litecoin'),
  CryptoMaster(symbol: 'SHIB', name: 'Shiba Inu'),
  CryptoMaster(symbol: 'XLM', name: 'Stellar'),
  CryptoMaster(symbol: 'ATOM', name: 'Cosmos'),
  CryptoMaster(symbol: 'NEAR', name: 'NEAR Protocol'),
  CryptoMaster(symbol: 'XAUT', name: 'Tether Gold'),
  CryptoMaster(symbol: 'UNI', name: 'Uniswap'),
  CryptoMaster(symbol: 'ARB', name: 'Arbitrum'),
  CryptoMaster(symbol: 'OP', name: 'Optimism'),
  CryptoMaster(symbol: 'PEPE', name: 'Pepe'),
  CryptoMaster(symbol: 'TON', name: 'Toncoin'),
  CryptoMaster(symbol: 'SUI', name: 'Sui'),
  CryptoMaster(symbol: 'APT', name: 'Aptos'),
  CryptoMaster(symbol: 'SAND', name: 'The Sandbox'),
  CryptoMaster(symbol: 'MANA', name: 'Decentraland'),
  CryptoMaster(symbol: 'FTM', name: 'Fantom'),
  CryptoMaster(symbol: 'INJ', name: 'Injective'),
  CryptoMaster(symbol: 'SEI', name: 'Sei'),
];

// STRUKTUR BARU UNTUK KATEGORI
class KategoriModel {
  String nama;
  String tipe; // "Pengeluaran" atau "Pemasukan"
  IconData ikon; // Menyimpan logo ikon

  KategoriModel({required this.nama, required this.tipe, required this.ikon});
}

// MODEL UNTUK UTANG / PIUTANG
// tipe transaksi: "Piutang" = orang lain berhutang ke kita, "Hutang" = kita berhutang ke orang lain
class TransaksiUtang {
  String id;
  double nominal;
  String tipe; // "Piutang" atau "Hutang"
  String catatan;
  DateTime tanggal;
  String akun;

  TransaksiUtang({
    required this.id,
    required this.nominal,
    required this.tipe,
    required this.catatan,
    required this.tanggal,
    required this.akun,
  });
}

class KontakUtang {
  String id;
  String nama;
  String telepon;
  DateTime tanggalDibuat;
  List<TransaksiUtang> transaksi;

  KontakUtang({
    required this.id,
    required this.nama,
    required this.telepon,
    required this.tanggalDibuat,
    required this.transaksi,
  });

  // Positif = orang berhutang ke kita (Piutang), Negatif = kita berhutang ke orang (Hutang)
  double get saldo {
    double total = 0;
    for (var tx in transaksi) {
      if (tx.tipe == "Piutang") {
        total += tx.nominal;
      } else {
        total -= tx.nominal;
      }
    }
    return total;
  }
}

// DAFTAR PILIHAN LOGO/IKON YANG BISA DIPILIH USER
List<IconData> daftarPilihanIkon = [
  Icons.fastfood, // Makanan
  Icons.directions_car, // Transportasi
  Icons.shopping_bag, // Belanja
  Icons.receipt_long, // Tagihan
  Icons.payments, // Gaji
  Icons.card_giftcard, // Pemberian
  Icons.trending_up, // Investasi
  Icons.home, // Rumah
  Icons.bolt, // Listrik/Listrik
  Icons.medical_services, // Kesehatan
  Icons.smoking_rooms, // Rokok/Vape
];

// DATA GLOBAL (akan diisi oleh database Hive saat aplikasi dimulai)
List<KategoriModel> masterKategori = [];
List<String> masterAkun = [];
String akunUtama = "";
double limitPengeluaran = 0.0;
Map<String, double> saldoAwalMap = {};
List<Transaksi> daftarTransaksi = [];
List<KontakUtang> daftarKontakUtang = [];
List<Asset> daftarAsset = [];
bool isHideSaldoGlobal = true;

// Serialisasi & Deserialisasi Asset
Map<String, dynamic> assetToMap(Asset a) {
  return {
    'id': a.id,
    'symbol': a.symbol,
    'name': a.name,
    'quantity': a.quantity,
    'buyPrice': a.buyPrice,
  };
}

Asset assetFromMap(Map<dynamic, dynamic> map) {
  return Asset(
    id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    symbol: map['symbol']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
  );
}

// Serialisasi & Deserialisasi TransaksiUtang
Map<String, dynamic> transaksiUtangToMap(TransaksiUtang t) {
  return {
    'id': t.id,
    'nominal': t.nominal,
    'tipe': t.tipe,
    'catatan': t.catatan,
    'tanggal': t.tanggal.toIso8601String(),
    'akun': t.akun,
  };
}

TransaksiUtang transaksiUtangFromMap(Map<dynamic, dynamic> map) {
  return TransaksiUtang(
    id: map['id'] ?? '',
    nominal: (map['nominal'] as num?)?.toDouble() ?? 0.0,
    tipe: map['tipe'] ?? 'Memberi',
    catatan: map['catatan'] ?? '',
    tanggal: DateTime.tryParse(map['tanggal'] ?? '') ?? DateTime.now(),
    akun: map['akun'] ?? 'Tunai',
  );
}

// Serialisasi & Deserialisasi KontakUtang
Map<String, dynamic> kontakUtangToMap(KontakUtang k) {
  return {
    'id': k.id,
    'nama': k.nama,
    'telepon': k.telepon,
    'tanggalDibuat': k.tanggalDibuat.toIso8601String(),
    'transaksi': k.transaksi.map((t) => transaksiUtangToMap(t)).toList(),
  };
}

KontakUtang kontakUtangFromMap(Map<dynamic, dynamic> map) {
  final List<dynamic>? txList = map['transaksi'];
  return KontakUtang(
    id: map['id'] ?? '',
    nama: map['nama'] ?? '',
    telepon: map['telepon'] ?? '',
    tanggalDibuat:
        DateTime.tryParse(map['tanggalDibuat'] ?? '') ?? DateTime.now(),
    transaksi: txList != null
        ? txList.map((t) => transaksiUtangFromMap(t as Map)).toList()
        : [],
  );
}

// ================= HIVE DATABASE & EXPORT/IMPORT =================

// Serialisasi & Deserialisasi Transaksi
Map<String, dynamic> transaksiToMap(Transaksi t) {
  return {
    'id': t.id,
    'nominal': t.nominal,
    'catatan': t.catatan,
    'tipe': t.tipe,
    'kategori': t.kategori,
    'akun': t.akun,
    'tanggal': t.tanggal.toIso8601String(),
  };
}

Transaksi transaksiFromMap(Map<dynamic, dynamic> map) {
  return Transaksi(
    id: map['id'] ?? '',
    nominal: (map['nominal'] as num?)?.toDouble() ?? 0.0,
    catatan: map['catatan'] ?? '',
    tipe: map['tipe'] ?? '',
    kategori: map['kategori'] ?? '',
    akun: map['akun'] ?? '',
    tanggal: DateTime.tryParse(map['tanggal'] ?? '') ?? DateTime.now(),
  );
}

// Serialisasi & Deserialisasi Kategori
Map<String, dynamic> kategoriToMap(KategoriModel k) {
  // Simpan index posisi ikon di daftarPilihanIkon (bukan codePoint)
  int ikonIndex = daftarPilihanIkon.indexOf(k.ikon);
  if (ikonIndex < 0) ikonIndex = 0; // fallback jika tidak ditemukan
  return {'nama': k.nama, 'tipe': k.tipe, 'ikon': ikonIndex};
}

KategoriModel kategoriFromMap(Map<dynamic, dynamic> map) {
  // Ambil ikon berdasarkan index; fallback ke index 0 jika tidak valid
  final rawValue = map['ikon'] as int? ?? 0;
  // Kompatibilitas: nilai lama berupa codePoint (> 1000), cari di list
  IconData resolvedIcon;
  if (rawValue < daftarPilihanIkon.length) {
    resolvedIcon = daftarPilihanIkon[rawValue];
  } else {
    // Coba cocokkan berdasarkan codePoint (data lama)
    resolvedIcon = daftarPilihanIkon.firstWhere(
      (icon) => icon.codePoint == rawValue,
      orElse: () => daftarPilihanIkon[0],
    );
  }
  return KategoriModel(
    nama: map['nama'] ?? '',
    tipe: map['tipe'] ?? '',
    ikon: resolvedIcon,
  );
}

// Inisialisasi Database Hive
Future<void> initDatabase() async {
  await Hive.initFlutter();
  await Hive.openBox('dompet_pribadi_box');
  loadData();
}

// Menyimpan data ke Hive
void saveData() {
  final box = Hive.box('dompet_pribadi_box');

  final transaksiMaps = daftarTransaksi.map((t) => transaksiToMap(t)).toList();
  final kategoriMaps = masterKategori.map((k) => kategoriToMap(k)).toList();
  final kontakUtangMaps = daftarKontakUtang
      .map((k) => kontakUtangToMap(k))
      .toList();
  final assetMaps = daftarAsset.map((a) => assetToMap(a)).toList();

  box.put('transaksi', transaksiMaps);
  box.put('kategori', kategoriMaps);
  box.put('akun', masterAkun);
  box.put('akunUtama', akunUtama);
  box.put('limitPengeluaran', limitPengeluaran);
  box.put('saldoAwalMap', saldoAwalMap);
  box.put('kontakUtang', kontakUtangMaps);
  box.put('asset', assetMaps);
  box.put('isHideSaldo', isHideSaldoGlobal);
}

// Memuat data dari Hive
void loadData() {
  final box = Hive.box('dompet_pribadi_box');

  // Load isHideSaldo
  isHideSaldoGlobal = box.get('isHideSaldo', defaultValue: true);

  // Load Akun (jika kosong, buat default)
  final List<dynamic>? savedAkun = box.get('akun');
  if (savedAkun != null) {
    masterAkun = List<String>.from(savedAkun);
  } else {
    masterAkun = ["Tunai", "SeaBank", "SuperBank", "Krom Bank"];
  }

  // Load Akun Utama
  akunUtama = box.get('akunUtama', defaultValue: '');
  if ((akunUtama.isEmpty || !masterAkun.contains(akunUtama)) && masterAkun.isNotEmpty) {
    akunUtama = masterAkun.first;
  }

  // Load Limit Pengeluaran
  limitPengeluaran = box.get('limitPengeluaran', defaultValue: 0.0) as double;

  // Load Saldo Awal Map
  final Map<dynamic, dynamic>? savedSaldoAwal = box.get('saldoAwalMap');
  if (savedSaldoAwal != null) {
    saldoAwalMap = Map<String, double>.from(
      savedSaldoAwal.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
    );
  } else {
    saldoAwalMap = {};
  }

  // Load Kategori (jika kosong, buat default)
  final List<dynamic>? savedKategori = box.get('kategori');
  if (savedKategori != null) {
    masterKategori = savedKategori
        .map((k) => kategoriFromMap(k as Map))
        .toList();
  } else {
    masterKategori = [
      KategoriModel(nama: "Makanan", tipe: "Pengeluaran", ikon: Icons.fastfood),
      KategoriModel(
        nama: "Transportasi",
        tipe: "Pengeluaran",
        ikon: Icons.directions_car,
      ),
      KategoriModel(nama: "Gaji", tipe: "Pemasukan", ikon: Icons.payments),
      KategoriModel(nama: "Bonus", tipe: "Pemasukan", ikon: Icons.trending_up),
    ];
  }

  // Pastikan kategori "Piutang" & "Hutang" ada untuk Pemasukan dan Pengeluaran
  final hasPiutangPengeluaran = masterKategori.any(
    (k) => k.nama == "Piutang" && k.tipe == "Pengeluaran",
  );
  if (!hasPiutangPengeluaran) {
    masterKategori.add(
      KategoriModel(nama: "Piutang", tipe: "Pengeluaran", ikon: Icons.payments),
    );
  }
  final hasPiutangPemasukan = masterKategori.any(
    (k) => k.nama == "Piutang" && k.tipe == "Pemasukan",
  );
  if (!hasPiutangPemasukan) {
    masterKategori.add(
      KategoriModel(nama: "Piutang", tipe: "Pemasukan", ikon: Icons.payments),
    );
  }
  final hasHutangPengeluaran = masterKategori.any(
    (k) => k.nama == "Hutang" && k.tipe == "Pengeluaran",
  );
  if (!hasHutangPengeluaran) {
    masterKategori.add(
      KategoriModel(nama: "Hutang", tipe: "Pengeluaran", ikon: Icons.payments),
    );
  }
  final hasHutangPemasukan = masterKategori.any(
    (k) => k.nama == "Hutang" && k.tipe == "Pemasukan",
  );
  if (!hasHutangPemasukan) {
    masterKategori.add(
      KategoriModel(nama: "Hutang", tipe: "Pemasukan", ikon: Icons.payments),
    );
  }
  // Load Transaksi
  final List<dynamic>? savedTransaksi = box.get('transaksi');
  if (savedTransaksi != null) {
    daftarTransaksi = savedTransaksi
        .map((t) => transaksiFromMap(t as Map))
        .toList();
  } else {
    daftarTransaksi = [];
  }

  // Load Kontak Utang
  // Jika data lama (mengandung key 'tipeHubungan'), hapus dan mulai kosong
  final List<dynamic>? savedKontakUtang = box.get('kontakUtang');
  if (savedKontakUtang != null && savedKontakUtang.isNotEmpty) {
    final firstItem = savedKontakUtang.first as Map;
    if (firstItem.containsKey('tipeHubungan')) {
      // Format lama ditemukan - hapus dari Hive
      box.delete('kontakUtang');
      daftarKontakUtang = [];
    } else {
      daftarKontakUtang = savedKontakUtang
          .map((k) => kontakUtangFromMap(k as Map))
          .toList();
    }
  } else {
    daftarKontakUtang = [];
  }

  // Load Asset
  final List<dynamic>? savedAsset = box.get('asset');
  if (savedAsset != null) {
    daftarAsset = savedAsset
        .map((a) => assetFromMap(a as Map))
        .toList();
  } else {
    daftarAsset = [];
  }

  // Simpan data (untuk menyimpan migrasi kategori jika ada perubahan)
  saveData();
}

// Mendapatkan path file backup

Future<File> getBackupFile() async {
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
  }
  dir ??= await getApplicationDocumentsDirectory();
  return File('${dir.path}/dompet_pribadi_backup.json');
}

// Eksport data ke JSON
Future<String?> exportData() async {
  try {
    final Map<String, dynamic> exportMap = {
      'transaksi': daftarTransaksi.map((t) => transaksiToMap(t)).toList(),
      'kategori': masterKategori.map((k) => kategoriToMap(k)).toList(),
      'akun': masterAkun,
      'akunUtama': akunUtama,
      'limitPengeluaran': limitPengeluaran,
      'saldoAwalMap': saldoAwalMap,
      'kontakUtang': daftarKontakUtang.map((k) => kontakUtangToMap(k)).toList(),
      'asset': daftarAsset.map((a) => assetToMap(a)).toList(),
    };

    final jsonString = jsonEncode(exportMap);
    final file = await getBackupFile();
    await file.writeAsString(jsonString);
    return file.path;
  } catch (e) {
    print('Gagal mengekspor data: $e');
    return null;
  }
}

// Import data dari JSON
Future<String> importData() async {
  try {
    final file = await getBackupFile();
    if (!await file.exists()) {
      return "not_found";
    }

    final jsonString = await file.readAsString();
    final Map<String, dynamic> importMap = jsonDecode(jsonString);

    if (importMap.containsKey('transaksi') &&
        importMap.containsKey('kategori') &&
        importMap.containsKey('akun')) {
      final List<dynamic> importedAkun = importMap['akun'];
      final List<dynamic> importedKategori = importMap['kategori'];
      final List<dynamic> importedTransaksi = importMap['transaksi'];

      masterAkun = List<String>.from(importedAkun);
      akunUtama = importMap['akunUtama'] ?? (masterAkun.isNotEmpty ? masterAkun.first : '');
      limitPengeluaran = (importMap['limitPengeluaran'] ?? 0.0) as double;
      final Map<dynamic, dynamic>? importedSaldoAwal = importMap['saldoAwalMap'];
      if (importedSaldoAwal != null) {
        saldoAwalMap = Map<String, double>.from(
          importedSaldoAwal.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        );
      } else {
        saldoAwalMap = {};
      }
      masterKategori = importedKategori
          .map((k) => kategoriFromMap(k as Map))
          .toList();
      daftarTransaksi = importedTransaksi
          .map((t) => transaksiFromMap(t as Map))
          .toList();

      if (importMap.containsKey('kontakUtang')) {
        final List<dynamic> importedKontakUtang = importMap['kontakUtang'];
        daftarKontakUtang = importedKontakUtang
            .map((k) => kontakUtangFromMap(k as Map))
            .toList();
      } else {
        daftarKontakUtang = [];
      }

      if (importMap.containsKey('asset')) {
        final List<dynamic> importedAsset = importMap['asset'];
        daftarAsset = importedAsset
            .map((a) => assetFromMap(a as Map))
            .toList();
      } else {
        daftarAsset = [];
      }

      saveData();
      return "success";
    }
    return "error";
  } catch (e) {
    print('Gagal mengimpor data: $e');
    return "error";
  }
}

// ================= FORMAT HELPER =================

String formatRibuan(double value) {
  bool isNegative = value < 0;
  double absValue = value.abs();

  // Split into integer and decimal parts
  String valueString = absValue.toString();
  List<String> parts = valueString.split('.');
  String integerPart = parts[0];
  String decimalPart = parts.length > 1 ? parts[1] : '';

  // Format integer part with dot as thousands separator
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String formattedInteger = integerPart.replaceAllMapped(
    reg,
    (Match match) => '${match[1]}.',
  );

  String result;
  if (decimalPart == '0' || decimalPart.isEmpty) {
    result = formattedInteger;
  } else {
    result = '$formattedInteger,$decimalPart';
  }

  return isNegative ? '-$result' : result;
}

class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Ambil jumlah angka sebelum kursor pada input baru
    int cursorPosition = newValue.selection.end;
    String textBeforeCursor = newValue.text.substring(0, cursorPosition);
    int digitsBeforeCursor = textBeforeCursor
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    // Bersihkan semua non-digit
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    double value = double.parse(cleanText);
    String formatted = formatRibuan(value);

    // Cari posisi kursor baru berdasarkan jumlah digit yang ada sebelum kursor
    int newCursorPosition = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }
      newCursorPosition = i + 1;
      if (digitCount == digitsBeforeCursor) {
        break;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

void syncTransaksiUtangToMainList(KontakUtang kontak, TransaksiUtang tx) {
  // Tentukan tipe & kategori untuk transaksi utama
  String mainTipe = tx.tipe == "Piutang" ? "Pengeluaran" : "Pemasukan";
  String mainKategori = tx.tipe == "Piutang" ? "Piutang" : "Hutang";
  String mainCatatan =
      "${kontak.nama}: ${tx.catatan.isNotEmpty ? tx.catatan : tx.tipe}";

  // Cari apakah transaksi dengan ID ini sudah ada di daftarTransaksi
  final existingIndex = daftarTransaksi.indexWhere((t) => t.id == tx.id);
  if (existingIndex >= 0) {
    // Update existing
    daftarTransaksi[existingIndex] = Transaksi(
      id: tx.id,
      nominal: tx.nominal,
      catatan: mainCatatan,
      tipe: mainTipe,
      kategori: mainKategori,
      akun: tx.akun,
      tanggal: tx.tanggal,
    );
  } else {
    // Add new
    daftarTransaksi.add(
      Transaksi(
        id: tx.id,
        nominal: tx.nominal,
        catatan: mainCatatan,
        tipe: mainTipe,
        kategori: mainKategori,
        akun: tx.akun,
        tanggal: tx.tanggal,
      ),
    );
  }
}

void removeTransaksiUtangFromMainList(String txId) {
  daftarTransaksi.removeWhere((t) => t.id == txId);
}

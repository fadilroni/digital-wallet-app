import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'data_model.dart';

class BankAppInfo {
  final String id;
  final String name;
  final List<String> packageNames;
  final List<String> keywords;

  const BankAppInfo({
    required this.id,
    required this.name,
    required this.packageNames,
    required this.keywords,
  });
}

class BankNotifService {
  static final BankNotifService instance = BankNotifService._internal();
  BankNotifService._internal();

  StreamSubscription? _subscription;
  bool _isListening = false;
  bool get isListening => _isListening;

  // Daftar Bank Bawaan Populer di Indonesia
  static const List<BankAppInfo> knownBanks = [
    BankAppInfo(
      id: 'bca',
      name: 'BCA (myBCA / BCA mobile)',
      packageNames: ['com.bca', 'mybca.bca.co.id', 'com.bca.klikbca'],
      keywords: ['bca', 'mybca', 'klikbca'],
    ),
    BankAppInfo(
      id: 'mandiri',
      name: 'Bank Mandiri (Livin\' by Mandiri)',
      packageNames: ['id.bmri.livin', 'id.co.bankmandiri.mandirionline'],
      keywords: ['livin', 'mandiri'],
    ),
    BankAppInfo(
      id: 'bri',
      name: 'BRI (BRImo)',
      packageNames: ['id.co.bri.brimo'],
      keywords: ['bri', 'brimo'],
    ),
    BankAppInfo(
      id: 'bni',
      name: 'BNI (wondr by BNI / BNI Mobile)',
      packageNames: ['id.bni.wondr', 'src.com.bni'],
      keywords: ['wondr', 'bni'],
    ),
    BankAppInfo(
      id: 'krom',
      name: 'Krom Bank (Krom)',
      packageNames: ['id.co.krom.bank', 'id.krom.bank'],
      keywords: ['krom', 'krom bank'],
    ),
    BankAppInfo(
      id: 'jago',
      name: 'Bank Jago',
      packageNames: ['com.jago.app'],
      keywords: ['jago', 'bank jago'],
    ),
    BankAppInfo(
      id: 'seabank',
      name: 'SeaBank Indonesia',
      packageNames: ['com.seabank.id'],
      keywords: ['seabank', 'sea bank'],
    ),
    BankAppInfo(
      id: 'blu',
      name: 'blu by BCA Digital',
      packageNames: ['id.co.bcadigital.blu'],
      keywords: ['blu', 'bca digital'],
    ),
    BankAppInfo(
      id: 'neobank',
      name: 'Neobank (Bank Neo Commerce)',
      packageNames: ['com.bnc.passbook'],
      keywords: ['neobank', 'bank neo'],
    ),
    BankAppInfo(
      id: 'bsi',
      name: 'BSI Mobile',
      packageNames: ['com.bsi.mobile'],
      keywords: ['bsi', 'bsi mobile'],
    ),
    BankAppInfo(
      id: 'jenius',
      name: 'Jenius (BTPN)',
      packageNames: ['com.btpn.dc'],
      keywords: ['jenius'],
    ),
    BankAppInfo(
      id: 'cimb',
      name: 'CIMB Niaga (OCTO Mobile)',
      packageNames: ['cimb.niaga.mobile.android'],
      keywords: ['octo', 'cimb'],
    ),
    BankAppInfo(
      id: 'allo',
      name: 'Allo Bank',
      packageNames: ['com.allobank.allomobile'],
      keywords: ['allo', 'allobank'],
    ),
    BankAppInfo(
      id: 'gopay',
      name: 'GoPay / Gojek',
      packageNames: ['com.gojek.app', 'com.gopay.wallet'],
      keywords: ['gopay', 'gojek'],
    ),
    BankAppInfo(
      id: 'dana',
      name: 'DANA Indonesia',
      packageNames: ['id.dana'],
      keywords: ['dana'],
    ),
    BankAppInfo(
      id: 'ovo',
      name: 'OVO',
      packageNames: ['ovo.id'],
      keywords: ['ovo'],
    ),
    BankAppInfo(
      id: 'shopeepay',
      name: 'ShopeePay / Shopee',
      packageNames: ['com.shopee.id', 'com.shopeepay.id'],
      keywords: ['shopeepay', 'shopee'],
    ),
    BankAppInfo(
      id: 'linkaja',
      name: 'LinkAja',
      packageNames: ['com.telkom.tcash'],
      keywords: ['linkaja'],
    ),
  ];

  /// Cek apakah izin Akses Notifikasi sudah diberikan oleh pengguna
  Future<bool> isPermissionGranted() async {
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Meminta izin Akses Notifikasi ke sistem Android
  Future<bool> requestPermission() async {
    try {
      return await NotificationListenerService.requestPermission();
    } catch (_) {
      return false;
    }
  }

  /// Mulai mendengarkan stream notifikasi jika fitur diaktifkan
  void startListening() {
    if (_isListening) return;
    if (!notifBankAutoRecordEnabled) return;

    try {
      _subscription = NotificationListenerService.notificationsStream.listen(
        (event) {
          _handleIncomingNotification(event);
        },
        onError: (err) {
          debugPrint("Bank notif listener error: $err");
        },
      );
      _isListening = true;
      debugPrint("Bank notif listener dimulai.");
    } catch (e) {
      debugPrint("Gagal memulai bank notif listener: $e");
    }
  }

  /// Berhenti mendengarkan notifikasi
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    debugPrint("Bank notif listener dihentikan.");
  }

  /// Memproses notifikasi yang masuk
  void _handleIncomingNotification(ServiceNotificationEvent event) {
    if (!notifBankAutoRecordEnabled) return;

    final String packageName = event.packageName ?? '';
    final String title = (event.title ?? '').trim();
    final String content = (event.content ?? '').trim();
    final String fullText = "$title $content".trim();

    if (fullText.isEmpty) return;

    // 1. Cari Akun Dompet Digital mana yang cocok dengan notifikasi ini
    final String? targetAccount = _findTargetAccount(packageName, fullText);
    if (targetAccount == null) {
      // Notifikasi bukan dari bank yang terhubung
      return;
    }

    // 2. Ekstraksi nominal uang dari teks
    final double? nominal = extractNominal(fullText);
    if (nominal == null || nominal <= 0) {
      return;
    }

    // 3. Tentukan jenis transaksi (Pengeluaran vs Pemasukan)
    final String tipe = detectTransactionType(fullText);

    // 4. Tentukan kategori secara cerdas
    final String kategori = inferCategory(fullText, tipe);

    // 5. Teks lengkap notifikasi disimpan utuh ke dalam keterangan transaksi
    final String catatan = fullText;

    // 6. Eksekusi berdasarkan mode (Opsi A: Konfirmasi vs Opsi B: Otomatis Langsung)
    if (notifBankMode == 'auto') {
      _executeAutoRecord(
        nominal: nominal,
        tipe: tipe,
        kategori: kategori,
        akun: targetAccount,
        catatan: catatan,
      );
    } else {
      _showConfirmationAlert(
        nominal: nominal,
        tipe: tipe,
        kategori: kategori,
        akun: targetAccount,
        catatan: catatan,
      );
    }
  }

  /// Mencari akun yang ditautkan ke package / keyword bank
  String? _findTargetAccount(String packageName, String fullText) {
    final lowerPkg = packageName.toLowerCase();
    final lowerText = fullText.toLowerCase();

    // Cek dari bankAccountMapping (namaAkun -> bankId / package)
    for (var entry in bankAccountMapping.entries) {
      final namaAkun = entry.key;
      final bankKey = entry.value.toLowerCase();

      // Cocokkan langsung dengan package
      if (lowerPkg.contains(bankKey) || bankKey.contains(lowerPkg)) {
        return namaAkun;
      }

      // Cocokkan dengan daftar knownBanks
      final matchedBank = knownBanks.firstWhere(
        (b) => b.id == bankKey || b.name.toLowerCase().contains(bankKey),
        orElse: () => const BankAppInfo(id: '', name: '', packageNames: [], keywords: []),
      );

      if (matchedBank.id.isNotEmpty) {
        // Cek package
        for (var pkg in matchedBank.packageNames) {
          if (lowerPkg.contains(pkg)) return namaAkun;
        }
        // Cek keywords di teks notifikasi
        for (var kw in matchedBank.keywords) {
          if (lowerText.contains(kw)) return namaAkun;
        }
      }

      // Jika bankKey adalah kata kunci kustom
      if (lowerText.contains(bankKey)) {
        return namaAkun;
      }
    }

    return null;
  }

  /// Ekstraksi nominal rupiah dari teks (misal: "Rp 50.000", "Rp. 1.500.000", "50.000,00", "IDR 25000")
  static double? extractNominal(String text) {
    // Pola regex nominal rupiah
    final regExp = RegExp(
      r'(?:rp\.?|idr|sebesar)?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{2})?|[0-9]{4,12})',
      caseSensitive: false,
    );

    final matches = regExp.allMatches(text);
    for (var match in matches) {
      String raw = match.group(1) ?? '';
      if (raw.isEmpty) continue;

      // Bersihkan tanda titik dan koma desimal
      // Format Indonesia biasanya ribuan pakai titik: 50.000 atau 1.500.000
      if (raw.contains('.') && raw.contains(',')) {
        // Misal 50.000,00 -> buang koma dan angka di belakangnya
        raw = raw.split(',')[0].replaceAll('.', '');
      } else if (raw.contains('.')) {
        raw = raw.replaceAll('.', '');
      } else if (raw.contains(',')) {
        raw = raw.replaceAll(',', '');
      }

      final parsed = double.tryParse(raw);
      if (parsed != null && parsed >= 100) {
        return parsed;
      }
    }
    return null;
  }

  /// Deteksi tipe transaksi (Pengeluaran vs Pemasukan)
  static String detectTransactionType(String text) {
    final lower = text.toLowerCase();

    // Kata kunci pemasukan (kredit)
    final masukKeywords = [
      'transfer masuk',
      'dana masuk',
      'terima uang',
      'diterima',
      'uang masuk',
      'kredit',
      'top up berhasil',
      'cashback',
      'gaji',
      'payroll',
      'setoran',
      'bunga deposito',
    ];

    for (var kw in masukKeywords) {
      if (lower.contains(kw)) {
        return 'Pemasukan';
      }
    }

    // Default transaksi notifikasi umumnya adalah Pengeluaran (debit/qris/transfer keluar)
    return 'Pengeluaran';
  }

  /// Menentukan kategori secara cerdas dari kata kunci teks
  static String inferCategory(String text, String tipe) {
    final lower = text.toLowerCase();

    if (tipe == 'Pemasukan') {
      if (lower.contains('gaji') || lower.contains('payroll')) return 'Gaji';
      if (lower.contains('bunga') || lower.contains('dividen') || lower.contains('investasi')) return 'Investasi';
      return 'Pemasukan Lain';
    }

    // Cek Makanan & Minuman
    final foodKeywords = [
      'indomaret', 'alfamart', 'kopi', 'coffee', 'cafe', 'resto', 'restoran',
      'bakso', 'mie', 'gofood', 'grabfood', 'shopeefood', 'mcd', 'kfc',
      'hokben', 'chatime', 'starbucks', 'kenangan', 'warung', 'martabak'
    ];
    for (var kw in foodKeywords) {
      if (lower.contains(kw)) return 'Makanan & Minuman';
    }

    // Cek Transportasi
    final transportKeywords = [
      'spbu', 'pertamina', 'shell', 'bensin', 'gojek', 'grab', 'goride',
      'gocar', 'grabbike', 'grabcar', 'tol', 'parkir', 'kai', 'mrt', 'krl', 'tiket'
    ];
    for (var kw in transportKeywords) {
      if (lower.contains(kw)) return 'Transportasi';
    }

    // Cek Tagihan & Utilitas
    final billKeywords = [
      'pln', 'listrik', 'pdam', 'bpjs', 'indihome', 'wifi', 'telkomsel',
      'indosat', 'xl', 'tri', 'smartfren', 'pulsa', 'paket data'
    ];
    for (var kw in billKeywords) {
      if (lower.contains(kw)) return 'Tagihan & Utilitas';
    }

    // Cek Belanja Online
    final shopKeywords = [
      'shopee', 'tokopedia', 'lazada', 'blibli', 'tiktok shop', 'zalora'
    ];
    for (var kw in shopKeywords) {
      if (lower.contains(kw)) return 'Belanja';
    }

    // Fallback ke kategori default pilihan pengguna
    return notifBankDefaultKategori;
  }

  /// Eksekusi pencatatan otomatis langsung (Opsi B)
  void _executeAutoRecord({
    required double nominal,
    required String tipe,
    required String kategori,
    required String akun,
    required String catatan,
  }) {
    final newTx = Transaksi(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nominal: nominal,
      catatan: catatan,
      tipe: tipe,
      kategori: kategori,
      akun: akun,
      tanggal: DateTime.now(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    daftarTransaksi.add(newTx);
    saveData();

    // Tampilkan notifikasi hening bahwa transaksi telah tercatat
    _notifyLocalRecorded(
      title: "⚡ Transaksi Tercatat Otomatis",
      body: "$tipe Rp ${nominal.toStringAsFixed(0)} ($akun)\n$kategori • $catatan",
    );
  }

  /// Tampilkan notifikasi konfirmasi 1-klik (Opsi A)
  void _showConfirmationAlert({
    required double nominal,
    required String tipe,
    required String kategori,
    required String akun,
    required String catatan,
  }) {
    _notifyLocalRecorded(
      title: "🔔 Deteksi Transaksi: $tipe Rp ${nominal.toStringAsFixed(0)}",
      body: "Akun: $akun • Ketuk untuk simpan ke buku kas\n$catatan",
    );
  }

  /// Menampilkan status notifikasi lokal ke HP pengguna
  Future<void> _notifyLocalRecorded({
    required String title,
    required String body,
  }) async {
    try {
      final fln = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'bank_record_channel',
        'Pencatatan Transaksi Bank',
        channelDescription: 'Notifikasi status pencatatan otomatis dari transaksi perbankan',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notifDetails = NotificationDetails(android: androidDetails);
      await fln.show(
        DateTime.now().millisecond,
        title,
        body,
        notifDetails,
      );
    } catch (e) {
      debugPrint("Gagal memunculkan notifikasi status: $e");
    }
  }
}


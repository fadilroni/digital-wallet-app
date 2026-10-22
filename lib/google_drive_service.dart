import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'data_model.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveSyncService {
  static final GoogleDriveSyncService instance = GoogleDriveSyncService._internal();
  GoogleDriveSyncService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Inisialisasi listener login
  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
    });
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Error silent sign in: $e');
    }
  }

  // Login Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Error sign in Google: $e');
      rethrow;
    }
  }

  // Logout Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error sign out: $e');
    }
  }

  // Mendapatkan instance DriveApi
  Future<drive.DriveApi?> _getDriveApi() async {
    _currentUser ??= await _googleSignIn.signInSilently();
    if (_currentUser == null) return null;

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  // Helper membaca file backup di Google Drive (jika ada)
  Future<Map<String, dynamic>?> _fetchDriveBackupData(drive.DriveApi driveApi) async {
    try {
      const fileName = 'dompet_pribadi_backup.json';
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName' and trashed = false",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return null;
      }

      final fileId = fileList.files!.first.id!;
      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await media.stream.forEach((chunk) {
        dataBytes.addAll(chunk);
      });

      final jsonString = utf8.decode(dataBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching drive backup data: $e');
      return null;
    }
  }

  // Menggabungkan data Cloud dan Lokal (Smart Merge)
  void _smartMergeData(Map<String, dynamic> remoteData) {
    // 1. Sinkronisasi ID Transaksi & Pengingat yang telah dihapus
    final remoteDeletedIds = (remoteData['deletedTransactionIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    for (var id in remoteDeletedIds) {
      recordDeletedTransactionId(id);
    }

    final remoteDeletedReminderIds = (remoteData['deletedReminderIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    for (var id in remoteDeletedReminderIds) {
      recordDeletedReminderId(id);
    }

    // 2. Transaksi Smart Merge (Union by ID, update if newer, sort by date descending)
    final Map<String, Transaksi> transactionMap = {};

    // Masukkan data remote terlebih dahulu
    if (remoteData.containsKey('transaksi') && remoteData['transaksi'] is List) {
      for (var item in (remoteData['transaksi'] as List)) {
        final tx = transaksiFromMap(Map<String, dynamic>.from(item));
        if (!deletedTransactionIds.contains(tx.id)) {
          transactionMap[tx.id] = tx;
        }
      }
    }

    // Gabungkan dengan data lokal saat ini
    for (var localTx in daftarTransaksi) {
      if (deletedTransactionIds.contains(localTx.id)) {
        transactionMap.remove(localTx.id);
        continue;
      }
      if (!transactionMap.containsKey(localTx.id)) {
        transactionMap[localTx.id] = localTx;
      } else {
        // Jika ada di kedua sisi, pilih yang waktu update-nya lebih baru
        final remoteTx = transactionMap[localTx.id]!;
        final localUpdated = localTx.updatedAt ?? localTx.tanggal.millisecondsSinceEpoch;
        final remoteUpdated = remoteTx.updatedAt ?? remoteTx.tanggal.millisecondsSinceEpoch;
        if (localUpdated >= remoteUpdated) {
          transactionMap[localTx.id] = localTx;
        }
      }
    }

    // Urutkan transaksi secara otomatis dari tanggal terbaru ke terlama
    final List<Transaksi> mergedTxList = transactionMap.values.toList();
    mergedTxList.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    daftarTransaksi = mergedTxList;

    // 3. Kategori Smart Merge (Gabungkan kategori unik)
    if (remoteData.containsKey('kategori') && remoteData['kategori'] is List) {
      final remoteKategoriList = (remoteData['kategori'] as List)
          .map((item) => kategoriFromMap(Map<String, dynamic>.from(item)))
          .toList();

      for (var rk in remoteKategoriList) {
        final exists = masterKategori.any((lk) =>
            lk.nama.trim().toLowerCase() == rk.nama.trim().toLowerCase() &&
            lk.tipe == rk.tipe);
        if (!exists) {
          masterKategori.add(rk);
        }
      }
    }

    // 4. Akun Smart Merge
    if (remoteData.containsKey('akun') && remoteData['akun'] is List) {
      final remoteAkun = List<String>.from(remoteData['akun']);
      for (var ak in remoteAkun) {
        if (!masterAkun.contains(ak)) {
          masterAkun.add(ak);
        }
      }
    }

    // 5. Saldo Awal Smart Merge
    if (remoteData.containsKey('saldoAwalMap') && remoteData['saldoAwalMap'] is Map) {
      final remoteSaldoAwal = Map<String, double>.from(
        (remoteData['saldoAwalMap'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
      for (var entry in remoteSaldoAwal.entries) {
        if (!saldoAwalMap.containsKey(entry.key) || saldoAwalMap[entry.key] == 0) {
          saldoAwalMap[entry.key] = entry.value;
        }
      }
    }

    // 6. Kontak Utang Smart Merge
    if (remoteData.containsKey('kontakUtang') && remoteData['kontakUtang'] is List) {
      final remoteKontakList = (remoteData['kontakUtang'] as List)
          .map((item) => kontakUtangFromMap(Map<String, dynamic>.from(item)))
          .toList();

      final Map<String, KontakUtang> kontakMap = {
        for (var k in daftarKontakUtang) k.id: k
      };

      for (var rk in remoteKontakList) {
        if (!kontakMap.containsKey(rk.id)) {
          kontakMap[rk.id] = rk;
        } else {
          final existing = kontakMap[rk.id]!;
          final Map<String, TransaksiUtang> txUtangMap = {
            for (var t in existing.transaksi) t.id: t
          };
          for (var rt in rk.transaksi) {
            txUtangMap[rt.id] = rt;
          }
          final mergedUtangTx = txUtangMap.values.toList();
          mergedUtangTx.sort((a, b) => b.tanggal.compareTo(a.tanggal));
          kontakMap[rk.id] = KontakUtang(
            id: existing.id,
            nama: existing.nama.isNotEmpty ? existing.nama : rk.nama,
            telepon: existing.telepon.isNotEmpty ? existing.telepon : rk.telepon,
            tanggalDibuat: existing.tanggalDibuat,
            transaksi: mergedUtangTx,
          );
        }
      }
      daftarKontakUtang = kontakMap.values.toList();
    }

    // 7. Asset Smart Merge
    if (remoteData.containsKey('asset') && remoteData['asset'] is List) {
      final remoteAssetList = (remoteData['asset'] as List)
          .map((item) => assetFromMap(Map<String, dynamic>.from(item)))
          .toList();

      final Map<String, Asset> assetMap = {
        for (var a in daftarAsset) a.id: a
      };
      for (var ra in remoteAssetList) {
        if (!assetMap.containsKey(ra.id)) {
          assetMap[ra.id] = ra;
        }
      }
      daftarAsset = assetMap.values.toList();
    }

    // 8. Recurring Reminders Smart Merge (Hapus yang ditandai terhapus, gabungkan yang baru)
    if (remoteData.containsKey('recurringReminders') && remoteData['recurringReminders'] is List) {
      final remoteReminderList = (remoteData['recurringReminders'] as List)
          .map((item) => recurringReminderFromMap(Map<String, dynamic>.from(item)))
          .toList();

      final Map<String, RecurringReminder> reminderMap = {};
      for (var rr in remoteReminderList) {
        if (!deletedReminderIds.contains(rr.id)) {
          reminderMap[rr.id] = rr;
        }
      }
      for (var lr in daftarPengingatRutin) {
        if (deletedReminderIds.contains(lr.id)) {
          reminderMap.remove(lr.id);
        } else {
          reminderMap[lr.id] = lr;
        }
      }
      daftarPengingatRutin = reminderMap.values.toList();
    } else {
      daftarPengingatRutin.removeWhere((r) => deletedReminderIds.contains(r.id));
    }

    // 9. Limit Pengeluaran Smart Merge
    if (remoteData.containsKey('limitPengeluaran')) {
      final remoteLimit = (remoteData['limitPengeluaran'] as num?)?.toDouble() ?? 0.0;
      if (remoteLimit > 0 || limitPengeluaran == 0) {
        limitPengeluaran = remoteLimit;
      }
    }

    // 10. Akun Utama Smart Merge
    if (remoteData.containsKey('akunUtama') && remoteData['akunUtama'] is String) {
      final remoteAkunUtama = remoteData['akunUtama'] as String;
      if (remoteAkunUtama.isNotEmpty && masterAkun.contains(remoteAkunUtama)) {
        akunUtama = remoteAkunUtama;
      }
    }

    // Simpan hasil gabungan ke database lokal Hive
    saveData(triggerCloudSync: false);
  }

  // Mengunggah / Backup Data ke Google Drive (dengan Smart Merge sebelumnya)
  Future<bool> uploadDataToDrive() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        _isSyncing = false;
        return false;
      }

      // Ambil file Drive yang ada dulu untuk di-merge agar tidak menimpa data device lain
      final remoteData = await _fetchDriveBackupData(driveApi);
      if (remoteData != null) {
        _smartMergeData(remoteData);
      }

      // Format JSON backup lengkap
      final Map<String, dynamic> backupData = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'transaksi': daftarTransaksi.map((t) => transaksiToMap(t)).toList(),
        'kategori': masterKategori.map((k) => kategoriToMap(k)).toList(),
        'akun': masterAkun,
        'akunUtama': akunUtama,
        'limitPengeluaran': limitPengeluaran,
        'saldoAwalMap': saldoAwalMap,
        'kontakUtang': daftarKontakUtang.map((k) => kontakUtangToMap(k)).toList(),
        'asset': daftarAsset.map((a) => assetToMap(a)).toList(),
        'isHideSaldo': isHideSaldoGlobal,
        'recurringReminders': daftarPengingatRutin.map((r) => recurringReminderToMap(r)).toList(),
        'deletedTransactionIds': deletedTransactionIds,
        'deletedReminderIds': deletedReminderIds,
      };

      final jsonString = jsonEncode(backupData);
      final List<int> mediaBytes = utf8.encode(jsonString);
      final mediaStream = Stream.value(mediaBytes);
      final media = drive.Media(mediaStream, mediaBytes.length);

      const fileName = 'dompet_pribadi_backup.json';

      // Cari file di folder appData
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName' and trashed = false",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
        );
        debugPrint('Google Drive Smart Merge: File updated successfully.');
      } else {
        final driveFile = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder'];

        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint('Google Drive Smart Merge: File created successfully.');
      }

      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint('Error uploading data to Google Drive: $e');
      _isSyncing = false;
      return false;
    }
  }

  // Mengunduh / Sync Data dari Google Drive (Smart Merge dua arah)
  Future<bool> downloadDataFromDrive() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        _isSyncing = false;
        return false;
      }

      final remoteData = await _fetchDriveBackupData(driveApi);
      if (remoteData == null) {
        debugPrint('Google Drive Sync: Tidak ada file backup ditemukan di Drive.');
        _isSyncing = false;
        return false;
      }

      // Lakukan smart merge antara data remote dan lokal
      _smartMergeData(remoteData);

      // Perbarui juga data di Google Drive dengan hasil gabungan
      final Map<String, dynamic> mergedBackupData = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'transaksi': daftarTransaksi.map((t) => transaksiToMap(t)).toList(),
        'kategori': masterKategori.map((k) => kategoriToMap(k)).toList(),
        'akun': masterAkun,
        'akunUtama': akunUtama,
        'limitPengeluaran': limitPengeluaran,
        'saldoAwalMap': saldoAwalMap,
        'kontakUtang': daftarKontakUtang.map((k) => kontakUtangToMap(k)).toList(),
        'asset': daftarAsset.map((a) => assetToMap(a)).toList(),
        'isHideSaldo': isHideSaldoGlobal,
        'recurringReminders': daftarPengingatRutin.map((r) => recurringReminderToMap(r)).toList(),
        'deletedTransactionIds': deletedTransactionIds,
        'deletedReminderIds': deletedReminderIds,
      };

      final jsonString = jsonEncode(mergedBackupData);
      final List<int> mediaBytes = utf8.encode(jsonString);
      final mediaStream = Stream.value(mediaBytes);
      final media = drive.Media(mediaStream, mediaBytes.length);

      const fileName = 'dompet_pribadi_backup.json';
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName' and trashed = false",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
        );
      }

      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint('Error downloading data from Google Drive: $e');
      _isSyncing = false;
      return false;
    }
  }
}


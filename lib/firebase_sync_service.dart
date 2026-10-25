import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'data_model.dart';
import 'notification_service.dart';

class FirebaseSyncService {
  static final FirebaseSyncService instance = FirebaseSyncService._internal();
  FirebaseSyncService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  StreamSubscription? _metaSub;
  StreamSubscription? _txSub;
  StreamSubscription? _contactSub;
  StreamSubscription? _assetSub;
  StreamSubscription? _reminderSub;

  // Inisialisasi Firebase secara aman saat aplikasi dijalankan
  static Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      debugPrint("Firebase berhasil diinisialisasi.");
    } catch (e) {
      debugPrint("Firebase init warning (mungkin offline/belum terhubung): $e");
    }
  }

  // Mulai listener realtime jika pengguna sudah login
  Future<void> init() async {
    if (isSignedIn) {
      pullFromFirebase();
      startRealtimeListener();
    }
  }

  // Masuk menggunakan Akun Google via Firebase Auth
  Future<User?> signInWithGoogle() async {
    try {
      _isSyncing = true;
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isSyncing = false;
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception(
          "Token otentikasi Google tidak ditemukan. Pastikan file google-services.json terbaru sudah terpasang.",
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      _isSyncing = false;

      // Tarik seluruh data dari cloud ke lokal agar device baru langsung lengkap
      await pullFromFirebase();

      // Mulai dengarkan pembaruan realtime dari cloud
      startRealtimeListener();

      return userCredential.user;
    } catch (e) {
      debugPrint("Error saat sign in Google Firebase: $e");
      _isSyncing = false;
      rethrow;
    }
  }

  // Keluar dari Firebase Auth
  Future<void> signOut() async {
    try {
      stopRealtimeListener();
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("Error saat sign out: $e");
    }
  }

  // Referensi Koleksi Pengguna di Firestore
  DocumentReference _userDoc(String uid) => _firestore.collection('users').doc(uid);
  CollectionReference _txCol(String uid) => _userDoc(uid).collection('transaksi');
  CollectionReference _contactCol(String uid) => _userDoc(uid).collection('kontak_utang');
  CollectionReference _assetCol(String uid) => _userDoc(uid).collection('asset');
  CollectionReference _reminderCol(String uid) => _userDoc(uid).collection('reminders');

  // Cek apakah di Firebase sudah ada data sebelumnya
  Future<bool> hasExistingCloudData() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await _userDoc(user.uid).get();
      if (doc.exists) return true;

      final txSnap = await _txCol(user.uid).limit(1).get();
      return txSnap.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error cek data cloud: $e");
      return false;
    }
  }

  // ── 1. MIGRASI DATA LOKAL KE FIREBASE (ONE-CLICK) ────────────────────────
  Future<bool> migrateLocalDataToFirebase() async {
    final user = currentUser;
    if (user == null) return false;

    _isSyncing = true;
    try {
      final uid = user.uid;

      // A. Unggah Metadata (Akun, Kategori, Saldo Awal, Limit)
      await _userDoc(uid).set({
        'version': 2,
        'updatedAt': FieldValue.serverTimestamp(),
        'akun': masterAkun,
        'akunUtama': akunUtama,
        'limitPengeluaran': limitPengeluaran,
        'saldoAwalMap': saldoAwalMap,
        'isHideSaldo': isHideSaldoGlobal,
        'kategori': masterKategori.map((k) => kategoriToMap(k)).toList(),
        'deletedTransactionIds': deletedTransactionIds,
        'deletedReminderIds': deletedReminderIds,
        'deletedContactIds': deletedContactIds,
        'deletedUtangTxIds': deletedUtangTxIds,
        'deletedAssetIds': deletedAssetIds,
        'bankAccountMapping': bankAccountMapping,
        'notifBankAutoRecordEnabled': notifBankAutoRecordEnabled,
        'notifBankMode': notifBankMode,
        'notifBankDefaultKategori': notifBankDefaultKategori,
      }, SetOptions(merge: true));

      // B. Unggah Transaksi dengan WriteBatch (maks 450 per batch)
      await _batchWriteCollection(
        _txCol(uid),
        daftarTransaksi,
        (t) => t.id,
        (t) => transaksiToMap(t),
      );

      // C. Unggah Kontak Utang
      await _batchWriteCollection(
        _contactCol(uid),
        daftarKontakUtang,
        (k) => k.id,
        (k) => kontakUtangToMap(k),
      );

      // D. Unggah Aset
      await _batchWriteCollection(
        _assetCol(uid),
        daftarAsset,
        (a) => a.id,
        (a) => assetToMap(a),
      );

      // E. Unggah Pengingat Rutin
      await _batchWriteCollection(
        _reminderCol(uid),
        daftarPengingatRutin,
        (r) => r.id,
        (r) => recurringReminderToMap(r),
      );

      _isSyncing = false;
      startRealtimeListener();
      return true;
    } catch (e) {
      debugPrint("Error saat migrasi data ke Firebase: $e");
      _isSyncing = false;
      return false;
    }
  }

  // Helper WriteBatch untuk banyak dokumen
  Future<void> _batchWriteCollection<T>(
    CollectionReference colRef,
    List<T> items,
    String Function(T) getId,
    Map<String, dynamic> Function(T) toMap,
  ) async {
    const int batchLimit = 400;
    for (int i = 0; i < items.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < items.length) ? i + batchLimit : items.length;
      final chunk = items.sublist(i, end);

      for (var item in chunk) {
        final docRef = colRef.doc(getId(item));
        batch.set(docRef, toMap(item), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  // ── 2. SINKRONISASI DARI LOKAL KE CLOUD SAAT ADA PERUBAHAN ─────────────────
  /// Mengunggah 1 transaksi secara instan ke Firestore saat ditambah/diedit
  Future<void> syncSingleTransaction(Transaksi t) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _txCol(user.uid).doc(t.id).set(transaksiToMap(t), SetOptions(merge: true));
      debugPrint("Firebase syncSingleTransaction berhasil: ${t.id}");
    } catch (e) {
      debugPrint("Gagal syncSingleTransaction ke Firebase: $e");
    }
  }

  /// Menghapus 1 transaksi langsung dari Firestore saat dihapus
  Future<void> deleteSingleTransaction(String id) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await _txCol(user.uid).doc(id).delete();
      debugPrint("Firebase deleteSingleTransaction berhasil: $id");
    } catch (e) {
      debugPrint("Gagal deleteSingleTransaction dari Firebase: $e");
    }
  }

  Future<void> syncLocalToCloud() async {
    final user = currentUser;
    if (user == null || _isSyncing) return;

    try {
      final uid = user.uid;

      // Update metadata
      await _userDoc(uid).set({
        'updatedAt': FieldValue.serverTimestamp(),
        'akun': masterAkun,
        'akunUtama': akunUtama,
        'limitPengeluaran': limitPengeluaran,
        'saldoAwalMap': saldoAwalMap,
        'isHideSaldo': isHideSaldoGlobal,
        'kategori': masterKategori.map((k) => kategoriToMap(k)).toList(),
        'deletedTransactionIds': deletedTransactionIds,
        'deletedReminderIds': deletedReminderIds,
        'deletedContactIds': deletedContactIds,
        'deletedUtangTxIds': deletedUtangTxIds,
        'deletedAssetIds': deletedAssetIds,
        'bankAccountMapping': bankAccountMapping,
        'notifBankAutoRecordEnabled': notifBankAutoRecordEnabled,
        'notifBankMode': notifBankMode,
        'notifBankDefaultKategori': notifBankDefaultKategori,
      }, SetOptions(merge: true));

      // Hapus dokumen yang ditandai terhapus di Firestore
      for (var id in deletedTransactionIds) {
        _txCol(uid).doc(id).delete().catchError((_) {});
      }
      for (var id in deletedContactIds) {
        _contactCol(uid).doc(id).delete().catchError((_) {});
      }
      for (var id in deletedAssetIds) {
        _assetCol(uid).doc(id).delete().catchError((_) {});
      }
      for (var id in deletedReminderIds) {
        _reminderCol(uid).doc(id).delete().catchError((_) {});
      }

      // Unggah item lokal aktif
      await _batchWriteCollection(
        _txCol(uid),
        daftarTransaksi,
        (t) => t.id,
        (t) => transaksiToMap(t),
      );
      await _batchWriteCollection(
        _contactCol(uid),
        daftarKontakUtang,
        (k) => k.id,
        (k) => kontakUtangToMap(k),
      );
      await _batchWriteCollection(
        _assetCol(uid),
        daftarAsset,
        (a) => a.id,
        (a) => assetToMap(a),
      );
      await _batchWriteCollection(
        _reminderCol(uid),
        daftarPengingatRutin,
        (r) => r.id,
        (r) => recurringReminderToMap(r),
      );
    } catch (e) {
      debugPrint("Gagal sinkron lokal ke Firebase: $e");
    }
  }

  // Helper untuk menerapkan metadata Firestore ke data lokal (Smart Merge)
  bool _applyMetadataFromMap(Map<String, dynamic> data) {
    bool hasChanges = false;

    // 1. Sinkron ID terhapus
    final remoteDeletedTx = List<String>.from(data['deletedTransactionIds'] ?? []);
    for (var id in remoteDeletedTx) {
      if (!deletedTransactionIds.contains(id)) {
        recordDeletedTransactionId(id);
        hasChanges = true;
      }
    }

    final remoteDeletedContacts = List<String>.from(data['deletedContactIds'] ?? []);
    for (var id in remoteDeletedContacts) {
      if (!deletedContactIds.contains(id)) {
        recordDeletedContactId(id);
        hasChanges = true;
      }
    }

    final remoteDeletedAssets = List<String>.from(data['deletedAssetIds'] ?? []);
    for (var id in remoteDeletedAssets) {
      if (!deletedAssetIds.contains(id)) {
        recordDeletedAssetId(id);
        hasChanges = true;
      }
    }

    final remoteDeletedReminders = List<String>.from(data['deletedReminderIds'] ?? []);
    for (var id in remoteDeletedReminders) {
      if (!deletedReminderIds.contains(id)) {
        recordDeletedReminderId(id);
        hasChanges = true;
      }
    }

    final remoteDeletedUtangTx = List<String>.from(data['deletedUtangTxIds'] ?? []);
    for (var id in remoteDeletedUtangTx) {
      if (!deletedUtangTxIds.contains(id)) {
        recordDeletedUtangTxId(id);
        hasChanges = true;
      }
    }

    // 2. Kategori Smart Merge
    if (data.containsKey('kategori') && data['kategori'] is List) {
      final remoteKategoriList = (data['kategori'] as List)
          .whereType<Map>()
          .map((item) => kategoriFromMap(Map<String, dynamic>.from(item)))
          .toList();

      for (var rk in remoteKategoriList) {
        final idx = masterKategori.indexWhere((lk) =>
            lk.nama.trim().toLowerCase() == rk.nama.trim().toLowerCase() &&
            lk.tipe == rk.tipe);
        if (idx < 0) {
          masterKategori.add(rk);
          hasChanges = true;
        } else if (masterKategori[idx].ikon != rk.ikon) {
          masterKategori[idx].ikon = rk.ikon;
          hasChanges = true;
        }
      }
    }

    // 3. Akun Smart Merge
    if (data.containsKey('akun') && data['akun'] is List) {
      final remoteAkun = List<String>.from(data['akun'])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (remoteAkun.isNotEmpty) {
        // Jika lokal fresh install (hanya punya "Cash Bank" bawaan & belum ada transaksi)
        // dan akun remote tidak mengandung "Cash Bank", gantikan dengan akun remote
        final isFreshInstall = masterAkun.length == 1 &&
            masterAkun.first == "Cash Bank" &&
            daftarTransaksi.isEmpty &&
            saldoAwalMap.isEmpty;
        if (isFreshInstall && !remoteAkun.contains("Cash Bank")) {
          masterAkun = List<String>.from(remoteAkun);
          hasChanges = true;
        } else {
          for (var ak in remoteAkun) {
            if (!masterAkun.contains(ak)) {
              masterAkun.add(ak);
              hasChanges = true;
            }
          }
        }
      }
    }

    // 4. Akun Utama
    if (data.containsKey('akunUtama') && data['akunUtama'] is String) {
      final remoteAkunUtama = data['akunUtama'] as String;
      if (remoteAkunUtama.isNotEmpty && akunUtama != remoteAkunUtama) {
        akunUtama = remoteAkunUtama;
        hasChanges = true;
      }
    }

    // 5. Saldo Awal Smart Merge
    if (data.containsKey('saldoAwalMap') && data['saldoAwalMap'] is Map) {
      final remoteSaldoAwal = Map<String, double>.from(
        (data['saldoAwalMap'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
      for (var entry in remoteSaldoAwal.entries) {
        if (!saldoAwalMap.containsKey(entry.key) || saldoAwalMap[entry.key] == 0) {
          saldoAwalMap[entry.key] = entry.value;
          hasChanges = true;
        }
      }
    }

    // 6. Limit Pengeluaran
    if (data.containsKey('limitPengeluaran')) {
      final remoteLimit = (data['limitPengeluaran'] as num?)?.toDouble() ?? 0.0;
      if (remoteLimit > 0 || limitPengeluaran == 0) {
        if (limitPengeluaran != remoteLimit) {
          limitPengeluaran = remoteLimit;
          hasChanges = true;
        }
      }
    }

    // 7. Pengaturan Notifikasi & Bank Mapping
    if (data.containsKey('bankAccountMapping') && data['bankAccountMapping'] is Map) {
      bankAccountMapping = Map<String, String>.from(data['bankAccountMapping']);
      hasChanges = true;
    }
    if (data.containsKey('notifBankAutoRecordEnabled') && data['notifBankAutoRecordEnabled'] is bool) {
      if (notifBankAutoRecordEnabled != data['notifBankAutoRecordEnabled']) {
        notifBankAutoRecordEnabled = data['notifBankAutoRecordEnabled'];
        hasChanges = true;
      }
    }
    if (data.containsKey('notifBankMode') && data['notifBankMode'] is String) {
      if (notifBankMode != data['notifBankMode']) {
        notifBankMode = data['notifBankMode'];
        hasChanges = true;
      }
    }
    if (data.containsKey('notifBankDefaultKategori') && data['notifBankDefaultKategori'] is String) {
      if (notifBankDefaultKategori != data['notifBankDefaultKategori']) {
        notifBankDefaultKategori = data['notifBankDefaultKategori'];
        hasChanges = true;
      }
    }

    return hasChanges;
  }

  // ── 3. REALTIME LISTENER (DUA ARAH) ───────────────────────────────────────
  void startRealtimeListener() {
    final user = currentUser;
    if (user == null) return;

    stopRealtimeListener();
    final uid = user.uid;

    // A. Pantau Metadata
    _metaSub = _userDoc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final hasChanges = _applyMetadataFromMap(data);
      if (hasChanges) {
        saveData(triggerCloudSync: false);
        dataVersionNotifier.value++;
      }
    });

    // B. Pantau Transaksi Realtime
    _txSub = _txCol(uid).snapshots().listen((snap) {
      bool hasChanges = false;
      for (var change in snap.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final tx = transaksiFromMap(data);

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          if (!deletedTransactionIds.contains(tx.id)) {
            final idx = daftarTransaksi.indexWhere((t) => t.id == tx.id);
            if (idx >= 0) {
              final localUpdated = daftarTransaksi[idx].updatedAt ?? 0;
              final remoteUpdated = tx.updatedAt ?? 0;
              if (remoteUpdated >= localUpdated) {
                daftarTransaksi[idx] = tx;
                hasChanges = true;
              }
            } else {
              daftarTransaksi.add(tx);
              hasChanges = true;
            }
          }
        } else if (change.type == DocumentChangeType.removed) {
          daftarTransaksi.removeWhere((t) => t.id == change.doc.id);
          recordDeletedTransactionId(change.doc.id);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        daftarTransaksi.sort((a, b) => b.tanggal.compareTo(a.tanggal));
        saveData(triggerCloudSync: false);
        dataVersionNotifier.value++;
      }
    });

    // C. Pantau Kontak Utang Realtime
    _contactSub = _contactCol(uid).snapshots().listen((snap) {
      bool hasChanges = false;
      for (var change in snap.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final kontak = kontakUtangFromMap(data);

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          if (!deletedContactIds.contains(kontak.id)) {
            final idx = daftarKontakUtang.indexWhere((k) => k.id == kontak.id);
            if (idx >= 0) {
              daftarKontakUtang[idx] = kontak;
            } else {
              daftarKontakUtang.add(kontak);
            }
            hasChanges = true;
          }
        } else if (change.type == DocumentChangeType.removed) {
          daftarKontakUtang.removeWhere((k) => k.id == change.doc.id);
          recordDeletedContactId(change.doc.id);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        saveData(triggerCloudSync: false);
        dataVersionNotifier.value++;
      }
    });

    // D. Pantau Aset Realtime
    _assetSub = _assetCol(uid).snapshots().listen((snap) {
      bool hasChanges = false;
      for (var change in snap.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final asset = assetFromMap(data);

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          if (!deletedAssetIds.contains(asset.id)) {
            final idx = daftarAsset.indexWhere((a) => a.id == asset.id);
            if (idx >= 0) {
              daftarAsset[idx] = asset;
            } else {
              daftarAsset.add(asset);
            }
            hasChanges = true;
          }
        } else if (change.type == DocumentChangeType.removed) {
          daftarAsset.removeWhere((a) => a.id == change.doc.id);
          recordDeletedAssetId(change.doc.id);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        saveData(triggerCloudSync: false);
        dataVersionNotifier.value++;
      }
    });

    // E. Pantau Pengingat Rutin Realtime
    _reminderSub = _reminderCol(uid).snapshots().listen((snap) {
      bool hasChanges = false;
      for (var change in snap.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final reminder = recurringReminderFromMap(data);

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          if (!deletedReminderIds.contains(reminder.id)) {
            final idx = daftarPengingatRutin.indexWhere((r) => r.id == reminder.id);
            if (idx >= 0) {
              daftarPengingatRutin[idx] = reminder;
            } else {
              daftarPengingatRutin.add(reminder);
            }
            hasChanges = true;
          }
        } else if (change.type == DocumentChangeType.removed) {
          daftarPengingatRutin.removeWhere((r) => r.id == change.doc.id);
          recordDeletedReminderId(change.doc.id);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        saveData(triggerCloudSync: false);
        dataVersionNotifier.value++;
        try {
          NotificationService.instance.scheduleAllReminders();
        } catch (_) {}
      }
    });
  }

  void stopRealtimeListener() {
    _metaSub?.cancel();
    _txSub?.cancel();
    _contactSub?.cancel();
    _assetSub?.cancel();
    _reminderSub?.cancel();
  }

  // ── 4. TARIK / UNDUH DATA DARI FIREBASE (FORCE PULL & MERGE KE LOKAL) ───────
  Future<bool> pullFromFirebase() async {
    final user = currentUser;
    if (user == null) return false;

    _isSyncing = true;
    try {
      final uid = user.uid;

      // 1. Ambil Dokumen Metadata (Akun, Kategori, Limit, Saldo Awal, dsb.)
      final docSnap = await _userDoc(uid).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>?;
        if (data != null) {
          _applyMetadataFromMap(data);
        }
      }

      // 2. Ambil Koleksi Transaksi
      final txSnap = await _txCol(uid).get();
      for (var doc in txSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final tx = transaksiFromMap(data);
        if (!deletedTransactionIds.contains(tx.id)) {
          final idx = daftarTransaksi.indexWhere((t) => t.id == tx.id);
          if (idx >= 0) {
            final localUpdated = daftarTransaksi[idx].updatedAt ?? 0;
            final remoteUpdated = tx.updatedAt ?? 0;
            if (remoteUpdated >= localUpdated) {
              daftarTransaksi[idx] = tx;
            }
          } else {
            daftarTransaksi.add(tx);
          }
        }
      }
      daftarTransaksi.sort((a, b) => b.tanggal.compareTo(a.tanggal));

      // 3. Ambil Koleksi Kontak Utang
      final contactSnap = await _contactCol(uid).get();
      for (var doc in contactSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final kontak = kontakUtangFromMap(data);
        if (!deletedContactIds.contains(kontak.id)) {
          final idx = daftarKontakUtang.indexWhere((k) => k.id == kontak.id);
          if (idx >= 0) {
            daftarKontakUtang[idx] = kontak;
          } else {
            daftarKontakUtang.add(kontak);
          }
        }
      }

      // 4. Ambil Koleksi Asset
      final assetSnap = await _assetCol(uid).get();
      for (var doc in assetSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final asset = assetFromMap(data);
        if (!deletedAssetIds.contains(asset.id)) {
          final idx = daftarAsset.indexWhere((a) => a.id == asset.id);
          if (idx >= 0) {
            daftarAsset[idx] = asset;
          } else {
            daftarAsset.add(asset);
          }
        }
      }

      // 5. Ambil Koleksi Pengingat Rutin
      final reminderSnap = await _reminderCol(uid).get();
      for (var doc in reminderSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final reminder = recurringReminderFromMap(data);
        if (!deletedReminderIds.contains(reminder.id)) {
          final idx = daftarPengingatRutin.indexWhere((r) => r.id == reminder.id);
          if (idx >= 0) {
            daftarPengingatRutin[idx] = reminder;
          } else {
            daftarPengingatRutin.add(reminder);
          }
        }
      }

      saveData(triggerCloudSync: false);
      dataVersionNotifier.value++;

      try {
        NotificationService.instance.scheduleAllReminders();
      } catch (_) {}

      _isSyncing = false;
      return true;
    } catch (e) {
      debugPrint("Error saat menarik data dari Firebase: $e");
      _isSyncing = false;
      return false;
    }
  }
}

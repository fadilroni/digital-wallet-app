import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../data_model.dart';
import '../google_drive_service.dart';
import '../firebase_sync_service.dart';
import '../bank_notif_service.dart';
import 'kategori_screen.dart';
import 'akun_screen.dart';
import 'recurring_reminder_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isHideSaldo = isHideSaldoGlobal;
  final TextEditingController limitCtrl = TextEditingController();
  bool enableLimit = false;

  static const _storageChannel = MethodChannel(
    'app.bantudigital.dompet_digital/storage',
  );

  @override
  void initState() {
    super.initState();
    enableLimit = limitPengeluaran > 0;
    if (enableLimit) {
      limitCtrl.text = formatRibuan(limitPengeluaran);
    }
  }

  String _formatCloudAuthError(dynamic e) {
    final str = e.toString();
    if (str.contains('10:') || str.contains('DEVELOPER_ERROR')) {
      return "Gagal (Error 10): SHA-1 atau konfigurasi OAuth belum sinkron. Pastikan APK menggunakan keystore yang tepat.";
    }
    if (str.contains('network_error') || str.contains('unavailable')) {
      return "Gagal terhubung: Periksa koneksi internet.";
    }
    if (str.contains('sign_in_canceled') || str.contains('cancelled')) {
      return "Login dibatalkan oleh pengguna.";
    }
    return "Gagal login: $str";
  }

  Future<bool> _checkStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool hasPerm = await _storageChannel.invokeMethod(
        'checkStoragePermission',
      );
      return hasPerm;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _storageChannel.invokeMethod('requestStoragePermission');
    } catch (_) {}
  }

  void _pickFileFromFileManager() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        _confirmAndImport(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal membuka file manager: $e")));
    }
  }

  void _showImportSelectionDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    List<File> files = await getAvailableBackupFiles();
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (files.isEmpty) {
      final defaultFile = await getBackupFile();
      if (!mounted) return;
      String displayPath = defaultFile.path;
      if (displayPath.contains('storage/emulated/0/')) {
        displayPath = displayPath.substring(displayPath.indexOf('backup/'));
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text("Backup Tidak Ditemukan"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tidak ditemukan file backup (.json) di folder backup.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Pastikan file diletakkan di folder penyimpanan internal berikut:",
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  displayPath,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Anda juga dapat menekan 'Cari File di HP' untuk mencari dan memilih file backup secara manual dari folder mana saja (seperti folder Download).",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text("Cari File di HP"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close warning dialog
                _pickFileFromFileManager();
              },
            ),
          ],
        ),
      );
      return;
    }

    // Show selection bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String searchQuery = "";
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomSheetState) {
            final List<File> filteredFiles = files.where((file) {
              final filename = file.path
                  .split(Platform.pathSeparator)
                  .last
                  .toLowerCase();
              return filename.contains(searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.download, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Pilih File Backup",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              searchQuery.isEmpty
                                  ? "Ditemukan ${files.length} file backup"
                                  : "Ditemukan ${filteredFiles.length} dari ${files.length} file backup",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search TextField
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Cari nama file...",
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setBottomSheetState(() {
                                  searchCtrl.clear();
                                  searchQuery = "";
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    onChanged: (val) {
                      setBottomSheetState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx); // Close bottom sheet
                      _pickFileFromFileManager();
                    },
                    icon: const Icon(Icons.folder_open, color: Colors.green),
                    label: const Text(
                      "Pilih File dari File Manager",
                      style: TextStyle(color: Colors.green),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: filteredFiles.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tidak ada file yang cocok",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredFiles.length,
                            itemBuilder: (context, index) {
                              final File file = filteredFiles[index];
                              final String fullPath = file.path;
                              final String filename = fullPath
                                  .split(Platform.pathSeparator)
                                  .last;

                              String displayDate = "";
                              try {
                                final stat = file.statSync();
                                final dt = stat.modified;
                                final day = dt.day.toString().padLeft(2, '0');
                                final month = dt.month.toString().padLeft(
                                  2,
                                  '0',
                                );
                                final year = dt.year;
                                final hour = dt.hour.toString().padLeft(2, '0');
                                final minute = dt.minute.toString().padLeft(
                                  2,
                                  '0',
                                );
                                displayDate = "$day/$month/$year $hour:$minute";
                              } catch (_) {
                                displayDate =
                                    "Waktu modifikasi tidak diketahui";
                              }

                              String sourceApp = "";
                              if (fullPath.contains(
                                'com.example.dompet_pribadi',
                              )) {
                                sourceApp = " (Lama: Dompet Pribadi)";
                              } else if (fullPath.contains(
                                'com.example.dompet_digital',
                              )) {
                                sourceApp = " (Lama: Dompet Digital)";
                              } else if (fullPath.contains(
                                'app.bantudigital.dompet_digital',
                              )) {
                                sourceApp = " (Aplikasi Sekarang)";
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.withOpacity(
                                      0.1,
                                    ),
                                    child: const Icon(
                                      Icons.description,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    filename,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        displayDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (sourceApp.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sourceApp,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(ctx); // Close bottom sheet
                                    _confirmAndImport(file);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Batal",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmAndImport(File file) {
    final filename = file.path.split(Platform.pathSeparator).last;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("Konfirmasi Impor"),
            ],
          ),
          content: Text(
            "Menghidupkan data dari file:\n$filename\n\nSemua data saat ini di aplikasi akan ditimpa. Lanjutkan?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx); // close confirm dialog

                // show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingCtx) => const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                );

                String result = await importData(selectedFile: file);
                if (!mounted) return;
                Navigator.pop(context); // close loading

                final messenger = ScaffoldMessenger.of(context);
                if (result == "success") {
                  setState(() {});
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Data berhasil diimpor!')),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Gagal mengimpor data.')),
                  );
                }
              },
              child: const Text("Ya, Impor"),
            ),
          ],
        );
      },
    );
  }

  void _exportJsonBackup() async {
    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(width: 16),
                Text(
                  "Membuat backup...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final String? filePath = await exportData();
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      if (filePath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal mengekspor data.")));
        return;
      }

      final filename = filePath.split(Platform.pathSeparator).last;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Backup Berhasil",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "File backup berhasil dibuat:\n$filename",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, color: Colors.green),
                        label: const Text(
                          "Bagikan",
                          style: TextStyle(color: Colors.green),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Share.shareXFiles([
                            XFile(filePath),
                          ], text: "Backup Dompet Pribadi");
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Buka File",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final result = await OpenFilex.open(filePath);
                          if (result.type != ResultType.done) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Tidak dapat membuka file: ${result.message}",
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // SECTION 1: KATEGORI & AKUN
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "KATEGORI & AKUN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Kategori'),
            subtitle: const Text('Kelola kategori pemasukan dan pengeluaran'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KategoriScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Akun'),
            subtitle: const Text('Kelola akun / dompet'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AkunScreen()),
              );
            },
          ),
          const Divider(height: 32),

          // SECTION 2: LIMIT PENGELUARAN
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "BATAS PENGELUARAN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("Aktifkan Batas Pengeluaran"),
            subtitle: const Text(
              "Beri peringatan jika pengeluaran melebihi batas",
            ),
            value: enableLimit,
            activeColor: Colors.green,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            onChanged: (val) {
              setState(() {
                enableLimit = val;
                if (!val) {
                  limitCtrl.clear();
                  limitPengeluaran = 0.0;
                } else {
                  final limitStr = limitCtrl.text.replaceAll('.', '');
                  limitPengeluaran = double.tryParse(limitStr) ?? 0.0;
                }
              });
              saveData();
            },
          ),
          if (enableLimit) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
              child: TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [RibuanInputFormatter()],
                decoration: const InputDecoration(
                  labelText: "Batas Maksimal Pengeluaran (Rp)",
                  prefixText: "Rp ",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  final limitStr = limitCtrl.text.replaceAll('.', '');
                  limitPengeluaran = double.tryParse(limitStr) ?? 0.0;
                  saveData();
                },
              ),
            ),
          ],
          const Divider(height: 32),

          // SECTION 3: PENGINGAT RUTIN
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "PENGINGAT RUTIN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Kelola Pengingat Rutin'),
            subtitle: const Text('Tambah atau edit tagihan rutin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecurringReminderScreen(),
                ),
              ).then((_) => setState(() {}));
            },
          ),
          const Divider(height: 32),

          // SECTION 4: CADANGAN DATA
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "CADANGAN DATA",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('Ekspor Data (Backup)'),
            leading: const Icon(Icons.upload_file),
            onTap: () {
              _exportJsonBackup();
            },
          ),
          ListTile(
            title: const Text('Impor Data (Backup)'),
            leading: const Icon(Icons.download),
            onTap: () async {
              bool hasPermission = await _checkStoragePermission();
              if (!hasPermission) {
                await _requestStoragePermission();
                await Future.delayed(const Duration(milliseconds: 500));
                hasPermission = await _checkStoragePermission();
                if (!hasPermission) {
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Izin Dibutuhkan"),
                      content: const Text(
                        "Aplikasi membutuhkan izin akses semua file untuk membaca daftar file cadangan di penyimpanan internal /backup/dompet_digital.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Tutup"),
                        ),
                      ],
                    ),
                  );
                  return;
                }
              }
              _showImportSelectionDialog();
            },
          ),
          const Divider(height: 32),

          // SECTION 5: SINKRONISASI CLOUD ONLINE
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "SINKRONISASI CLOUD ONLINE",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          activeCloudProvider = 'firebase';
                        });
                        saveData();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: activeCloudProvider == 'firebase'
                              ? Colors.green
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_sync,
                                size: 18,
                                color: activeCloudProvider == 'firebase'
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Firebase Cloud",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: activeCloudProvider == 'firebase'
                                      ? Colors.white
                                      : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          activeCloudProvider = 'gdrive';
                        });
                        saveData();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: activeCloudProvider == 'gdrive'
                              ? Colors.green
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_to_drive,
                                size: 18,
                                color: activeCloudProvider == 'gdrive'
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Google Drive",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: activeCloudProvider == 'gdrive'
                                      ? Colors.white
                                      : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tampilan Berdasarkan Cloud Provider
          if (activeCloudProvider == 'firebase') ...[
            Builder(
              builder: (context) {
                final fbUser = FirebaseSyncService.instance.currentUser;
                final isSyncing = FirebaseSyncService.instance.isSyncing;

                if (fbUser == null) {
                  return ListTile(
                    leading: const Icon(Icons.cloud_off, color: Colors.orange),
                    title: const Text('Hubungkan Firebase Cloud Sync'),
                    subtitle: const Text('Login Google untuk sinkronisasi realtime 2 HP'),
                    trailing: const Icon(Icons.login, color: Colors.green),
                    onTap: () async {
                      try {
                        final user = await FirebaseSyncService.instance.signInWithGoogle();
                        setState(() {
                          isHideSaldo = isHideSaldoGlobal;
                          enableLimit = limitPengeluaran > 0;
                          if (enableLimit) {
                            limitCtrl.text = formatRibuan(limitPengeluaran);
                          }
                        });
                        if (!context.mounted) return;
                        if (user != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Berhasil masuk: ${user.email}. Data berhasil disinkronkan.")),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_formatCloudAuthError(e)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  );
                }

                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: fbUser.photoURL != null ? NetworkImage(fbUser.photoURL!) : null,
                        child: fbUser.photoURL == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(fbUser.displayName ?? 'Akun Firebase'),
                      subtitle: Text(fbUser.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () async {
                          await FirebaseSyncService.instance.signOut();
                          setState(() {});
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
                      title: const Text('Migrasikan Data ke Firebase (1-Klik)'),
                      subtitle: const Text('Upload seluruh data lokal ke Firebase Firestore'),
                      trailing: isSyncing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right),
                      onTap: isSyncing
                          ? null
                          : () async {
                              setState(() {});
                              final ok = await FirebaseSyncService.instance.migrateLocalDataToFirebase();
                              setState(() {});
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? "Seluruh data lokal berhasil dimigrasikan ke Firebase!"
                                        : "Gagal migrasi data ke Firebase.",
                                  ),
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_download_outlined, color: Colors.teal),
                      title: const Text('Tarik Data dari Firebase (Download)'),
                      subtitle: const Text('Unduh dan sinkronkan akun, kategori & transaksi dari cloud'),
                      trailing: isSyncing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right),
                      onTap: isSyncing
                          ? null
                          : () async {
                              setState(() {});
                              final ok = await FirebaseSyncService.instance.pullFromFirebase();
                              setState(() {
                                isHideSaldo = isHideSaldoGlobal;
                                enableLimit = limitPengeluaran > 0;
                                if (enableLimit) {
                                  limitCtrl.text = formatRibuan(limitPengeluaran);
                                }
                              });
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? "Data dari Firebase berhasil ditarik dan disinkronkan!"
                                        : "Gagal menarik data dari Firebase.",
                                  ),
                                ),
                              );
                            },
                    ),
                    const ListTile(
                      leading: Icon(Icons.sync, color: Colors.green),
                      title: Text('Sinkronisasi Realtime'),
                      subtitle: Text('Aktif • Setiap perubahan tersinkron otomatis antar-HP'),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            Builder(
              builder: (context) {
                final user = GoogleDriveSyncService.instance.currentUser;
                final isSyncing = GoogleDriveSyncService.instance.isSyncing;

                if (user == null) {
                  return ListTile(
                    leading: const Icon(Icons.cloud_off, color: Colors.orange),
                    title: const Text('Hubungkan Akun Google Drive'),
                    subtitle: const Text('Login untuk sinkronisasi cadangan file di Drive'),
                    trailing: const Icon(Icons.login, color: Colors.green),
                    onTap: () async {
                      try {
                        await GoogleDriveSyncService.instance.signIn();
                        setState(() {});
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Berhasil terhubung ke Akun Google!")),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_formatCloudAuthError(e)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  );
                }

                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(user.displayName ?? 'Akun Google'),
                      subtitle: Text(user.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () async {
                          await GoogleDriveSyncService.instance.signOut();
                          setState(() {});
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                      title: const Text('Upload Data Manual'),
                      subtitle: const Text('Gabungkan & upload data lokal ke Google Drive'),
                      trailing: isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
                      onTap: isSyncing
                          ? null
                          : () async {
                              setState(() {});
                              final success = await GoogleDriveSyncService.instance.uploadDataToDrive();
                              setState(() {});
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? "Data berhasil digabungkan & di-upload ke Google Drive!"
                                        : "Gagal meng-upload data ke Google Drive.",
                                  ),
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_download, color: Colors.green),
                      title: const Text('Sinkron / Tarik Data Online'),
                      subtitle: const Text('Tarik & gabungkan data dari Google Drive'),
                      trailing: isSyncing ? const CircularProgressIndicator() : const Icon(Icons.refresh),
                      onTap: isSyncing
                          ? null
                          : () async {
                              setState(() {});
                              final success = await GoogleDriveSyncService.instance.downloadDataFromDrive();
                              setState(() {});
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? "Data berhasil disinkronkan & digabungkan dari Google Drive!"
                                        : "Gagal menarik data dari Google Drive.",
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                );
              },
            ),
          ],

          const Divider(height: 32),

          // SECTION 6: CATAT TRANSAKSI DARI NOTIFIKASI BANK
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "CATAT TRANSAKSI DARI NOTIFIKASI BANK",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
            title: const Text('Catat Otomatis dari Notifikasi'),
            subtitle: const Text('Membaca notifikasi mobile banking & e-wallet'),
            value: notifBankAutoRecordEnabled,
            onChanged: (val) async {
              if (val) {
                bool granted = await BankNotifService.instance.isPermissionGranted();
                if (!granted) {
                  await BankNotifService.instance.requestPermission();
                }
                BankNotifService.instance.startListening();
              } else {
                BankNotifService.instance.stopListening();
              }
              setState(() {
                notifBankAutoRecordEnabled = val;
              });
              saveData();
            },
          ),
          if (notifBankAutoRecordEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                elevation: 0,
                color: Colors.blue.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Mode Pencatatan:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      RadioListTile<String>(
                        title: const Text('Opsi A: Konfirmasi 1-Klik (Rekomendasi)', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Memunculkan notifikasi/dialog konfirmasi sebelum disimpan', style: TextStyle(fontSize: 11)),
                        value: 'confirm',
                        groupValue: notifBankMode,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) {
                          setState(() {
                            notifBankMode = v ?? 'confirm';
                          });
                          saveData();
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Opsi B: Otomatis Langsung Masuk', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Transaksi langsung masuk saldo tanpa konfirmasi manual', style: TextStyle(fontSize: 11)),
                        value: 'auto',
                        groupValue: notifBankMode,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) {
                          setState(() {
                            notifBankMode = v ?? 'auto';
                          });
                          saveData();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined, color: Colors.orange),
              title: const Text('Kategori Default Cadangan'),
              subtitle: Text(notifBankDefaultKategori),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return SimpleDialog(
                      title: const Text("Pilih Kategori Cadangan"),
                      children: masterKategori
                          .where((k) => k.tipe == "Pengeluaran")
                          .map(
                            (k) => SimpleDialogOption(
                              onPressed: () {
                                setState(() {
                                  notifBankDefaultKategori = k.nama;
                                });
                                saveData();
                                Navigator.pop(ctx);
                              },
                              child: Text(k.nama),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.green),
              title: const Text('Atur Pemetaan Akun Bank'),
              subtitle: Text('${bankAccountMapping.length} akun terhubung ke notifikasi bank'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AkunScreen()),
                ).then((_) {
                  setState(() {});
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.blueGrey),
              title: const Text('Periksa Izin Notifikasi HP'),
              subtitle: const Text('Buka halaman pengaturan izin notifikasi Android'),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: () async {
                await BankNotifService.instance.requestPermission();
              },
            ),
          ],
        ],
      ),
    );
  }
}

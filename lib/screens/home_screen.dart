import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../data_model.dart';
import 'kategori_screen.dart';
import 'akun_screen.dart';
import 'grafik_screen.dart';
import 'utang_screen.dart';
import 'asset_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  bool isHideSaldo = isHideSaldoGlobal;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _pilihanTipe = "Pengeluaran";
  String _pilihanKategori = "";
  String _pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) ? akunUtama : (masterAkun.isNotEmpty ? masterAkun.first : "");
  int _currentIndex = 0;
  String _filterAkun = "Semua";
  String _filterKategori = "Semua";
  String _filterTipe = "Semua";
  // Melacak tab aktif di KategoriScreen agar FAB bisa auto-select tipe
  String _kategoriTabTipe = "Pengeluaran";

  // Filter Tanggal Default: Awal dan Akhir Bulan Saat Ini
  DateTime rangeMulai = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime rangeSelesai = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  String _formatTanggalHeader(DateTime date) {
    const bulan = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return "${date.day} ${bulan[date.month - 1]} ${date.year}";
  }

  String _formatWaktu(DateTime date) {
    String hourStr = date.hour < 10 ? "0${date.hour}" : "${date.hour}";
    String minuteStr = date.minute < 10 ? "0${date.minute}" : "${date.minute}";
    return "$hourStr:$minuteStr";
  }

  void _showDetailTransaksi(Transaksi item, IconData categoryIcon) {
    final isPengeluaran = item.tipe == "Pengeluaran";
    final color = isPengeluaran ? Colors.red : Colors.green;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              // Icon + nominal
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(categoryIcon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.kategori,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.tipe,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${isPengeluaran ? "-" : "+"}Rp ${formatRibuan(item.nominal)}",
                    style: TextStyle(
                      color: isPengeluaran
                          ? Colors.red[800]
                          : Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              // Detail rows
              _detailRow(
                Icons.account_balance_wallet_outlined,
                "Akun",
                item.akun,
              ),
              if (item.catatan.isNotEmpty)
                _detailRow(Icons.notes_outlined, "Catatan", item.catatan),
              _detailRow(
                Icons.calendar_today_outlined,
                "Tanggal",
                "${_formatTanggalHeader(item.tanggal)}, ${_formatWaktu(item.tanggal)}",
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        "Hapus",
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _hapusTransaksi(item);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editTransaksi(item);
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
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _editTransaksi(Transaksi item) {
    showDialog(
      context: context,
      builder: (context) {
        String editTipe = item.tipe;
        String editKategori = item.kategori;
        String editAkun = item.akun;
        DateTime editTanggal = item.tanggal;
        final TextEditingController nominalEditController =
            TextEditingController(text: formatRibuan(item.nominal));
        final TextEditingController catatanEditController =
            TextEditingController(text: item.catatan);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> kategoriAktif = masterKategori
                .where((k) => k.tipe == editTipe)
                .map((k) => k.nama)
                .toList();

            // Proteksi error jika list kosong atau data berubah
            if (kategoriAktif.isNotEmpty &&
                !kategoriAktif.contains(editKategori)) {
              editKategori = kategoriAktif.first;
            }

            String tanggalStr =
                "${editTanggal.day.toString().padLeft(2, '0')}/"
                "${editTanggal.month.toString().padLeft(2, '0')}/"
                "${editTanggal.year}";
            String jamStr =
                "${editTanggal.hour.toString().padLeft(2, '0')}:"
                "${editTanggal.minute.toString().padLeft(2, '0')}";

            return AlertDialog(
              title: Text("Edit Transaksi"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nominalEditController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: InputDecoration(labelText: "Nominal (Rp)"),
                    ),
                    TextField(
                      controller: catatanEditController,
                      decoration: InputDecoration(
                        labelText: "Keterangan/Catatan",
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: editTipe,
                      decoration: InputDecoration(labelText: "Tipe"),
                      items: ["Pengeluaran", "Pemasukan"]
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          editTipe = val!;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: editKategori.isEmpty ? null : editKategori,
                      decoration: InputDecoration(labelText: "Kategori"),
                      items: kategoriAktif
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          editKategori = val!;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: editAkun,
                      decoration: InputDecoration(
                        labelText: "Simpan/Ambil Dari",
                      ),
                      items: masterAkun
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          editAkun = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Picker Tanggal & Jam
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(tanggalStr),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: editTanggal,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  editTanggal = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    editTanggal.hour,
                                    editTanggal.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(jamStr),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: editTanggal.hour,
                                  minute: editTanggal.minute,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  editTanggal = DateTime(
                                    editTanggal.year,
                                    editTanggal.month,
                                    editTanggal.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nominalEditController.text.isNotEmpty) {
                      setState(() {
                        item.nominal =
                            double.tryParse(
                              nominalEditController.text.replaceAll('.', ''),
                            ) ??
                            0;
                        item.catatan = catatanEditController.text;
                        item.tipe = editTipe;
                        item.kategori = editKategori;
                        item.akun = editAkun;
                        item.tanggal = editTanggal;
                      });
                      saveData();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _hapusTransaksi(Transaksi item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Hapus Transaksi"),
          content: Text("Apakah Anda yakin ingin menghapus transaksi ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  daftarTransaksi.removeWhere((t) => t.id == item.id);
                });
                saveData();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  static const _storageChannel = MethodChannel('app.bantudigital.dompet_digital/storage');

  Future<bool> _checkStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool hasPerm = await _storageChannel.invokeMethod('checkStoragePermission');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal membuka file manager: $e")),
      );
    }
  }

  void _showImportSelectionDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
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
              final filename = file.path.split(Platform.pathSeparator).last.toLowerCase();
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
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
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
                    label: const Text("Pilih File dari File Manager", style: TextStyle(color: Colors.green)),
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
                                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  "Tidak ada file yang cocok",
                                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
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
                              final String filename = fullPath.split(Platform.pathSeparator).last;

                              String displayDate = "";
                              try {
                                final stat = file.statSync();
                                final dt = stat.modified;
                                final day = dt.day.toString().padLeft(2, '0');
                                final month = dt.month.toString().padLeft(2, '0');
                                final year = dt.year;
                                final hour = dt.hour.toString().padLeft(2, '0');
                                final minute = dt.minute.toString().padLeft(2, '0');
                                displayDate = "$day/$month/$year $hour:$minute";
                              } catch (_) {
                                displayDate = "Waktu modifikasi tidak diketahui";
                              }

                              String sourceApp = "";
                              if (fullPath.contains('com.example.dompet_pribadi')) {
                                sourceApp = " (Lama: Dompet Pribadi)";
                              } else if (fullPath.contains('com.example.dompet_digital')) {
                                sourceApp = " (Lama: Dompet Digital)";
                              } else if (fullPath.contains('app.bantudigital.dompet_digital')) {
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                    child: const Icon(Icons.description, color: Colors.green),
                                  ),
                                  title: Text(
                                    filename,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        displayDate,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      if (sourceApp.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sourceApp,
                                          style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
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
                    child: const Text("Batal", style: TextStyle(fontWeight: FontWeight.bold)),
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
          content: Text("Menghidupkan data dari file:\n$filename\n\nSemua data saat ini di aplikasi akan ditimpa. Lanjutkan?"),
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

  void _showSettingsDialog() {
    final TextEditingController limitCtrl = TextEditingController(
      text: limitPengeluaran > 0 ? formatRibuan(limitPengeluaran) : "",
    );
    bool enableLimit = limitPengeluaran > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBottomSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
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
                    const Row(
                      children: [
                        Icon(Icons.settings, color: Colors.green, size: 28),
                        SizedBox(width: 12),
                        Text(
                          "Pengaturan Aplikasi",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // SECTION 1: LIMIT PENGELUARAN
                    const Text(
                      "BATAS PENGELUARAN",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("Aktifkan Batas Pengeluaran"),
                      subtitle: const Text("Beri peringatan jika pengeluaran melebihi batas"),
                      value: enableLimit,
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setBottomSheetState(() {
                          enableLimit = val;
                          if (!val) {
                            limitCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (enableLimit) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: limitCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: "Batas Maksimal Pengeluaran (Rp)",
                          prefixText: "Rp ",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const Divider(height: 32),

                    // SECTION 2: PRIVASI
                    const Text(
                      "PRIVASI",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("Sembunyikan Saldo"),
                      subtitle: const Text("Sembunyikan saldo di halaman utama"),
                      value: isHideSaldo,
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setBottomSheetState(() {
                          isHideSaldo = val;
                          isHideSaldoGlobal = val;
                        });
                        setState(() {});
                        saveData();
                      },
                    ),
                    const Divider(height: 32),

                    // SECTION 3: CADANGAN DATA
                    const Text(
                      "CADANGAN DATA",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.upload),
                            label: const Text("Ekspor Data"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              
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
                                      content: const Text("Aplikasi membutuhkan izin akses semua file untuk dapat menulis cadangan ke penyimpanan internal /backup/dompet_digital."),
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

                              String? path = await exportData();
                              if (path != null) {
                                String displayPath = path;
                                if (path.contains('storage/emulated/0/')) {
                                  displayPath = path.substring(path.indexOf('backup/'));
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Backup berhasil diekspor ke Penyimpanan Internal:\n$displayPath'),
                                    duration: const Duration(seconds: 8),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Gagal mengekspor data.')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download, color: Colors.green),
                            label: const Text("Impor Data", style: TextStyle(color: Colors.green)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              
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
                                      content: const Text("Aplikasi membutuhkan izin akses semua file untuk membaca daftar file cadangan di penyimpanan internal /backup/dompet_digital."),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // SAVE BUTTON
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (enableLimit) {
                            final limitStr = limitCtrl.text.replaceAll('.', '');
                            limitPengeluaran = double.tryParse(limitStr) ?? 0.0;
                          } else {
                            limitPengeluaran = 0.0;
                          }
                        });
                        saveData();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        "Simpan Pengaturan",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _tambahTransaksi() {
    DateTime pilihanTanggal = DateTime.now();
    if (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) {
      _pilihanAkun = akunUtama;
    } else if (masterAkun.isNotEmpty) {
      _pilihanAkun = masterAkun.first;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> kategoriDialog = masterKategori
                .where((k) => k.tipe == _pilihanTipe)
                .map((k) => k.nama)
                .toList();

            if (kategoriDialog.isNotEmpty &&
                !kategoriDialog.contains(_pilihanKategori)) {
              _pilihanKategori = kategoriDialog.first;
            }

            String tanggalStr =
                "${pilihanTanggal.day.toString().padLeft(2, '0')}/"
                "${pilihanTanggal.month.toString().padLeft(2, '0')}/"
                "${pilihanTanggal.year}";
            String jamStr =
                "${pilihanTanggal.hour.toString().padLeft(2, '0')}:"
                "${pilihanTanggal.minute.toString().padLeft(2, '0')}";

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text("Tambah Transaksi"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: "Nominal (Rp)",
                        border: OutlineInputBorder(),
                        prefixText: "Rp ",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _catatanController,
                      decoration: const InputDecoration(
                        labelText: "Keterangan/Catatan",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _pilihanTipe,
                      decoration: const InputDecoration(
                        labelText: "Tipe",
                        border: OutlineInputBorder(),
                      ),
                      items: ["Pengeluaran", "Pemasukan"]
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          _pilihanTipe = val!;
                          final newList = masterKategori
                              .where((k) => k.tipe == _pilihanTipe)
                              .map((k) => k.nama)
                              .toList();
                          _pilihanKategori = newList.isNotEmpty
                              ? newList.first
                              : "";
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_pilihanTipe),
                      initialValue: kategoriDialog.isNotEmpty
                          ? _pilihanKategori
                          : null,
                      decoration: const InputDecoration(
                        labelText: "Kategori",
                        border: OutlineInputBorder(),
                      ),
                      items: kategoriDialog
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => _pilihanKategori = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _pilihanAkun,
                      decoration: const InputDecoration(
                        labelText: "Simpan/Ambil Dari (Akun)",
                        border: OutlineInputBorder(),
                      ),
                      items: masterAkun
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => _pilihanAkun = val!),
                    ),
                    const SizedBox(height: 12),
                    // Picker Tanggal & Jam
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(tanggalStr),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: pilihanTanggal,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  pilihanTanggal = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    pilihanTanggal.hour,
                                    pilihanTanggal.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(jamStr),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: pilihanTanggal.hour,
                                  minute: pilihanTanggal.minute,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  pilihanTanggal = DateTime(
                                    pilihanTanggal.year,
                                    pilihanTanggal.month,
                                    pilihanTanggal.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nominalController.clear();
                    _catatanController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Batal"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Simpan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (_nominalController.text.isNotEmpty) {
                      setState(() {
                        daftarTransaksi.add(
                          Transaksi(
                            id: DateTime.now().toString(),
                            nominal:
                                double.tryParse(
                                  _nominalController.text.replaceAll('.', ''),
                                ) ??
                                0,
                            catatan: _catatanController.text,
                            tipe: _pilihanTipe,
                            kategori: _pilihanKategori,
                            akun: _pilihanAkun,
                            tanggal: pilihanTanggal,
                          ),
                        );
                        saveData();
                        _nominalController.clear();
                        _catatanController.clear();
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _tambahKategoriDialog() {
    final TextEditingController namaCtrl = TextEditingController();
    // Auto-select tipe berdasarkan tab yang sedang dibuka di KategoriScreen
    String tipe = _kategoriTabTipe;
    IconData ikon = daftarPilihanIkon.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.category, color: Colors.green),
                  SizedBox(width: 8),
                  Text("Tambah Kategori"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: namaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nama Kategori",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipe,
                      decoration: const InputDecoration(
                        labelText: "Tipe Kategori",
                        border: OutlineInputBorder(),
                      ),
                      items: ["Pengeluaran", "Pemasukan"]
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) => setDialogState(() => tipe = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IconData>(
                      initialValue: ikon,
                      decoration: const InputDecoration(
                        labelText: "Pilih Logo Kategori",
                        border: OutlineInputBorder(),
                      ),
                      items: daftarPilihanIkon.map((IconData ic) {
                        return DropdownMenuItem<IconData>(
                          value: ic,
                          child: Row(
                            children: [
                              Icon(ic, color: Colors.green),
                              const SizedBox(width: 12),
                              Text(getNamaIkon(ic)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => ikon = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Simpan"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (namaCtrl.text.isNotEmpty) {
                      setState(() {
                        masterKategori.add(
                          KategoriModel(
                            nama: namaCtrl.text,
                            tipe: tipe,
                            ikon: ikon,
                          ),
                        );
                        saveData();
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _tambahAkunDialog() {
    final TextEditingController namaCtrl = TextEditingController();
    final TextEditingController saldoAwalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.green),
              SizedBox(width: 8),
              Text("Tambah Akun/Dompet"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nama Akun/Dompet (Misal: Mandiri)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: saldoAwalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Saldo Awal (Rp)",
                    prefixText: "Rp ",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Simpan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (namaCtrl.text.isNotEmpty) {
                  final String nama = namaCtrl.text;
                  final String saldoAwalStr = saldoAwalCtrl.text.replaceAll('.', '');
                  final double saldoAwal = double.tryParse(saldoAwalStr) ?? 0.0;
                  setState(() {
                    masterAkun.add(nama);
                    if (saldoAwal > 0) {
                      saldoAwalMap[nama] = saldoAwal;
                    }
                    saveData();
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Memilih kategori yang sesuai secara dinamis
    List<String> kategoriAktif = masterKategori
        .where((k) => k.tipe == _pilihanTipe)
        .map((k) => k.nama)
        .toList();

    // Proteksi error jika list kosong atau data berubah
    if (kategoriAktif.isNotEmpty && !kategoriAktif.contains(_pilihanKategori)) {
      _pilihanKategori = kategoriAktif.first;
    }

    // Filter data berdasarkan Range Tanggal, Akun, & Hitung Saldo Bersih, Pemasukan, Pengeluaran
    double totalPemasukan = 0;
    double totalPengeluaran = 0;

    // Hitung total pengeluaran khusus bulan saat ini untuk warning limit
    final DateTime nowTime = DateTime.now();
    double pengeluaranBulanIni = 0;
    for (var t in daftarTransaksi) {
      if (t.tipe == "Pengeluaran" &&
          t.tanggal.year == nowTime.year &&
          t.tanggal.month == nowTime.month) {
        pengeluaranBulanIni += t.nominal;
      }
    }

    // Proteksi filter akun jika akun dihapus dari masterAkun
    if (!["Semua", ...masterAkun].contains(_filterAkun)) {
      _filterAkun = "Semua";
    }

    // Proteksi pilihan akun jika akun dihapus dari masterAkun
    if (!masterAkun.contains(_pilihanAkun) && masterAkun.isNotEmpty) {
      _pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) ? akunUtama : masterAkun.first;
    }

    // Dinamis: Kategori yang ditampilkan menyesuaikan tipe yang dipilih
    List<String> listKategoriFilter = [];
    if (_filterTipe == "Semua") {
      listKategoriFilter = masterKategori.map((k) => k.nama).toSet().toList();
    } else {
      listKategoriFilter = masterKategori
          .where((k) => k.tipe == _filterTipe)
          .map((k) => k.nama)
          .toSet()
          .toList();
    }

    // Proteksi filter kategori jika kategori tidak valid/dihapus
    if (!["Semua", ...listKategoriFilter].contains(_filterKategori)) {
      _filterKategori = "Semua";
    }

    List<Transaksi> riwayatTerfilter = daftarTransaksi.where((t) {
      bool masukRange =
          t.tanggal.isAfter(rangeMulai.subtract(Duration(days: 1))) &&
          t.tanggal.isBefore(rangeSelesai.add(Duration(days: 1)));

      bool masukTipe = _filterTipe == "Semua" || t.tipe == _filterTipe;
      bool masukAkun = _filterAkun == "Semua" || t.akun == _filterAkun;
      bool masukKategori =
          _filterKategori == "Semua" || t.kategori == _filterKategori;
      bool lolosFilter = masukRange && masukTipe && masukAkun && masukKategori;

      if (lolosFilter) {
        if (t.tipe == "Pemasukan") totalPemasukan += t.nominal;
        if (t.tipe == "Pengeluaran") totalPengeluaran += t.nominal;
      }
      return lolosFilter;
    }).toList();

    // Urutkan transaksi berdasarkan tanggal secara descending (terbaru di atas)
    riwayatTerfilter.sort((a, b) => b.tanggal.compareTo(a.tanggal));

    // Kelompokkan transaksi berdasarkan tanggal untuk tampilan list
    Map<String, List<Transaksi>> transaksiPerTanggal = {};
    for (var t in riwayatTerfilter) {
      String key = _formatTanggalHeader(t.tanggal);
      if (!transaksiPerTanggal.containsKey(key)) {
        transaksiPerTanggal[key] = [];
      }
      transaksiPerTanggal[key]!.add(t);
    }

    double totalSaldo = totalPemasukan - totalPengeluaran;

    String appBarTitle;
    if (_currentIndex == 0) {
      appBarTitle = "Catatan Keuangan Digital";
    } else if (_currentIndex == 1) {
      appBarTitle = "Grafik Keuangan";
    } else if (_currentIndex == 2) {
      appBarTitle = "Kelola Master Kategori";
    } else if (_currentIndex == 3) {
      appBarTitle = "Master Akun / Dompet";
    } else if (_currentIndex == 4) {
      appBarTitle = "Utang & Piutang";
    } else {
      appBarTitle = "Portofolio Aset Kripto";
    }

    final Widget homeBody = SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FILTER RANGE TANGGAL
            Text(
              "FILTER PERIODE",
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: rangeMulai,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => rangeMulai = picked);
                  },
                  child: Text(
                    "Dari: ${rangeMulai.day}/${rangeMulai.month}/${rangeMulai.year}",
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: rangeSelesai,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => rangeSelesai = picked);
                  },
                  child: Text(
                    "Sampai: ${rangeSelesai.day}/${rangeSelesai.month}/${rangeSelesai.year}",
                  ),
                ),
              ],
            ),
            // FILTER UTAMA (Tipe, Akun, Kategori)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Filter Tipe
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Tipe: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 5),
                    DropdownButton<String>(
                      value: _filterTipe,
                      items: ["Semua", "Pengeluaran", "Pemasukan"].map((
                        String val,
                      ) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _filterTipe = val!;
                          // Reset filter kategori jika tidak valid dengan tipe terpilih
                          if (_filterTipe != "Semua") {
                            final validCats = masterKategori
                                .where((k) => k.tipe == _filterTipe)
                                .map((k) => k.nama)
                                .toSet();
                            if (!validCats.contains(_filterKategori)) {
                              _filterKategori = "Semua";
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                // Filter Akun
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Akun: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 5),
                    DropdownButton<String>(
                      value: _filterAkun,
                      items: ["Semua", ...masterAkun].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _filterAkun = val!;
                        });
                      },
                    ),
                  ],
                ),
                // Filter Kategori
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Kategori: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 5),
                    DropdownButton<String>(
                      value: _filterKategori,
                      items: ["Semua", ...listKategoriFilter].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _filterKategori = val!;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (limitPengeluaran > 0 && pengeluaranBulanIni > limitPengeluaran) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Batas Pengeluaran Terlampaui!",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Pengeluaran bulan ini (Rp ${formatRibuan(pengeluaranBulanIni)}) telah melebihi batas maksimal bulanan Anda (Rp ${formatRibuan(limitPengeluaran)}).",
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // RINGKASAN SALDO, PEMASUKAN, & PENGELUARAN
            // RINGKASAN SALDO, PEMASUKAN, & PENGELUARAN
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              "Pemasukan",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHideSaldo
                                  ? "Rp ••••••••"
                                  : "Rp ${formatRibuan(totalPemasukan)}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        Column(
                          children: [
                            const Text(
                              "Pengeluaran",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHideSaldo
                                  ? "Rp ••••••••"
                                  : "Rp ${formatRibuan(totalPengeluaran)}",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Saldo Bersih + Tombol Mata
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isHideSaldo = !isHideSaldo;
                              isHideSaldoGlobal = isHideSaldo;
                            });
                            saveData();
                          },
                          icon: Icon(
                            isHideSaldo
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                          ),
                        ),
                        Text(
                          isHideSaldo
                              ? "Saldo Bersih: Rp ••••••••"
                              : "Saldo Bersih: Rp ${formatRibuan(totalSaldo)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: totalSaldo >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(height: 10),
            // DAFTAR RIWAYAT DENGAN GRUP TANGGAL
            ...transaksiPerTanggal.entries.map((entry) {
              String tanggalHeader = entry.key;
              List<Transaksi> listTransaksi = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      bottom: 8.0,
                      left: 8.0,
                    ),
                    child: Text(
                      tanggalHeader,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  ...listTransaksi.map((item) {
                    final categoryDetail = masterKategori.firstWhere(
                      (k) => k.nama == item.kategori,
                      orElse: () => KategoriModel(
                        nama: item.kategori,
                        tipe: item.tipe,
                        ikon: Icons.category,
                      ),
                    );
                    final isPengeluaran = item.tipe == "Pengeluaran";
                    final color = isPengeluaran ? Colors.red : Colors.green;
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      onTap: () =>
                          _showDetailTransaksi(item, categoryDetail.ikon),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          categoryDetail.ikon,
                          color: color,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        item.kategori,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        item.catatan.isNotEmpty
                            ? "${item.catatan} • ${item.akun}"
                            : item.akun,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${isPengeluaran ? "-Rp. " : "+Rp. "}${formatRibuan(item.nominal)}",
                            style: TextStyle(
                              color: isPengeluaran
                                  ? Colors.red[800]
                                  : Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatWaktu(item.tanggal),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      );

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        automaticallyImplyLeading: false,
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: "Pengaturan",
                  onPressed: _showSettingsDialog,
                ),
              ]
            : null,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          KeepAliveWrapper(child: homeBody),
          const KeepAliveWrapper(child: GrafikScreen()),
          KeepAliveWrapper(
            child: KategoriScreen(
              onTabChanged: (tipe) => setState(() => _kategoriTabTipe = tipe),
            ),
          ),
          const KeepAliveWrapper(child: AkunScreen()),
          const KeepAliveWrapper(child: UtangScreen()),
          const KeepAliveWrapper(child: AssetScreen()),
        ],
      ),
      floatingActionButton:
          (_currentIndex == 0 || _currentIndex == 2 || _currentIndex == 3)
          ? FloatingActionButton(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              onPressed: () {
                if (_currentIndex == 0) {
                  _tambahTransaksi();
                } else if (_currentIndex == 2) {
                  _tambahKategoriDialog();
                } else if (_currentIndex == 3) {
                  _tambahAkunDialog();
                }
              },
              child: const Icon(Icons.add),
            )
          : null, // AssetScreen manages its own FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.jumpToPage(index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Grafik"),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: "Kategori",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Akun/Dompet",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind_outlined),
            label: "Utang",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_bitcoin),
            label: "Aset",
          ),
        ],
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'settings_screen.dart'; // Import the new settings screen
import '../data_model.dart';
import 'grafik_screen.dart';
import 'utang_screen.dart';
import 'asset_screen.dart';
import '../notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (daftarPengingatRutin.any((r) => r.enabled)) {
        NotificationService.instance.scheduleAllReminders();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _pilihanTipe = "Pengeluaran";
  String _pilihanKategori = "";
  String _pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama))
      ? akunUtama
      : (masterAkun.isNotEmpty ? masterAkun.first : "");
  int _currentIndex = 0;
  String _filterAkun = "Semua";
  String _filterKategori = "Semua";
  String _filterTipe = "Semua";

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

  String _formatDateReadable(DateTime date) {
    const bulan = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    return "${date.day.toString().padLeft(2, '0')} ${bulan[date.month - 1]} ${date.year}";
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
                      color: color.withOpacity(0.12),
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
                  // Jika Pindah Dana Pengeluaran → hapus pasangan masuknya
                  if (item.tipe == 'Pengeluaran' &&
                      item.kategori == 'Pindah Dana') {
                    daftarTransaksi.removeWhere(
                      (t) => t.id == 'transfer_masuk_${item.id}',
                    );
                  }
                  // Jika Pindah Dana Pemasukan → hapus pasangan keluarnya
                  if (item.tipe == 'Pemasukan' &&
                      item.kategori == 'Pindah Dana') {
                    daftarTransaksi.removeWhere(
                      (t) => t.id == 'transfer_keluar_${item.id}',
                    );
                  }
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

  void _exportToExcel(List<Transaksi> transaksi) async {
    if (transaksi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada transaksi untuk diekspor.")),
      );
      return;
    }

    // Tampilkan loading dialog
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
                  "Membuat Excel...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      var excel = xl.Excel.createExcel();
      xl.Sheet sheetObject = excel['Laporan Transaksi'];

      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Headers
      List<xl.CellValue> headers = [
        xl.TextCellValue("No"),
        xl.TextCellValue("Tanggal"),
        xl.TextCellValue("Waktu"),
        xl.TextCellValue("Tipe"),
        xl.TextCellValue("Kategori"),
        xl.TextCellValue("Akun / Dompet"),
        xl.TextCellValue("Nominal (Rp)"),
        xl.TextCellValue("Catatan"),
      ];
      sheetObject.appendRow(headers);

      // Header styling
      final headerStyle = xl.CellStyle(
        bold: true,
        horizontalAlign: xl.HorizontalAlign.Center,
        backgroundColorHex: xl.ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );

      for (int col = 0; col < headers.length; col++) {
        var cell = sheetObject.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = headerStyle;
      }

      // Add data rows
      for (int i = 0; i < transaksi.length; i++) {
        final t = transaksi[i];
        final rowIdx = i + 1;

        final dateStr = "${t.tanggal.day}/${t.tanggal.month}/${t.tanggal.year}";
        final timeStr =
            "${t.tanggal.hour.toString().padLeft(2, '0')}:${t.tanggal.minute.toString().padLeft(2, '0')}";

        sheetObject.appendRow([
          xl.IntCellValue(rowIdx),
          xl.TextCellValue(dateStr),
          xl.TextCellValue(timeStr),
          xl.TextCellValue(t.tipe),
          xl.TextCellValue(t.kategori),
          xl.TextCellValue(t.akun),
          xl.DoubleCellValue(t.nominal),
          xl.TextCellValue(t.catatan),
        ]);

        // Center index, date, time
        sheetObject
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx),
            )
            .cellStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Center,
        );
        sheetObject
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx),
            )
            .cellStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Center,
        );
        sheetObject
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx),
            )
            .cellStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Center,
        );

        // Color coding for Type
        final typeCell = sheetObject.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx),
        );
        typeCell.cellStyle = xl.CellStyle(
          fontColorHex: xl.ExcelColor.fromHexString(
            t.tipe == "Pengeluaran" ? '#F44336' : '#4CAF50',
          ),
          bold: true,
          horizontalAlign: xl.HorizontalAlign.Center,
        );

        // Right align nominal
        sheetObject
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx),
            )
            .cellStyle = xl.CellStyle(
          horizontalAlign: xl.HorizontalAlign.Right,
        );
      }

      // Save file
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception("Gagal menyimpan data Excel.");
      }

      final directory = await getTemporaryDirectory();
      final String path =
          "${directory.path}/Laporan_Transaksi_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final File file = File(path);
      await file.writeAsBytes(fileBytes);

      // Tutup loading dialog
      if (mounted) Navigator.pop(context);

      // Tampilkan dialog opsi share/open
      if (!mounted) return;
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
                      Icons.description_outlined,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Excel Berhasil Dibuat",
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
                  "Berhasil mengekspor ${transaksi.length} transaksi ke file Excel.",
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
                            XFile(path),
                          ], text: "Laporan Transaksi Dompet Digital");
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
                          final result = await OpenFilex.open(path);
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
      if (mounted) Navigator.pop(context); // Tutup loading dialog jika error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan saat membuat Excel: $e")),
      );
    }
  }

  void _tambahTransaksi() {
    DateTime pilihanTanggal = DateTime.now();
    String akunTujuan = masterAkun.isNotEmpty ? masterAkun.first : '';
    if (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) {
      _pilihanAkun = akunUtama;
    } else if (masterAkun.isNotEmpty) {
      _pilihanAkun = masterAkun.first;
    }
    // akunTujuan default ke akun pertama yang berbeda dari akun sumber
    final akunSelainUtama = masterAkun.where((a) => a != _pilihanAkun).toList();
    akunTujuan = akunSelainUtama.isNotEmpty
        ? akunSelainUtama.first
        : _pilihanAkun;

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

            final isPindahDana = _pilihanKategori == 'Pindah Dana';
            final isPindahDanaKeluar =
                isPindahDana && _pilihanTipe == 'Pengeluaran';
            final isPindahDanaMasuk =
                isPindahDana && _pilihanTipe == 'Pemasukan';

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
                      autofocus: true,
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
                      decoration: InputDecoration(
                        labelText: isPindahDanaKeluar
                            ? "Akun Sumber"
                            : isPindahDanaMasuk
                            ? "Akun Tujuan"
                            : "Simpan/Ambil Dari (Akun)",
                        border: const OutlineInputBorder(),
                      ),
                      items: masterAkun
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => _pilihanAkun = val!),
                    ),
                    // Akun pasangan — tampil jika Pindah Dana
                    if (isPindahDana) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('pasangan_${_pilihanAkun}_$_pilihanTipe'),
                        initialValue: akunTujuan != _pilihanAkun
                            ? akunTujuan
                            : (masterAkun
                                      .where((a) => a != _pilihanAkun)
                                      .isNotEmpty
                                  ? masterAkun
                                        .where((a) => a != _pilihanAkun)
                                        .first
                                  : akunTujuan),
                        decoration: InputDecoration(
                          labelText: isPindahDanaKeluar
                              ? "Akun Tujuan"
                              : "Akun Sumber",
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            isPindahDanaKeluar
                                ? Icons.arrow_forward
                                : Icons.arrow_back,
                            color: Colors.blue,
                          ),
                        ),
                        items: masterAkun
                            .map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => akunTujuan = val!),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPindahDanaKeluar
                            ? "Dana akan masuk ke akun tujuan secara otomatis"
                            : "Dana akan keluar dari akun sumber secara otomatis",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
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
                      final nominal =
                          double.tryParse(
                            _nominalController.text.replaceAll('.', ''),
                          ) ??
                          0;
                      final transferId = DateTime.now().millisecondsSinceEpoch
                          .toString();
                      setState(() {
                        daftarTransaksi.add(
                          Transaksi(
                            id: transferId,
                            nominal: nominal,
                            catatan: _catatanController.text,
                            tipe: _pilihanTipe,
                            kategori: _pilihanKategori,
                            akun: _pilihanAkun,
                            tanggal: pilihanTanggal,
                          ),
                        );
                        // Jika Pindah Dana Keluar: buat transaksi masuk ke akun tujuan
                        if (isPindahDanaKeluar) {
                          daftarTransaksi.add(
                            Transaksi(
                              id: 'transfer_masuk_$transferId',
                              nominal: nominal,
                              catatan: _catatanController.text.isNotEmpty
                                  ? _catatanController.text
                                  : 'Transfer dari $_pilihanAkun',
                              tipe: 'Pemasukan',
                              kategori: 'Pindah Dana',
                              akun: akunTujuan,
                              tanggal: pilihanTanggal,
                            ),
                          );
                        }
                        // Jika Pindah Dana Masuk: buat transaksi keluar dari akun sumber
                        if (isPindahDanaMasuk) {
                          daftarTransaksi.add(
                            Transaksi(
                              id: 'transfer_keluar_$transferId',
                              nominal: nominal,
                              catatan: _catatanController.text.isNotEmpty
                                  ? _catatanController.text
                                  : 'Transfer ke $_pilihanAkun',
                              tipe: 'Pengeluaran',
                              kategori: 'Pindah Dana',
                              akun: akunTujuan,
                              tanggal: pilihanTanggal,
                            ),
                          );
                        }
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

    // Filter data berdasarkan Range Tanggal, Akun, & Hitung Pemasukan, Pengeluaran (Kecuali Pindah Dana)
    double totalPemasukan = 0;
    double totalPengeluaran = 0;

    // Hitung total pengeluaran khusus bulan saat ini untuk warning limit (kecuali Pindah Dana)
    final DateTime nowTime = DateTime.now();
    double pengeluaranBulanIni = 0;
    for (var t in daftarTransaksi) {
      if (t.tipe == "Pengeluaran" &&
          shouldCountInSummary(t) &&
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
      _pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama))
          ? akunUtama
          : masterAkun.first;
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

      if (lolosFilter && shouldCountInSummary(t)) {
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

    String appBarTitle;
    if (_currentIndex == 0) {
      appBarTitle = "Catatan Keuangan Digital";
    } else if (_currentIndex == 1) {
      appBarTitle = "Grafik Keuangan";
    } else if (_currentIndex == 2) {
      appBarTitle = "Utang & Piutang";
    } else {
      appBarTitle = "Portofolio Asset";
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
                  Text("Tipe: ", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text("Akun: ", style: TextStyle(fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),
          if (limitPengeluaran > 0 &&
              pengeluaranBulanIni > limitPengeluaran) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 28,
                  ),
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHideSaldoGlobal
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
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      Column(
                        children: [
                          const Text(
                            "Pengeluaran",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHideSaldoGlobal
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
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(categoryDetail.ikon, color: color, size: 24),
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
        actions: [
          if (_currentIndex == 0 || _currentIndex == 3) ...[
            IconButton(
              icon: Icon(
                isHideSaldoGlobal
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: isHideSaldoGlobal
                  ? "Tampilkan Saldo"
                  : "Sembunyikan Saldo",
              onPressed: () {
                setState(() {
                  isHideSaldoGlobal = !isHideSaldoGlobal;
                });
                saveData();
              },
            ),
          ],
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "Ekspor Excel",
              onPressed: () => _exportToExcel(riwayatTerfilter),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Pengaturan",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              setState(() {});
            },
          ),
        ],
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
          KeepAliveWrapper(child: GrafikScreen()),
          KeepAliveWrapper(child: UtangScreen()),
          KeepAliveWrapper(child: AssetScreen()),
        ],
      ),
      floatingActionButton: (_currentIndex == 0)
          ? FloatingActionButton(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              onPressed: () {
                if (_currentIndex == 0) {
                  _tambahTransaksi();
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

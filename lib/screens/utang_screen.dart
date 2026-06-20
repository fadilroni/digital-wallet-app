import 'package:flutter/material.dart';
import '../data_model.dart';

class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key});

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _dariController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Total hutang saya (kita berutang ke orang lain - saldo negatif)
  double get _totalUtangSaya {
    double total = 0;
    for (var k in daftarKontakUtang) {
      double s = k.saldo;
      if (s < 0) {
        total += s.abs();
      }
    }
    return total;
  }

  // Total piutang saya (orang lain berutang ke kita - saldo positif)
  double get _totalPiutangSaya {
    double total = 0;
    for (var k in daftarKontakUtang) {
      double s = k.saldo;
      if (s > 0) {
        total += s;
      }
    }
    return total;
  }

  void _tambahUtangPiutang() {
    _nominalController.clear();
    _catatanController.clear();
    _dariController.clear();
    String pilihanTipe = "Piutang";
    DateTime pilihanTanggal = DateTime.now();
    String pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) ? akunUtama : (masterAkun.isNotEmpty ? masterAkun.first : "Tunai");

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  Text("Tambah Hutang/Piutang"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _dariController,
                      decoration: const InputDecoration(
                        labelText: "Dari/Kepada (Nama)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: "Jumlah (Rp)",
                        border: OutlineInputBorder(),
                        prefixText: "Rp ",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _catatanController,
                      decoration: const InputDecoration(
                        labelText: "Catatan",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: pilihanTipe,
                      decoration: const InputDecoration(
                        labelText: "Tipe",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Piutang",
                          child: Text("Piutang (orang lain berhutang ke saya)"),
                        ),
                        DropdownMenuItem(
                          value: "Hutang",
                          child: Text("Hutang (saya berhutang ke orang lain)"),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => pilihanTipe = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: pilihanAkun,
                      decoration: const InputDecoration(
                        labelText: "Akun",
                        border: OutlineInputBorder(),
                      ),
                      items: masterAkun.map((String akun) {
                        return DropdownMenuItem<String>(
                          value: akun,
                          child: Text(akun),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => pilihanAkun = val!),
                    ),
                    const SizedBox(height: 12),
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
                                    picked.year, picked.month, picked.day,
                                    pilihanTanggal.hour, pilihanTanggal.minute,
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nama = _dariController.text.trim();
                    final nominalStr =
                        _nominalController.text.replaceAll('.', '');
                    final nominal = double.tryParse(nominalStr) ?? 0;
                    if (nama.isEmpty || nominal <= 0) return;

                    setState(() {
                      // Cari kontak yang sudah ada, atau buat baru
                      KontakUtang? kontak;
                      for (var k in daftarKontakUtang) {
                        if (k.nama.toLowerCase() == nama.toLowerCase()) {
                          kontak = k;
                          break;
                        }
                      }
                      if (kontak == null) {
                        kontak = KontakUtang(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          nama: nama,
                          telepon: "",
                          tanggalDibuat: pilihanTanggal,
                          transaksi: [],
                        );
                        daftarKontakUtang.add(kontak);
                      }
                      final tx = TransaksiUtang(
                        id: DateTime.now().millisecondsSinceEpoch.toString() + "_tx",
                        nominal: nominal,
                        tipe: pilihanTipe,
                        catatan: _catatanController.text,
                        tanggal: pilihanTanggal,
                        akun: pilihanAkun,
                      );
                      kontak.transaksi.add(tx);
                      syncTransaksiUtangToMainList(kontak, tx);
                    });
                    saveData();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Simpan"),
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
    // Urutkan: yang punya saldo > 0 di atas, lalu abjad
    final sorted = List<KontakUtang>.from(daftarKontakUtang);
    sorted.sort((a, b) {
      final sa = a.saldo.abs();
      final sb = b.saldo.abs();
      if (sa > 0 && sb == 0) return -1;
      if (sa == 0 && sb > 0) return 1;
      return a.nama.toLowerCase().compareTo(b.nama.toLowerCase());
    });

    final filtered = sorted.where((item) {
      return item.nama.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Header Card showing totals — selalu tampil
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Total Utang Saya
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Utang Saya",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Rp ${formatRibuan(_totalUtangSaya)}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(width: 16),
                          // Total Piutang Saya
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Piutang Saya",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Rp ${formatRibuan(_totalPiutangSaya)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Cari nama kontak...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = "";
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                "Tidak menemukan kontak \"$_searchQuery\"",
                                style: TextStyle(color: Colors.grey[500], fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80, top: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final saldo = item.saldo;
                            final lunas = saldo == 0;
                            final isPiutang = saldo > 0;
                            final inisial =
                                item.nama.isNotEmpty ? item.nama[0].toUpperCase() : "?";

                            // Tanggal transaksi terakhir
                            String lastTgl = "-";
                            if (item.transaksi.isNotEmpty) {
                              final last = item.transaksi
                                  .reduce((a, b) => a.tanggal.isAfter(b.tanggal) ? a : b);
                              lastTgl =
                                  "${last.tanggal.day.toString().padLeft(2, '0')}/"
                                  "${last.tanggal.month.toString().padLeft(2, '0')}/"
                                  "${last.tanggal.year}";
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _DetailUtangScreen(
                                        kontak: item,
                                        onChanged: () => setState(() {}),
                                      ),
                                    ),
                                  );
                                  setState(() {});
                                },
                                leading: CircleAvatar(
                                  backgroundColor: lunas
                                      ? Colors.grey[200]
                                      : isPiutang
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.red.withValues(alpha: 0.12),
                                  child: Text(
                                    inisial,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: lunas
                                          ? Colors.grey
                                          : isPiutang
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                    ),
                                  ),
                                ),
                                title: Text(item.nama,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("Terakhir: $lastTgl",
                                    style: const TextStyle(fontSize: 12)),
                                trailing: lunas
                                    ? const Text("LUNAS",
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold))
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "Rp ${formatRibuan(saldo.abs())}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isPiutang
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isPiutang ? "Piutang" : "Hutang",
                                            style: TextStyle(
                                                fontSize: 11, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tambahUtangPiutang,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Detail Ledger ────────────────────────────────────────────────────────────
class _DetailUtangScreen extends StatefulWidget {
  final KontakUtang kontak;
  final VoidCallback onChanged;
  const _DetailUtangScreen({required this.kontak, required this.onChanged});

  @override
  State<_DetailUtangScreen> createState() => _DetailUtangScreenState();
}

class _DetailUtangScreenState extends State<_DetailUtangScreen> {
  final TextEditingController _nominalCtrl = TextEditingController();
  final TextEditingController _catatanCtrl = TextEditingController();

  void _tambahTransaksi(String tipe) {
    _nominalCtrl.clear();
    _catatanCtrl.clear();
    DateTime tgl = DateTime.now();
    String pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) ? akunUtama : (masterAkun.isNotEmpty ? masterAkun.first : "Tunai");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          String tglStr =
              "${tgl.day.toString().padLeft(2, '0')}/"
              "${tgl.month.toString().padLeft(2, '0')}/${tgl.year}";
          String jamStr =
              "${tgl.hour.toString().padLeft(2, '0')}:"
              "${tgl.minute.toString().padLeft(2, '0')}";

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  tipe == "Piutang"
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: tipe == "Piutang" ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(tipe == "Piutang" ? "Tambah Piutang" : "Tambah Hutang"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RibuanInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: "Jumlah (Rp)",
                      border: OutlineInputBorder(),
                      prefixText: "Rp ",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _catatanCtrl,
                    decoration: const InputDecoration(
                      labelText: "Catatan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pilihanAkun,
                    decoration: const InputDecoration(
                      labelText: "Akun",
                      border: OutlineInputBorder(),
                    ),
                    items: masterAkun.map((akun) => DropdownMenuItem(
                      value: akun, child: Text(akun))).toList(),
                    onChanged: (val) => set(() => pilihanAkun = val!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(tglStr),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tgl,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              set(() {
                                tgl = DateTime(picked.year, picked.month,
                                    picked.day, tgl.hour, tgl.minute);
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
                              context: ctx,
                              initialTime:
                                  TimeOfDay(hour: tgl.hour, minute: tgl.minute),
                            );
                            if (picked != null) {
                              set(() {
                                tgl = DateTime(tgl.year, tgl.month, tgl.day,
                                    picked.hour, picked.minute);
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
                  onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
              ElevatedButton(
                onPressed: () {
                  final nominal = double.tryParse(
                          _nominalCtrl.text.replaceAll('.', '')) ?? 0;
                  if (nominal <= 0) return;
                  final tx = TransaksiUtang(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nominal: nominal,
                    tipe: tipe,
                    catatan: _catatanCtrl.text,
                    tanggal: tgl,
                    akun: pilihanAkun,
                  );
                  setState(() {
                    widget.kontak.transaksi.add(tx);
                  });
                  syncTransaksiUtangToMainList(widget.kontak, tx);
                  saveData();
                  widget.onChanged();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      tipe == "Piutang" ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _lunaskan() {
    final saldo = widget.kontak.saldo;
    if (saldo == 0) return;
    final isPiutang = saldo > 0;
    String pilihanAkun = (akunUtama.isNotEmpty && masterAkun.contains(akunUtama)) ? akunUtama : (masterAkun.isNotEmpty ? masterAkun.first : "Tunai");
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text("Lunaskan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Tandai ${widget.kontak.nama} sebagai LUNAS?\nJumlah: Rp ${formatRibuan(saldo.abs())}"),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: pilihanAkun,
                decoration: const InputDecoration(
                  labelText: "Akun Pelunasan",
                  border: OutlineInputBorder(),
                ),
                items: masterAkun.map((akun) => DropdownMenuItem(
                  value: akun, child: Text(akun))).toList(),
                onChanged: (val) => set(() => pilihanAkun = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                final tx = TransaksiUtang(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  nominal: saldo.abs(),
                  tipe: isPiutang ? "Hutang" : "Piutang",
                  catatan: "Pelunasan",
                  tanggal: DateTime.now(),
                  akun: pilihanAkun,
                );
                setState(() {
                  widget.kontak.transaksi.add(tx);
                });
                syncTransaksiUtangToMainList(widget.kontak, tx);
                saveData();
                widget.onChanged();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Lunaskan"),
            ),
          ],
        ),
      ),
    );
  }

  void _hapusKontak() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kontak"),
        content: Text(
            "Hapus '${widget.kontak.nama}' beserta seluruh riwayat hutang/piutang?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              for (var tx in widget.kontak.transaksi) {
                removeTransaksiUtangFromMainList(tx.id);
              }
              daftarKontakUtang.removeWhere((k) => k.id == widget.kontak.id);
              saveData();
              widget.onChanged();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  void _editNamaKontak() {
    final TextEditingController nameCtrl = TextEditingController(text: widget.kontak.nama);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Nama Kontak"),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: "Nama Kontak",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  widget.kontak.nama = newName;
                });
                saveData();
                widget.onChanged();
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _showDetailTransaksiUtang(TransaksiUtang tx) {
    final isPiutang = tx.tipe == "Piutang";
    final color = isPiutang ? Colors.green : Colors.red;

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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      isPiutang ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPiutang ? "Piutang" : "Hutang",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx.tipe,
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
                    "Rp ${formatRibuan(tx.nominal)}",
                    style: TextStyle(
                      color: color[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              if (tx.catatan.isNotEmpty)
                _detailRow(Icons.notes_outlined, "Catatan", tx.catatan),
              _detailRow(
                Icons.calendar_today_outlined,
                "Tanggal",
                "${tx.tanggal.day.toString().padLeft(2, '0')}/${tx.tanggal.month.toString().padLeft(2, '0')}/${tx.tanggal.year}, "
                "${tx.tanggal.hour.toString().padLeft(2, '0')}:${tx.tanggal.minute.toString().padLeft(2, '0')}",
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text("Hapus", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _hapusTransaksiUtang(tx);
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
                        _editTransaksiUtang(tx);
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
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
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

  void _hapusTransaksiUtang(TransaksiUtang tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Transaksi"),
        content: const Text("Hapus transaksi ini dari riwayat?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.kontak.transaksi.removeWhere((t) => t.id == tx.id);
              });
              removeTransaksiUtangFromMainList(tx.id);
              saveData();
              widget.onChanged();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  void _editTransaksiUtang(TransaksiUtang tx) {
    final TextEditingController nominalCtrl = TextEditingController(text: formatRibuan(tx.nominal));
    final TextEditingController catatanCtrl = TextEditingController(text: tx.catatan);
    String editTipe = tx.tipe;
    String editAkun = tx.akun.isNotEmpty ? tx.akun : (masterAkun.isNotEmpty ? masterAkun.first : "Tunai");
    DateTime tgl = tx.tanggal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          String tglStr =
              "${tgl.day.toString().padLeft(2, '0')}/"
              "${tgl.month.toString().padLeft(2, '0')}/${tgl.year}";
          String jamStr =
              "${tgl.hour.toString().padLeft(2, '0')}:"
              "${tgl.minute.toString().padLeft(2, '0')}";

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text("Edit Transaksi"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RibuanInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: "Jumlah (Rp)",
                      border: OutlineInputBorder(),
                      prefixText: "Rp ",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: catatanCtrl,
                    decoration: const InputDecoration(
                      labelText: "Catatan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: editTipe,
                    decoration: const InputDecoration(
                      labelText: "Tipe",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Piutang", child: Text("Piutang")),
                      DropdownMenuItem(value: "Hutang", child: Text("Hutang")),
                    ],
                    onChanged: (val) => set(() => editTipe = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: editAkun,
                    decoration: const InputDecoration(
                      labelText: "Akun",
                      border: OutlineInputBorder(),
                    ),
                    items: masterAkun.map((akun) => DropdownMenuItem(
                      value: akun, child: Text(akun))).toList(),
                    onChanged: (val) => set(() => editAkun = val!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(tglStr),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tgl,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              set(() {
                                tgl = DateTime(picked.year, picked.month,
                                    picked.day, tgl.hour, tgl.minute);
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
                              context: ctx,
                              initialTime:
                                  TimeOfDay(hour: tgl.hour, minute: tgl.minute),
                            );
                            if (picked != null) {
                              set(() {
                                tgl = DateTime(tgl.year, tgl.month, tgl.day,
                                    picked.hour, picked.minute);
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () {
                  final nominal = double.tryParse(
                          nominalCtrl.text.replaceAll('.', '')) ?? 0;
                  if (nominal <= 0) return;
                  setState(() {
                    tx.nominal = nominal;
                    tx.catatan = catatanCtrl.text;
                    tx.tipe = editTipe;
                    tx.akun = editAkun;
                    tx.tanggal = tgl;
                  });
                  syncTransaksiUtangToMainList(widget.kontak, tx);
                  saveData();
                  widget.onChanged();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = widget.kontak.saldo;
    final lunas = saldo == 0;
    final isPiutang = saldo > 0;

    final listTx = List<TransaksiUtang>.from(widget.kontak.transaksi)
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kontak.nama),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editNamaKontak,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _hapusKontak,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Ringkasan Saldo ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lunas
                              ? "Status"
                              : isPiutang
                                  ? "Piutang (mereka berhutang)"
                                  : "Hutang (saya berhutang)",
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lunas
                              ? "LUNAS"
                              : "Rp ${formatRibuan(saldo.abs())}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: lunas
                                ? Colors.green
                                : isPiutang
                                    ? Colors.green[700]
                                    : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    if (!lunas)
                      ElevatedButton(
                        onPressed: _lunaskan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("LUNASKAN"),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Header Kolom ─────────────────────────────────────────────────
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text("TANGGAL",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey))),
                Expanded(
                    flex: 2,
                    child: Text("PIUTANG",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.green))),
                Expanded(
                    flex: 2,
                    child: Text("HUTANG",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.red))),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List Transaksi ───────────────────────────────────────────────
          Expanded(
            child: listTx.isEmpty
                ? const Center(child: Text("Belum ada riwayat transaksi."))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: listTx.length,
                    separatorBuilder: (ctx2, idx) =>
                        Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (_, i) {
                      final tx = listTx[i];
                      final tglStr =
                          "${tx.tanggal.day.toString().padLeft(2, '0')}/"
                          "${tx.tanggal.month.toString().padLeft(2, '0')}/"
                          "${tx.tanggal.year}  "
                          "${tx.tanggal.hour.toString().padLeft(2, '0')}:"
                          "${tx.tanggal.minute.toString().padLeft(2, '0')}";
                      final isPiutangTx = tx.tipe == "Piutang";

                      return InkWell(
                        onTap: () => _showDetailTransaksiUtang(tx),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tglStr,
                                        style: const TextStyle(fontSize: 12)),
                                    if (tx.catatan.isNotEmpty)
                                      Text(tx.catatan,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: isPiutangTx
                                    ? Text(
                                        "Rp ${formatRibuan(tx.nominal)}",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                    )
                                    : const SizedBox(),
                              ),
                              Expanded(
                                flex: 2,
                                child: !isPiutangTx
                                    ? Text(
                                        "Rp ${formatRibuan(tx.nominal)}",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                    )
                                    : const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── Bottom action buttons ────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tambahTransaksi("Piutang"),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("PIUTANG",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tambahTransaksi("Hutang"),
                  icon: const Icon(Icons.remove, color: Colors.white),
                  label: const Text("HUTANG",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

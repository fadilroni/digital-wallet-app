import 'package:flutter/material.dart';
import '../data_model.dart';

String getNamaIkon(IconData ikon) {
  if (ikon == Icons.fastfood) return "Makanan / Minuman";
  if (ikon == Icons.directions_car) return "Transportasi";
  if (ikon == Icons.shopping_bag) return "Belanja";
  if (ikon == Icons.receipt_long) return "Tagihan / Biaya";
  if (ikon == Icons.payments) return "Gaji / Pendapatan";
  if (ikon == Icons.card_giftcard) return "Hadiah / Pemberian";
  if (ikon == Icons.trending_up) return "Investasi / Bonus";
  if (ikon == Icons.category) return "Kategori Lain";
  if (ikon == Icons.assignment_return) return "Reimburse";
  if (ikon == Icons.home) return "Kebutuhan Rumah";
  if (ikon == Icons.bolt) return "Listrik / Utilitas";
  if (ikon == Icons.medical_services) return "Kesehatan / Medis";
  if (ikon == Icons.smoking_rooms) return "Rokok / Vape";
  return "Lainnya";
}

class KategoriScreen extends StatefulWidget {
  /// Dipanggil setiap kali tab berubah, mengirimkan tipe aktif ("Pengeluaran" / "Pemasukan")
  final void Function(String tipe)? onTabChanged;

  const KategoriScreen({super.key, this.onTabChanged});

  @override
  _KategoriScreenState createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ["Pengeluaran", "Pemasukan"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      // Hanya trigger saat animasi selesai (bukan saat animasi berjalan)
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged?.call(_tabs[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editKategori(KategoriModel item) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController namaEditController = TextEditingController(
          text: item.nama,
        );
        String editTipe = item.tipe;
        IconData editIkon = item.ikon;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Edit Kategori"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: namaEditController,
                      decoration: const InputDecoration(
                        labelText: "Nama Kategori",
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
                      items: _tabs
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) => setDialogState(() => editTipe = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IconData>(
                      initialValue: editIkon,
                      decoration: const InputDecoration(
                        labelText: "Pilih Logo Kategori",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: daftarPilihanIkon.map((IconData ikon) {
                        return DropdownMenuItem<IconData>(
                          value: ikon,
                          child: Row(
                            children: [
                              Icon(ikon, color: Colors.green),
                              const SizedBox(width: 12),
                              Text(getNamaIkon(ikon)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => editIkon = val!),
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
                    if (namaEditController.text.isNotEmpty) {
                      String oldNama = item.nama;
                      String oldTipe = item.tipe;
                      String newNama = namaEditController.text;

                      setState(() {
                        item.nama = newNama;
                        item.tipe = editTipe;
                        item.ikon = editIkon;
                        // Update transaksi yang memakai kategori ini
                        for (var t in daftarTransaksi) {
                          if (t.kategori == oldNama && t.tipe == oldTipe) {
                            t.kategori = newNama;
                            t.tipe = editTipe;
                          }
                        }
                      });
                      saveData();
                      Navigator.pop(context);
                    }
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

  void _hapusKategori(KategoriModel item) {
    int countTipe = masterKategori.where((k) => k.tipe == item.tipe).length;
    if (countTipe <= 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Tidak Dapat Menghapus"),
          content: Text(
            "Minimal harus ada 1 kategori untuk tipe ${item.tipe}.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Kategori"),
        content: Text(
          "Apakah Anda yakin ingin menghapus kategori '${item.nama}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => masterKategori.remove(item));
              saveData();
              Navigator.pop(context);
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

  /// Menampilkan detail kategori dalam popup bottom sheet
  void _showDetailKategori(
    KategoriModel item,
    Color bgColor,
    Color accentColor,
  ) {
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
              // Icon + nama
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: bgColor,
                    child: Icon(item.ikon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.tipe,
                            style: TextStyle(
                              color: accentColor == Colors.redAccent
                                  ? Colors.red[700]
                                  : Colors.green[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.label_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 10),
                  Text(
                    "Nama: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    item.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.swap_vert_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Tipe: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    item.tipe,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
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
                        _hapusKategori(item);
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
                        _editKategori(item);
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

  void _onReorder(String tipe, int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final targetList = masterKategori.where((k) => k.tipe == tipe).toList();
      final otherList = masterKategori.where((k) => k.tipe != tipe).toList();

      final item = targetList.removeAt(oldIndex);
      targetList.insert(newIndex, item);

      masterKategori = [...otherList, ...targetList];
    });
    saveData();
  }

  /// Membangun daftar kategori untuk satu tipe tertentu
  Widget _buildList(String tipe) {
    final list = masterKategori.where((k) => k.tipe == tipe).toList();
    final isPengeluaran = tipe == "Pengeluaran";
    final accentColor = isPengeluaran ? Colors.redAccent : Colors.greenAccent;
    final bgColor = isPengeluaran ? Colors.red.shade900 : Colors.green.shade900;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[500]),
            const SizedBox(height: 10),
            Text(
              "Belum ada kategori $tipe.\nTekan tombol \"+\" untuk menambah.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: list.length,
      onReorder: (oldIdx, newIdx) => _onReorder(tipe, oldIdx, newIdx),
      itemBuilder: (context, index) {
        final item = list[index];
        return Card(
          key: ValueKey(item.nama),
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            onTap: () => _showDetailKategori(item, bgColor, accentColor),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: bgColor,
                  child: Icon(item.ikon, color: Colors.white),
                ),
              ],
            ),
            title: Text(
              item.nama,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        );
      },
    );
  }

  void _tambahKategori() {
    final TextEditingController namaController = TextEditingController();
    String tipeBaru = _tabController.index == 0 ? 'Pengeluaran' : 'Pemasukan';
    IconData ikonBaru = Icons.category;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Kategori'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tipeBaru,
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    items: _tabs
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => tipeBaru = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IconData>(
                    value: ikonBaru,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Logo',
                      border: OutlineInputBorder(),
                    ),
                    items: daftarPilihanIkon.map((ikon) {
                      return DropdownMenuItem<IconData>(
                        value: ikon,
                        child: Row(
                          children: [
                            Icon(ikon, color: Colors.green),
                            const SizedBox(width: 12),
                            Text(getNamaIkon(ikon)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => ikonBaru = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nama = namaController.text.trim();
                    if (nama.isEmpty) return;

                    setState(() {
                      masterKategori.add(
                        KategoriModel(
                          nama: nama,
                          tipe: tipeBaru,
                          ikon: ikonBaru,
                        ),
                      );
                    });
                    saveData();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahKategori,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ===== TAB BAR =====
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_downward, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Pengeluaran (${masterKategori.where((k) => k.tipe == "Pengeluaran").length})",
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Pemasukan (${masterKategori.where((k) => k.tipe == "Pemasukan").length})",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),

          // ===== TAB VIEW =====
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildList("Pengeluaran"), _buildList("Pemasukan")],
            ),
          ),
        ],
      ),
    );
  }
}

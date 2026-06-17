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
  if (ikon == Icons.home) return "Kebutuhan Rumah";
  if (ikon == Icons.bolt) return "Listrik / Utilitas";
  if (ikon == Icons.medical_services) return "Kesehatan / Medis";
  return "Lainnya";
}

class KategoriScreen extends StatefulWidget {
  const KategoriScreen({super.key});

  @override
  _KategoriScreenState createState() => _KategoriScreenState();
}

class _KategoriScreenState extends State<KategoriScreen> {
  final TextEditingController _kategoriController = TextEditingController();
  String _tipeKategoriBaru = "Pengeluaran";
  IconData _ikonTerpilih = daftarPilihanIkon.first; // Default logo pertama

  void _editKategori(KategoriModel item) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController namaEditController =
            TextEditingController(text: item.nama);
        String editTipe = item.tipe;
        IconData editIkon = item.ikon;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit Kategori"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: namaEditController,
                      decoration: InputDecoration(
                        labelText: "Nama Kategori",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          "Tipe: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 10),
                        DropdownButton<String>(
                          value: editTipe,
                          items: ["Pengeluaran", "Pemasukan"].map((String val) {
                            return DropdownMenuItem<String>(
                                value: val, child: Text(val));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              editTipe = val!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<IconData>(
                      initialValue: editIkon,
                      decoration: const InputDecoration(
                        labelText: "Pilih Logo Kategori",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      onChanged: (IconData? val) {
                        setDialogState(() {
                          editIkon = val!;
                        });
                      },
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
                  child: Text("Simpan"),
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
          title: Text("Tidak Dapat Menghapus"),
          content: Text("Minimal harus ada 1 kategori untuk tipe ${item.tipe}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Hapus Kategori"),
          content: Text("Apakah Anda yakin ingin menghapus kategori '${item.nama}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  masterKategori.remove(item);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. INPUT NAMA KATEGORI
          TextField(
            controller: _kategoriController,
            decoration: InputDecoration(
              labelText: "Nama Kategori Baru",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),

          // 2. PILIHAN TIPE (PENGELUARAN / PEMASUKAN)
          Row(
            children: [
              Text(
                "Tipe Kategori: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 10),
              DropdownButton<String>(
                value: _tipeKategoriBaru,
                items: ["Pengeluaran", "Pemasukan"].map((String val) {
                  return DropdownMenuItem<String>(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) => setState(() => _tipeKategoriBaru = val!),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // 3. PILIHAN LOGO / IKON (Dropdown)
          DropdownButtonFormField<IconData>(
            initialValue: _ikonTerpilih,
            decoration: const InputDecoration(
              labelText: "Pilih Logo Kategori",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            onChanged: (IconData? val) {
              setState(() {
                _ikonTerpilih = val!;
              });
            },
          ),
          const SizedBox(height: 15),

          // 4. TOMBOL SIMPAN
          ElevatedButton(
            onPressed: () {
              if (_kategoriController.text.isNotEmpty) {
                setState(() {
                  masterKategori.add(
                    KategoriModel(
                      nama: _kategoriController.text,
                      tipe: _tipeKategoriBaru,
                      ikon: _ikonTerpilih,
                    ),
                  );
                  saveData();
                  _kategoriController.clear();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text("Simpan Kategori"),
          ),
          Divider(height: 30, color: Colors.grey),

          // 5. DAFTAR SEMUA KATEGORI DALAM SATU LIST
          Text(
            "Daftar Kategori Saat Ini:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: masterKategori.length,
              itemBuilder: (context, index) {
                final item = masterKategori[index];
                bool isPengeluaran = item.tipe == "Pengeluaran";

                return Card(
                  child: ListTile(
                    // Menampilkan Logo Ikon yang dipilih
                    leading: CircleAvatar(
                      backgroundColor: isPengeluaran
                          ? Colors.red.shade900
                          : Colors.green.shade900,
                      child: Icon(item.ikon, color: Colors.white),
                    ),
                    title: Text(item.nama),
                    // Label Pembeda Tipe & tombol Aksi di sebelah kanan
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPengeluaran
                                ? Colors.red.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            item.tipe,
                            style: TextStyle(
                              color: isPengeluaran
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => _editKategori(item),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => _hapusKategori(item),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../data_model.dart';
import '../bank_notif_service.dart';

class AkunScreen extends StatefulWidget {
  const AkunScreen({super.key});

  @override
  _AkunScreenState createState() => _AkunScreenState();
}

class _AkunScreenState extends State<AkunScreen> {
  /// Hitung saldo bersih untuk satu akun (Pemasukan - Pengeluaran)
  double _hitungSaldo(String namaAkun) {
    double saldo = saldoAwalMap[namaAkun] ?? 0.0;
    for (var t in daftarTransaksi) {
      if (t.akun == namaAkun) {
        if (t.tipe == "Pemasukan") {
          saldo += t.nominal;
        } else {
          saldo -= t.nominal;
        }
      }
    }
    return saldo;
  }

  String _getBankDisplayName(String? bankKey) {
    if (bankKey == null || bankKey.isEmpty) return "Tidak Terhubung";
    for (var b in BankNotifService.knownBanks) {
      if (b.id == bankKey) return b.name;
    }
    return bankKey;
  }

  Future<String?> _pilihAplikasiDiHp() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        withIcon: true,
      );
      if (!mounted) return null;
      return await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text("Pilih Aplikasi di HP"),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: apps.isEmpty
                  ? const Center(child: Text("Tidak ada aplikasi pihak ketiga ditemukan"))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: apps.length,
                      itemBuilder: (context, i) {
                        final app = apps[i];
                        return ListTile(
                          leading: app.icon != null
                              ? Image.memory(app.icon!, width: 36, height: 36)
                              : const Icon(Icons.apps),
                          title: Text(app.name ?? ''),
                          subtitle: Text(
                            app.packageName ?? '',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(ctx, app.packageName);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Tutup"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Gagal mengambil aplikasi terinstall: $e");
      return null;
    }
  }

  void _showDetailAkun(int index) {
    final namaAkun = masterAkun[index];
    final saldo = _hitungSaldo(namaAkun);
    final isPositif = saldo >= 0;

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
              // Icon + nama akun
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      namaAkun,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              // Saldo
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Saldo: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    "Rp ${formatRibuan(saldo.abs())}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isPositif ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  if (!isPositif)
                    Text(
                      " (minus)",
                      style: TextStyle(color: Colors.red[400], fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Jumlah transaksi
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Transaksi: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    "${daftarTransaksi.where((t) => t.akun == namaAkun).length} transaksi",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Akun Utama
              Row(
                children: [
                  Icon(
                    namaAkun == akunUtama ? Icons.star : Icons.star_border,
                    size: 18,
                    color: namaAkun == akunUtama
                        ? Colors.amber[700]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Akun Utama: ",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    namaAkun == akunUtama ? "Ya" : "Tidak",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: namaAkun == akunUtama
                          ? Colors.amber[800]
                          : Colors.grey[800],
                    ),
                  ),
                  if (namaAkun != akunUtama) ...[
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      label: const Text(
                        "Set Utama",
                        style: TextStyle(color: Colors.amber),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          akunUtama = namaAkun;
                        });
                        saveData();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ],
              ),
              if (notifBankAutoRecordEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      bankAccountMapping.containsKey(namaAkun)
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: 18,
                      color: bankAccountMapping.containsKey(namaAkun)
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Notifikasi Bank: ",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Expanded(
                      child: Text(
                        _getBankDisplayName(bankAccountMapping[namaAkun]),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: bankAccountMapping.containsKey(namaAkun)
                              ? Colors.green[700]
                              : Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
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
                        _hapusAkun(index);
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
                        _editAkun(index);
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

  void _editAkun(int index) {
    final String oldNama = masterAkun[index];
    final double oldSaldoAwal = saldoAwalMap[oldNama] ?? 0.0;
    String selectedBankId = bankAccountMapping[oldNama] ?? "";

    final TextEditingController editController = TextEditingController(
      text: oldNama,
    );
    final TextEditingController saldoAwalController = TextEditingController(
      text: oldSaldoAwal > 0 ? formatRibuan(oldSaldoAwal) : "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Akun/Dompet"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editController,
                      decoration: const InputDecoration(
                        labelText: "Nama Akun/Dompet",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: saldoAwalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: "Saldo Awal (Rp)",
                        prefixText: "Rp ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (notifBankAutoRecordEnabled) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedBankId.isEmpty ? "" : (BankNotifService.knownBanks.any((b) => b.id == selectedBankId) ? selectedBankId : "__custom_selected__"),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Hubungkan Notifikasi Bank",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notifications_active_outlined, color: Colors.blue),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: "",
                            child: Text("Tidak Terhubung (Manual)"),
                          ),
                          ...BankNotifService.knownBanks.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          )),
                          if (selectedBankId.isNotEmpty && !BankNotifService.knownBanks.any((b) => b.id == selectedBankId))
                            DropdownMenuItem(
                              value: "__custom_selected__",
                              child: Text("Aplikasi: $selectedBankId", overflow: TextOverflow.ellipsis),
                            ),
                          const DropdownMenuItem(
                            value: "__custom_picker__",
                            child: Text("➕ Pilih Aplikasi Lain di HP Ini...", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == "__custom_picker__") {
                            final chosenPkg = await _pilihAplikasiDiHp();
                            if (chosenPkg != null) {
                              setDialogState(() {
                                selectedBankId = chosenPkg;
                              });
                            }
                          } else if (val != "__custom_selected__") {
                            setDialogState(() {
                              selectedBankId = val ?? "";
                            });
                          }
                        },
                      ),
                    ],
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
                    if (editController.text.isNotEmpty) {
                      String newNama = editController.text;
                      final String newSaldoAwalStr = saldoAwalController.text
                          .replaceAll('.', '');
                      final double newSaldoAwal =
                          double.tryParse(newSaldoAwalStr) ?? 0.0;

                      setState(() {
                        masterAkun[index] = newNama;
                        if (akunUtama == oldNama) {
                          akunUtama = newNama;
                        }
                        // Update saldoAwalMap
                        saldoAwalMap.remove(oldNama);
                        if (newSaldoAwal > 0) {
                          saldoAwalMap[newNama] = newSaldoAwal;
                        }

                        // Update bankAccountMapping
                        if (oldNama != newNama) {
                          bankAccountMapping.remove(oldNama);
                        }
                        if (selectedBankId.isNotEmpty) {
                          bankAccountMapping[newNama] = selectedBankId;
                        } else {
                          bankAccountMapping.remove(newNama);
                        }

                        // Update transaksi yang memakai akun ini
                        for (var t in daftarTransaksi) {
                          if (t.akun == oldNama) {
                            t.akun = newNama;
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

  void _hapusAkun(int index) {
    if (masterAkun.length <= 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Tidak Dapat Menghapus"),
          content: Text("Minimal harus ada 1 akun/dompet."),
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

    final String oldNama = masterAkun[index];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Hapus Akun/Dompet"),
          content: Text("Apakah Anda yakin ingin menghapus akun '$oldNama'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  masterAkun.removeAt(index);
                  if (akunUtama == oldNama) {
                    akunUtama = masterAkun.first;
                  }
                  // Hapus saldo awal
                  saldoAwalMap.remove(oldNama);
                  bankAccountMapping.remove(oldNama);
                  // Update transaksi yang memakai akun ini ke akun pertama yang tersisa
                  for (var t in daftarTransaksi) {
                    if (t.akun == oldNama) {
                      t.akun = masterAkun.first;
                    }
                  }
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

  void _tambahAkun() {
    final TextEditingController namaController = TextEditingController();
    final TextEditingController saldoAwalController = TextEditingController();
    String selectedBankId = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Akun / Dompet'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Akun / Dompet',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: saldoAwalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Saldo Awal (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (notifBankAutoRecordEnabled) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedBankId.isEmpty ? "" : (BankNotifService.knownBanks.any((b) => b.id == selectedBankId) ? selectedBankId : "__custom_selected__"),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Hubungkan Notifikasi Bank",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notifications_active_outlined, color: Colors.blue),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: "",
                            child: Text("Tidak Terhubung (Manual)"),
                          ),
                          ...BankNotifService.knownBanks.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          )),
                          if (selectedBankId.isNotEmpty && !BankNotifService.knownBanks.any((b) => b.id == selectedBankId))
                            DropdownMenuItem(
                              value: "__custom_selected__",
                              child: Text("Aplikasi: $selectedBankId", overflow: TextOverflow.ellipsis),
                            ),
                          const DropdownMenuItem(
                            value: "__custom_picker__",
                            child: Text("➕ Pilih Aplikasi Lain di HP Ini...", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == "__custom_picker__") {
                            final chosenPkg = await _pilihAplikasiDiHp();
                            if (chosenPkg != null) {
                              setDialogState(() {
                                selectedBankId = chosenPkg;
                              });
                            }
                          } else if (val != "__custom_selected__") {
                            setDialogState(() {
                              selectedBankId = val ?? "";
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
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
                      if (!masterAkun.contains(nama)) {
                        masterAkun.add(nama);
                      }
                      final saldoAwal =
                          double.tryParse(
                            saldoAwalController.text.replaceAll('.', ''),
                          ) ??
                          0.0;
                      if (saldoAwal > 0) {
                        saldoAwalMap[nama] = saldoAwal;
                      }
                      if (akunUtama.isEmpty) {
                        akunUtama = nama;
                      }
                      if (selectedBankId.isNotEmpty) {
                        bankAccountMapping[nama] = selectedBankId;
                      }
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
      appBar: AppBar(title: const Text('Akun / Dompet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahAkun,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Akun'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: masterAkun.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Belum ada akun/dompet.\nTambah akun baru via tombol \"+\" di bawah.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: masterAkun.length,
                      itemBuilder: (c, i) {
                        final akunNama = masterAkun[i];
                        final saldo = _hitungSaldo(akunNama);
                        final isPositif = saldo >= 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            onTap: () => _showDetailAkun(i),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.blue,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  akunNama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (akunNama == akunUtama) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 10,
                                          color: Colors.amber[800],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          "UTAMA",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              "Saldo: Rp ${formatRibuan(saldo.abs())}${!isPositif ? " (minus)" : ""}",
                              style: TextStyle(
                                color: isPositif
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../data_model.dart';
import '../notification_service.dart';

class RecurringReminderScreen extends StatefulWidget {
  const RecurringReminderScreen({super.key});

  @override
  State<RecurringReminderScreen> createState() =>
      _RecurringReminderScreenState();
}

class _RecurringReminderScreenState extends State<RecurringReminderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat Rutin')),
      body: daftarPengingatRutin.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 72, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada pengingat rutin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tambahkan pengingat tagihan atau transfer rutin agar aplikasi dapat mengingatkan Anda setiap kali mencatat transaksi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: daftarPengingatRutin.length,
              itemBuilder: (context, index) {
                final reminder = daftarPengingatRutin[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Icon(
                      Icons.receipt_long,
                      color: reminder.enabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(reminder.title),
                    subtitle: Text(
                      'Rp ${formatRibuan(reminder.nominal)} • ${reminder.recurrenceType} • ${_formatDateReadable(reminder.nextDue)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: reminder.enabled,
                          activeColor: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              reminder.enabled = value;
                              saveData();
                            });
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddEditReminder(reminder);
                            } else if (value == 'delete') {
                              _confirmDeleteReminder(reminder);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _showAddEditReminder(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateReadable(DateTime date) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${bulan[date.month - 1]} ${date.year}';
  }

  void _showAddEditReminder(RecurringReminder? reminder) {
    final isEditing = reminder != null;
    String title = reminder?.title ?? '';
    String kategori =
        reminder?.kategori ??
        (masterKategori.isNotEmpty ? masterKategori.first.nama : 'Tagihan');
    String akun =
        reminder?.akun ?? (masterAkun.isNotEmpty ? masterAkun.first : 'Tunai');
    double nominal = reminder?.nominal ?? 0.0;
    String recurrenceType = reminder?.recurrenceType ?? 'Bulanan';
    int customIntervalDays = reminder?.customIntervalDays ?? 7;
    DateTime nextDue = reminder?.nextDue ?? DateTime.now();
    String note = reminder?.note ?? '';

    final expenseCategories = masterKategori
        .where((k) => k.tipe == 'Pengeluaran')
        .map((k) => k.nama)
        .toList();

    if (!expenseCategories.contains(kategori)) {
      kategori = expenseCategories.isNotEmpty
          ? expenseCategories.first
          : 'Belanja';
    }

    final titleCtrl = TextEditingController(text: title);
    final nominalCtrl = TextEditingController(
      text: nominal > 0 ? formatRibuan(nominal) : '',
    );
    final noteCtrl = TextEditingController(text: note);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, innerSetState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Pengingat' : 'Tambah Pengingat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Judul Pengingat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nominalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        nominal =
                            double.tryParse(val.replaceAll('.', '')) ?? 0.0;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: kategori,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: expenseCategories
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          innerSetState(() {
                            kategori = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: akun,
                      decoration: const InputDecoration(
                        labelText: 'Akun',
                        border: OutlineInputBorder(),
                      ),
                      items: masterAkun
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          innerSetState(() {
                            akun = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: recurrenceType,
                      decoration: const InputDecoration(
                        labelText: 'Frekuensi',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Bulanan', 'Mingguan', 'Harian', 'Custom']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          innerSetState(() {
                            recurrenceType = val;
                          });
                        }
                      },
                    ),
                    if (recurrenceType == 'Custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Interval Hari (Custom)',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                          text: customIntervalDays.toString(),
                        ),
                        onChanged: (val) {
                          customIntervalDays = int.tryParse(val) ?? 7;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.calendar_today,
                        color: Colors.green,
                      ),
                      label: Text(
                        'Tanggal Jatuh Tempo: ${_formatDateReadable(nextDue)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          innerSetState(() {
                            nextDue = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (val) => note = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final enteredTitle = titleCtrl.text.trim();
                    if (enteredTitle.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Judul pengingat wajib diisi.'),
                        ),
                      );
                      return;
                    }

                    final newReminder = RecurringReminder(
                      id:
                          reminder?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: enteredTitle,
                      kategori: kategori,
                      akun: akun,
                      nominal: nominal,
                      recurrenceType: recurrenceType,
                      customIntervalDays: customIntervalDays,
                      nextDue: nextDue,
                      enabled: reminder?.enabled ?? true,
                      note: noteCtrl.text.trim(),
                    );

                    if (isEditing) {
                      final index = daftarPengingatRutin.indexWhere(
                        (r) => r.id == reminder!.id,
                      );
                      if (index >= 0) {
                        daftarPengingatRutin[index] = newReminder;
                      }
                    } else {
                      daftarPengingatRutin.add(newReminder);
                    }
                    saveData();
                    if (enableRecurringReminderGlobal) {
                      await NotificationService.instance.scheduleReminder(
                        newReminder,
                      );
                    }

                    Navigator.pop(dialogCtx);
                    this.setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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

  void _confirmDeleteReminder(RecurringReminder reminder) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Pengingat'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus pengingat ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                setState(() {
                  daftarPengingatRutin.removeWhere((r) => r.id == reminder.id);
                  saveData();
                });
                await NotificationService.instance.cancelReminder(reminder.id);
                Navigator.pop(ctx);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }
}

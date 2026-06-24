import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data_model.dart';

// ─── Warna brand tiap kripto ─────────────────────────────────────────────────
Color _cryptoColor(String symbol) {
  const map = {
    'BTC': Color(0xFFF7931A),
    'ETH': Color(0xFF627EEA),
    'USDT': Color(0xFF26A17B),
    'BNB': Color(0xFFF3BA2F),
    'SOL': Color(0xFF9945FF),
    'XRP': Color(0xFF00AAE4),
    'ADA': Color(0xFF0033AD),
    'DOGE': Color(0xFFC2A633),
    'TRX': Color(0xFFFF060A),
    'POL': Color(0xFF8247E5),
    'DOT': Color(0xFFE6007A),
    'AVAX': Color(0xFFE84142),
    'LINK': Color(0xFF2A5ADA),
    'LTC': Color(0xFF345D9D),
    'SHIB': Color(0xFFFF9900),
    'XLM': Color(0xFF14B6E7),
    'ATOM': Color(0xFF6F4CFF),
    'NEAR': Color(0xFF00C1DE),
    'XAUT': Color(0xFFFFD700),
    'UNI': Color(0xFFFF007A),
    'ARB': Color(0xFF12AAFF),
    'OP': Color(0xFFFF0420),
    'PEPE': Color(0xFF4CAF50),
    'TON': Color(0xFF0098EA),
    'SUI': Color(0xFF4CA3FF),
    'APT': Color(0xFF00D4AA),
    'SAND': Color(0xFF00ADEF),
    'MANA': Color(0xFFFF2D55),
    'FTM': Color(0xFF1969FF),
    'INJ': Color(0xFF00B2FF),
    'SEI': Color(0xFF9E1FFF),
  };
  return map[symbol] ?? Colors.blueGrey;
}

class LivePrice {
  final double last;
  final double buy; // Harga beli di market (ask)
  final double sell; // Harga jual di market (bid)

  LivePrice({required this.last, required this.buy, required this.sell});
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AssetScreen extends StatefulWidget {
  const AssetScreen({super.key});

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  Map<String, LivePrice> _hargaLive = {};
  bool _isLoading = false;
  String? _errorMsg;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchHarga();
    _checkMaturityAndAddInterest();
  }

  // ── Indodax API ──────────────────────────────────────────────────────────
  Future<void> _fetchHarga() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final resp = await http
          .get(Uri.parse('https://indodax.com/api/ticker_all'))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final tickers = data['tickers'] as Map<String, dynamic>;
        final Map<String, LivePrice> harga = {};

        // Parse harga untuk setiap crypto yang dimiliki pengguna
        for (final crypto in cryptoList) {
          final key = '${crypto.symbol.toLowerCase()}_idr';
          if (tickers.containsKey(key)) {
            final ticker = tickers[key] as Map<String, dynamic>;
            final lastVal =
                double.tryParse(ticker['last']?.toString() ?? '') ?? 0.0;
            // Indodax 'buy' = bid/harga jual tertinggi dari buyer
            // Indodax 'sell' = ask/harga beli terendah dari seller
            final buyVal =
                double.tryParse(ticker['buy']?.toString() ?? '') ?? lastVal;
            final sellVal =
                double.tryParse(ticker['sell']?.toString() ?? '') ?? lastVal;

            harga[crypto.symbol] = LivePrice(
              last: lastVal,
              buy: sellVal, // Harga untuk beli (dari orderbook sell)
              sell: buyVal, // Harga untuk jual (dari orderbook buy)
            );
            globalHargaCrypto[crypto.symbol] = lastVal;
          }
        }

        if (mounted) {
          setState(() {
            _hargaLive = harga;
            _isLoading = false;
            _lastUpdated = DateTime.now();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMsg = 'Gagal: HTTP ${resp.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Gagal memuat harga. Periksa koneksi internet.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmt(double v) {
    bool isNegative = v < 0;
    double absValue = v.abs();

    // Pembulatan ke 2 desimal (menggunakan round untuk pembulatan standar terdekat)
    double roundedValue = (absValue * 100).round() / 100.0;

    String valueString = roundedValue.toStringAsFixed(2);
    List<String> parts = valueString.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];

    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formattedInteger = integerPart.replaceAllMapped(
      reg,
      (Match match) => '${match[1]}.',
    );

    String result = '$formattedInteger,$decimalPart';
    return isNegative ? '-$result' : result;
  }

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    // Hapus trailing zero
    return v
        .toString()
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  double _nilaiSekarang(Asset a) {
    if (a.assetType == "deposito") {
      return a.buyPrice;
    }
    final harga = _hargaLive[a.symbol]?.last ?? 0;
    return a.quantity * harga;
  }

  double _modal(Asset a) {
    if (a.assetType == "deposito") {
      return a.buyPrice;
    }
    return a.quantity * a.buyPrice;
  }

  double _pl(Asset a) {
    if (a.assetType == "deposito") {
      return 0.0;
    }
    return _nilaiSekarang(a) - _modal(a);
  }

  double _plPersen(Asset a) {
    if (a.assetType == "deposito") {
      return 0.0;
    }
    final m = _modal(a);
    if (m == 0) return 0;
    return (_pl(a) / m) * 100;
  }

  void _checkMaturityAndAddInterest() {
    bool hasChanges = false;
    final now = DateTime.now();

    for (var a in daftarAsset) {
      if (a.assetType == "deposito" && !(a.isInterestPaid ?? false)) {
        final depositDate = a.depositDate;
        final tenorDays = a.tenor;
        if (depositDate != null && tenorDays != null) {
          final maturityDate = depositDate.add(Duration(days: tenorDays));
          if (now.isAfter(maturityDate)) {
            final nominal = a.buyPrice;
            final bungaPercent = a.interestRate ?? 0.0;

            // Bunga = nominal * (bungaPercent / 100) * (tenorDays / 365)
            double bungaKotor =
                nominal * (bungaPercent / 100.0) * (tenorDays / 365.0);

            // Hitung saldo akun saat ini
            double saldoAkun = saldoAwalMap[a.sourceAccount] ?? 0.0;
            for (var t in daftarTransaksi) {
              if (t.akun == a.sourceAccount) {
                if (t.tipe == "Pemasukan") {
                  saldoAkun += t.nominal;
                } else {
                  saldoAkun -= t.nominal;
                }
              }
            }

            double totalValue = nominal + saldoAkun;
            double bungaBersih = bungaKotor;
            bool isTaxed = false;
            if (totalValue > 7500000) {
              bungaBersih = bungaKotor * 0.8;
              isTaxed = true;
            }

            // Pembulatan ke 2 desimal terdekat
            bungaBersih = (bungaBersih * 100).round() / 100.0;

            if (bungaBersih > 0) {
              final String txId = 'bunga_deposito_${a.id}';
              if (!daftarTransaksi.any((t) => t.id == txId)) {
                daftarTransaksi.add(
                  Transaksi(
                    id: txId,
                    nominal: bungaBersih,
                    catatan:
                        'Bunga Deposito: ${a.name}${isTaxed ? " (Pajak 20%)" : ""}',
                    tipe: 'Pemasukan',
                    kategori: 'Investasi',
                    akun:
                        a.sourceAccount ??
                        (masterAkun.isNotEmpty ? masterAkun.first : "Tunai"),
                    tanggal: maturityDate,
                  ),
                );

                a.isInterestPaid = true;
                hasChanges = true;
              }
            }
          }
        }
      }
    }

    if (hasChanges) {
      saveData();
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ── Dialog Tambah / Edit Asset ───────────────────────────────────────────
  void _showAssetDialog({Asset? existing}) {
    String selectedType = existing != null
        ? (existing.assetType ?? "crypto")
        : "crypto";

    CryptoMaster selectedCrypto = existing != null
        ? cryptoList.firstWhere(
            (c) => c.symbol == existing.symbol,
            orElse: () => cryptoList.first,
          )
        : cryptoList.first;

    final qtyCtrl = TextEditingController(
      text: existing != null ? _fmtQty(existing.quantity) : '',
    );
    final hargaCtrl = TextEditingController(
      text: existing != null ? existing.buyPrice.toStringAsFixed(0) : '',
    );

    // Deposito variables
    final nameCtrl = TextEditingController(
      text: existing != null ? existing.name : '',
    );
    final nominalCtrl = TextEditingController(
      text: existing != null ? existing.buyPrice.toStringAsFixed(0) : '',
    );
    final bungaCtrl = TextEditingController(
      text: existing != null ? (existing.interestRate?.toString() ?? '') : '',
    );

    String selectedTenorOption = "30"; // default
    final customTenorCtrl = TextEditingController();
    if (existing != null && existing.assetType == "deposito") {
      final t = existing.tenor;
      if (t == 7 ||
          t == 14 ||
          t == 21 ||
          t == 30 ||
          t == 90 ||
          t == 180 ||
          t == 365) {
        selectedTenorOption = t.toString();
      } else if (t != null) {
        selectedTenorOption = "Kustom";
        customTenorCtrl.text = t.toString();
      }
    }

    DateTime depositDate = existing != null && existing.depositDate != null
        ? existing.depositDate!
        : DateTime.now();

    String selectedAccount = existing != null && existing.sourceAccount != null
        ? existing.sourceAccount!
        : (masterAkun.contains(akunUtama)
              ? akunUtama
              : (masterAkun.isNotEmpty ? masterAkun.first : ''));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        existing == null
                            ? (selectedType == 'crypto'
                                  ? 'Tambah Aset Kripto'
                                  : 'Tambah Aset Deposito')
                            : 'Edit Aset',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Selector tipe aset (only if existing == null)
                      if (existing == null) ...[
                        const Text(
                          'Tipe Aset',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedType == 'crypto'
                                      ? const Color(0xFF6C63FF)
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white12
                                            : Colors.grey[200]),
                                  foregroundColor: selectedType == 'crypto'
                                      ? Colors.white
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: selectedType == 'crypto' ? 2 : 0,
                                ),
                                onPressed: () =>
                                    setBS(() => selectedType = 'crypto'),
                                child: const Text('Kripto'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedType == 'deposito'
                                      ? const Color(0xFF6C63FF)
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white12
                                            : Colors.grey[200]),
                                  foregroundColor: selectedType == 'deposito'
                                      ? Colors.white
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: selectedType == 'deposito' ? 2 : 0,
                                ),
                                onPressed: () =>
                                    setBS(() => selectedType = 'deposito'),
                                child: const Text('Reksadana / Deposito'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (selectedType == 'crypto') ...[
                        // Pilih Kripto
                        DropdownButtonFormField<CryptoMaster>(
                          initialValue: selectedCrypto,
                          decoration: InputDecoration(
                            labelText: 'Pilih Kripto',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: CircleAvatar(
                              radius: 14,
                              backgroundColor: _cryptoColor(
                                selectedCrypto.symbol,
                              ),
                              child: Text(
                                selectedCrypto.symbol[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          items: cryptoList
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: _cryptoColor(c.symbol),
                                        child: Text(
                                          c.symbol[0],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('${c.symbol} - ${c.name}'),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: existing != null
                              ? null // tidak bisa ganti symbol saat edit
                              : (val) {
                                  if (val != null) {
                                    setBS(() => selectedCrypto = val);
                                  }
                                },
                        ),
                        const SizedBox(height: 14),

                        // Jumlah kepemilikan
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Jumlah (Qty)',
                            hintText: 'cth: 0.005',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.currency_bitcoin),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Harga beli rata-rata
                        TextField(
                          controller: hargaCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Harga Beli Rata-rata (IDR)',
                            hintText: 'cth: 1500000000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixText: 'Rp ',
                          ),
                        ),
                      ] else ...[
                        // Deposito / Reksadana Fields
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nama Aset / Deposito',
                            hintText: 'cth: Deposito Mandiri Syariah',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.account_balance),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: nominalCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RibuanInputFormatter()],
                          decoration: InputDecoration(
                            labelText: 'Nominal Investasi',
                            hintText: 'cth: 10.000.000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixText: 'Rp ',
                            prefixIcon: const Icon(Icons.wallet),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: bungaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Bunga / Imbal Hasil (% per tahun)',
                            hintText: 'cth: 5.5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.percent),
                          ),
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: selectedTenorOption,
                          decoration: InputDecoration(
                            labelText: 'Tenor Deposito',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.timer),
                          ),
                          items: const [
                            DropdownMenuItem(value: '7', child: Text('7 Hari')),
                            DropdownMenuItem(
                              value: '14',
                              child: Text('14 Hari'),
                            ),
                            DropdownMenuItem(
                              value: '21',
                              child: Text('21 Hari'),
                            ),
                            DropdownMenuItem(
                              value: '30',
                              child: Text('1 Bulan'),
                            ),
                            DropdownMenuItem(
                              value: '90',
                              child: Text('3 Bulan'),
                            ),
                            DropdownMenuItem(
                              value: '180',
                              child: Text('6 Bulan'),
                            ),
                            DropdownMenuItem(
                              value: '365',
                              child: Text('1 Tahun'),
                            ),
                            DropdownMenuItem(
                              value: 'Kustom',
                              child: Text('Kustom (Hari)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setBS(() => selectedTenorOption = val);
                            }
                          },
                        ),
                        if (selectedTenorOption == "Kustom") ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: customTenorCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Jumlah Hari Tenor',
                              hintText: 'cth: 60',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.date_range),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  'Tgl Deposito: ${depositDate.day}/${depositDate.month}/${depositDate.year}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: depositDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setBS(() => depositDate = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (existing == null) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedAccount.isNotEmpty
                                ? selectedAccount
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Pilih Akun (Langsung Memotong Saldo)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.account_balance_wallet,
                              ),
                            ),
                            items: masterAkun
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setBS(() => selectedAccount = val);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      const SizedBox(height: 24),

                      // Tombol Simpan
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          existing == null ? 'Tambah Aset' : 'Simpan',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (selectedType == 'crypto') {
                            final qty = double.tryParse(qtyCtrl.text);
                            final harga = double.tryParse(hargaCtrl.text);
                            if (qty == null ||
                                qty <= 0 ||
                                harga == null ||
                                harga < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Isi jumlah dan harga beli dengan benar.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              if (existing == null) {
                                final idx = daftarAsset.indexWhere(
                                  (a) => a.symbol == selectedCrypto.symbol,
                                );
                                if (idx >= 0) {
                                  final old = daftarAsset[idx];
                                  final totalQty = old.quantity + qty;
                                  final avgPrice =
                                      ((old.quantity * old.buyPrice) +
                                          (qty * harga)) /
                                      totalQty;
                                  daftarAsset[idx] = Asset(
                                    id: old.id,
                                    symbol: old.symbol,
                                    name: old.name,
                                    quantity: totalQty,
                                    buyPrice: avgPrice,
                                    assetType: 'crypto',
                                  );
                                } else {
                                  daftarAsset.add(
                                    Asset(
                                      id: DateTime.now().millisecondsSinceEpoch
                                          .toString(),
                                      symbol: selectedCrypto.symbol,
                                      name: selectedCrypto.name,
                                      quantity: qty,
                                      buyPrice: harga,
                                      assetType: 'crypto',
                                    ),
                                  );
                                }
                              } else {
                                existing.quantity = qty;
                                existing.buyPrice = harga;
                              }
                              saveData();
                            });
                            Navigator.pop(ctx);
                            if (existing == null) _fetchHarga();
                          } else {
                            final name = nameCtrl.text.trim();
                            final nominalStr = nominalCtrl.text.replaceAll(
                              '.',
                              '',
                            );
                            final nominal = double.tryParse(nominalStr);
                            final bunga = double.tryParse(bungaCtrl.text);

                            int? tenor;
                            if (selectedTenorOption == "Kustom") {
                              tenor = int.tryParse(customTenorCtrl.text);
                            } else {
                              tenor = int.tryParse(selectedTenorOption);
                            }

                            if (name.isEmpty ||
                                nominal == null ||
                                nominal <= 0 ||
                                bunga == null ||
                                bunga < 0 ||
                                tenor == null ||
                                tenor <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Isi semua data Deposito dengan benar.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (existing == null && selectedAccount.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pilih akun pembayaran.'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              if (existing == null) {
                                final assetId = DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString();

                                daftarAsset.add(
                                  Asset(
                                    id: assetId,
                                    symbol: 'DEP',
                                    name: name,
                                    quantity: 1.0,
                                    buyPrice: nominal,
                                    assetType: 'deposito',
                                    interestRate: bunga,
                                    tenor: tenor,
                                    depositDate: depositDate,
                                    sourceAccount: selectedAccount,
                                    isInterestPaid: false,
                                  ),
                                );

                                daftarTransaksi.add(
                                  Transaksi(
                                    id: 'investasi_beli_$assetId',
                                    nominal: nominal,
                                    catatan: 'Pembelian Aset: $name',
                                    tipe: 'Pengeluaran',
                                    kategori: 'Investasi',
                                    akun: selectedAccount,
                                    tanggal: depositDate,
                                  ),
                                );
                              } else {
                                existing.name = name;
                                existing.buyPrice = nominal;
                                existing.interestRate = bunga;
                                existing.tenor = tenor;
                                existing.depositDate = depositDate;
                              }
                              saveData();
                            });

                            _checkMaturityAndAddInterest();
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _hapusAsset(Asset a) {
    final isDeposito = a.assetType == "deposito";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isDeposito ? 'Hapus/Cairkan Deposito?' : 'Hapus ${a.symbol}?',
        ),
        content: Text(
          isDeposito
              ? 'Aset ${a.name} senilai Rp ${_fmt(a.buyPrice)} akan dihapus dari portofolio. Pilih apakah Anda ingin mengembalikan saldo pokok ke akun ${a.sourceAccount ?? ""}?'
              : 'Aset ${a.name} (${_fmtQty(a.quantity)} ${a.symbol}) akan dihapus dari portofolio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          if (isDeposito)
            TextButton(
              onPressed: () {
                setState(() {
                  // Add Pemasukan transaction for principal
                  daftarTransaksi.add(
                    Transaksi(
                      id: 'investasi_cair_${a.id}',
                      nominal: a.buyPrice,
                      catatan: 'Pencairan Pokok Aset: ${a.name}',
                      tipe: 'Pemasukan',
                      kategori: 'Investasi',
                      akun:
                          a.sourceAccount ??
                          (masterAkun.isNotEmpty ? masterAkun.first : 'Tunai'),
                      tanggal: DateTime.now(),
                    ),
                  );
                  daftarAsset.removeWhere((x) => x.id == a.id);
                  saveData();
                });
                Navigator.pop(ctx);
              },
              child: const Text(
                'Cairkan Pokok & Hapus',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                daftarAsset.removeWhere((x) => x.id == a.id);
                saveData();
              });
              Navigator.pop(ctx);
            },
            child: Text(isDeposito ? 'Hapus Saja' : 'Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hitung total portofolio aset tambahan
    double totalNilai = 0;
    double totalModal = 0;
    for (final a in daftarAsset) {
      totalNilai += _nilaiSekarang(a);
      totalModal += _modal(a);
    }
    final totalPL = totalNilai - totalModal;
    final totalPLPct = totalModal > 0 ? (totalPL / totalModal) * 100 : 0.0;
    final isProfit = totalPL >= 0;

    // Hitung total saldo akun
    double totalSaldoAkun = 0;
    for (final namaAkun in masterAkun) {
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
      totalSaldoAkun += saldo;
    }

    final grandTotal = totalNilai + totalSaldoAkun;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchHarga,
        color: const Color(0xFF6C63FF),
        child: CustomScrollView(
          slivers: [
            // ── Header Portofolio ──
            SliverToBoxAdapter(
              child: _buildHeader(
                grandTotal,
                totalNilai,
                totalSaldoAkun,
                totalModal,
                totalPL,
                totalPLPct,
                isProfit,
                isDark,
              ),
            ),

            // ── Error / Loading indicator ──
            if (_errorMsg != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchHarga,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Judul List ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Aset Saya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    if (_lastUpdated != null && !_isLoading)
                      Text(
                        'Update ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ),

            // ── Daftar Asset ──
            daftarAsset.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildAssetCard(daftarAsset[i], isDark),
                      childCount: daftarAsset.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAssetDialog(),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Header Widget ────────────────────────────────────────────────────────
  Widget _buildHeader(
    double grandTotal,
    double totalNilai,
    double totalSaldoAkun,
    double totalModal,
    double totalPL,
    double totalPLPct,
    bool isProfit,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A3F8F), Color(0xFF6C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Portofolio Asset',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            isHideSaldoGlobal ? 'Rp ••••••••' : 'Rp ${_fmt(grandTotal)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          // Detail Portofolio: Aset Ditambahkan & Saldo Akun
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aset Ditambahkan',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isHideSaldoGlobal
                          ? 'Rp ••••••••'
                          : 'Rp ${_fmt(totalNilai)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Saldo Akun',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isHideSaldoGlobal
                          ? 'Rp ••••••••'
                          : 'Rp ${_fmt(totalSaldoAkun)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          // Info khusus Aset yang Ditambahkan (Modal, P&L, Return)
          const Text(
            'Kinerja Aset Ditambahkan:',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _headerStat(
                'Modal',
                isHideSaldoGlobal ? 'Rp ••••••••' : 'Rp ${_fmt(totalModal)}',
                Colors.white70,
              ),
              const SizedBox(width: 16),
              _headerStat(
                'P&L',
                isHideSaldoGlobal
                    ? 'Rp ••••••••'
                    : '${isProfit ? '+' : ''}Rp ${_fmt(totalPL)}',
                isProfit ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
              ),
              const SizedBox(width: 16),
              _headerStat(
                'Return',
                '${isProfit ? '+' : ''}${totalPLPct.toStringAsFixed(2)}%',
                isProfit ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Asset Card ───────────────────────────────────────────────────────────
  Widget _buildAssetCard(Asset a, bool isDark) {
    if (a.assetType == "deposito") {
      final nilai = _nilaiSekarang(a);
      final color = const Color(0xFF6C63FF);

      final depositDate = a.depositDate ?? DateTime.now();
      final tenor = a.tenor ?? 30;
      final maturityDate = depositDate.add(Duration(days: tenor));
      final remainingDays = maturityDate.difference(DateTime.now()).inDays;

      String statusStr = "Aktif";
      Color statusColor = Colors.blue;
      if (a.isInterestPaid ?? false) {
        statusStr = "Selesai (Cair)";
        statusColor = Colors.green;
      } else if (remainingDays <= 0) {
        statusStr = "Jatuh Tempo";
        statusColor = Colors.orange;
      } else {
        statusStr = "Aktif ($remainingDays hari)";
        statusColor = Colors.blue;
      }

      return Dismissible(
        key: Key(a.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          _hapusAsset(a);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Colors.red.withValues(alpha: 0.15),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        child: GestureDetector(
          onTap: () => _showAssetDialog(existing: a),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Ikon Deposito
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.account_balance,
                          color: Color(0xFF6C63FF),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nama & Kategori
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "REKSADANA / DEPOSITO",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nilai & Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isHideSaldoGlobal
                              ? 'Rp ••••••••'
                              : 'Rp ${_fmt(nilai)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusStr,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Detail bawah
                Row(
                  children: [
                    _detailItem(
                      'Nominal',
                      isHideSaldoGlobal
                          ? 'Rp ••••••••'
                          : 'Rp ${_fmt(a.buyPrice)}',
                      Colors.grey[600]!,
                    ),
                    _detailItem(
                      'Bunga',
                      '${a.interestRate}% p.a.',
                      Colors.grey[600]!,
                    ),
                    _detailItem('Tenor', '${a.tenor} Hari', Colors.grey[600]!),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _detailItem(
                      'Tgl Deposito',
                      '${depositDate.day}/${depositDate.month}/${depositDate.year}',
                      Colors.grey[600]!,
                    ),
                    _detailItem(
                      'Jatuh Tempo',
                      '${maturityDate.day}/${maturityDate.month}/${maturityDate.year}',
                      Colors.grey[600]!,
                    ),
                    _detailItem(
                      'Akun Asal',
                      a.sourceAccount ?? '—',
                      Colors.grey[600]!,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hargaSekarang = _hargaLive[a.symbol];
    final nilai = _nilaiSekarang(a);
    final pl = _pl(a);
    final plPct = _plPersen(a);
    final isProfit = pl >= 0;
    final color = _cryptoColor(a.symbol);

    return Dismissible(
      key: Key(a.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _hapusAsset(a);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () => _showAssetDialog(existing: a),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Ikon kripto
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        a.symbol.length > 2
                            ? a.symbol.substring(0, 2)
                            : a.symbol,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nama & jumlah
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          a.name,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nilai portofolio
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hargaSekarang == null
                            ? '—'
                            : (isHideSaldoGlobal
                                  ? 'Rp ••••••••'
                                  : 'Rp ${_fmt(nilai)}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (hargaSekarang != null)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isProfit
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${plPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isProfit ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Detail bawah
              Row(
                children: [
                  _detailItem('Qty', _fmtQty(a.quantity), Colors.grey[600]!),
                  _detailItem(
                    'Harga Beli',
                    _hargaLive[a.symbol] == null
                        ? '—'
                        : 'Rp ${_fmt(_hargaLive[a.symbol]!.buy)}',
                    Colors.grey[600]!,
                  ),
                  _detailItem(
                    'Harga Jual',
                    _hargaLive[a.symbol] == null
                        ? '—'
                        : 'Rp ${_fmt(_hargaLive[a.symbol]!.sell)}',
                    Colors.grey[600]!,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _detailItem(
                    'Rata-rata Beli',
                    'Rp ${_fmt(a.buyPrice)}',
                    Colors.grey[600]!,
                  ),
                  _detailItem(
                    'Harga Kini',
                    hargaSekarang == null
                        ? '—'
                        : 'Rp ${_fmt(hargaSekarang.last)}',
                    Colors.grey[600]!,
                  ),
                  _detailItem(
                    'P&L',
                    hargaSekarang == null
                        ? '—'
                        : (isHideSaldoGlobal
                              ? 'Rp ••••••••'
                              : '${isProfit ? '+' : ''}Rp ${_fmt(pl)}'),
                    hargaSekarang == null
                        ? Colors.grey
                        : (isProfit ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.currency_bitcoin,
                size: 40,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Aset',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ketuk tombol "+" untuk mulai\nmencatat portofolio Asset Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

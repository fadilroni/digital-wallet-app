import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data_model.dart';

class GrafikScreen extends StatefulWidget {
  const GrafikScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _GrafikScreenState createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Transaksi state ───────────────────────────────────────────
  String _selectedTipe = 'Pengeluaran';
  String _chartType = 'Line'; // default grafik garis
  String _selectedAkun = 'Semua';
  String _selectedKategori = 'Semua';
  DateTime rangeMulai = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime rangeSelesai = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  final List<Color> palette = const [
    Color(0xFF6C63FF),
    Color(0xFFFF2E93),
    Color(0xFF00ADB5),
    Color(0xFFFF8E25),
    Color(0xFF4E9F3D),
    Color(0xFFFFD369),
    Color(0xFFDE3B40),
    Color(0xFF2979FF),
    Color(0xFF00E676),
    Color(0xFF8A3DFF),
    Color(0xFFF7931A),
    Color(0xFF627EEA),
  ];

  Map<String, double> _hargaLive = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHargaCrypto();
  }

  Future<void> _fetchHargaCrypto() async {
    if (globalHargaCrypto.isNotEmpty) {
      if (mounted) {
        setState(() {
          _hargaLive = Map.from(globalHargaCrypto);
        });
      }
      return;
    }
    try {
      final resp = await http
          .get(Uri.parse('https://indodax.com/api/ticker_all'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final tickers = data['tickers'] as Map<String, dynamic>;
        final Map<String, double> harga = {};
        for (final crypto in cryptoList) {
          final key = '${crypto.symbol.toLowerCase()}_idr';
          if (tickers.containsKey(key)) {
            final ticker = tickers[key] as Map<String, dynamic>;
            final lastVal =
                double.tryParse(ticker['last']?.toString() ?? '') ?? 0.0;
            harga[crypto.symbol] = lastVal;
            globalHargaCrypto[crypto.symbol] = lastVal;
          }
        }
        if (mounted) {
          setState(() {
            _hargaLive = harga;
          });
        }
      } else {
        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────
  Color _asetColor(Asset a, int idx) {
    const map = {
      'BTC': Color(0xFFF7931A),
      'ETH': Color(0xFF627EEA),
      'USDT': Color(0xFF26A17B),
      'BNB': Color(0xFFF3BA2F),
      'SOL': Color(0xFF9945FF),
      'XRP': Color(0xFF00AAE4),
    };
    if (a.assetType == 'deposito') return const Color(0xFF6C63FF);
    return map[a.symbol] ?? palette[idx % palette.length];
  }

  String _fmt(double v) {
    bool isNegative = v < 0;
    double absValue = v.abs();
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

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFF6C63FF),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long), text: 'Transaksi'),
              Tab(icon: Icon(Icons.pie_chart), text: 'Aset'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTransaksiTab(isDark), _buildAsetTab(isDark)],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1 — TRANSAKSI
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTransaksiTab(bool isDark) {
    final kategoriAktif = masterKategori
        .where((k) => k.tipe == _selectedTipe)
        .map((k) => k.nama)
        .toList();

    if (!['Semua', ...masterAkun].contains(_selectedAkun)) {
      _selectedAkun = 'Semua';
    }
    if (!['Semua', ...kategoriAktif].contains(_selectedKategori)) {
      _selectedKategori = 'Semua';
    }

    final filtered = daftarTransaksi.where((t) {
      return t.tipe == _selectedTipe &&
          t.kategori != 'Pindah Dana' &&
          !t.tanggal.isBefore(rangeMulai) &&
          t.tanggal.isBefore(rangeSelesai.add(const Duration(days: 1))) &&
          (_selectedAkun == 'Semua' || t.akun == _selectedAkun) &&
          (_selectedKategori == 'Semua' || t.kategori == _selectedKategori);
    }).toList();

    final total = filtered.fold<double>(0, (s, t) => s + t.nominal);

    // Per kategori
    final Map<String, double> catMap = {};
    for (var t in filtered) {
      catMap[t.kategori] = (catMap[t.kategori] ?? 0) + t.nominal;
    }
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Harian untuk grafik garis/kolom
    final List<DateTime> days = [];
    final List<double> dayVals = [];
    DateTime cur = DateTime(rangeMulai.year, rangeMulai.month, rangeMulai.day);
    final end = DateTime(
      rangeSelesai.year,
      rangeSelesai.month,
      rangeSelesai.day,
    );
    while (!cur.isAfter(end)) {
      days.add(cur);
      dayVals.add(
        filtered
            .where(
              (t) =>
                  t.tanggal.year == cur.year &&
                  t.tanggal.month == cur.month &&
                  t.tanggal.day == cur.day,
            )
            .fold(0, (s, t) => s + t.nominal),
      );
      cur = cur.add(const Duration(days: 1));
    }

    final accentColor = _selectedTipe == 'Pengeluaran'
        ? Colors.redAccent
        : Colors.greenAccent;

    // Warna grafik garis: sesuai kategori yang dipilih, atau accent jika "Semua"
    Color lineColor = accentColor;
    if (_selectedKategori != 'Semua') {
      final selIdx = sorted.indexWhere((e) => e.key == _selectedKategori);
      if (selIdx >= 0) {
        lineColor = palette[selIdx % palette.length];
      } else {
        // Kategori belum ada di sorted (tidak ada transaksi), pakai warna dari
        // posisi kategori dalam daftar master untuk konsistensi
        final masterIdx = kategoriAktif.indexOf(_selectedKategori);
        lineColor =
            palette[masterIdx.clamp(0, palette.length - 1) % palette.length];
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter periode ──
          _periodCard(),
          const SizedBox(height: 10),

          // ── Filter tipe + chart type ──
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  label: 'Tipe',
                  value: _selectedTipe,
                  items: const ['Pengeluaran', 'Pemasukan'],
                  onChanged: (v) => setState(() {
                    _selectedTipe = v!;
                    _selectedKategori = 'Semua';
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  label: 'Grafik',
                  value: _chartType,
                  items: const ['Line', 'Pie'],
                  labels: const ['Grafik Garis', 'Grafik Pie'],
                  onChanged: (v) => setState(() => _chartType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Filter akun + kategori ──
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('akun_$_selectedAkun'),
                  initialValue: _selectedAkun,
                  decoration: const InputDecoration(
                    labelText: 'Akun',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: ['Semua', ...masterAkun]
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAkun = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('kat_${_selectedTipe}_$_selectedKategori'),
                  initialValue: _selectedKategori,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: ['Semua', ...kategoriAktif]
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedKategori = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Total card ──
          Card(
            color: _selectedTipe == 'Pengeluaran'
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.green.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    'Total $_selectedTipe',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${formatRibuan(total)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Chart ──
          if (filtered.isEmpty)
            _emptyCard()
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _chartType == 'Line'
                          ? 'Tren Harian — ${_selectedKategori == 'Semua' ? _selectedTipe : _selectedKategori}'
                          : 'Distribusi per Kategori',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _chartType == 'Line' ? lineColor : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: _chartType == 'Line'
                          ? CustomPaint(
                              painter: LineChartPainter(
                                days: days,
                                values: dayVals,
                                lineColor: lineColor,
                                gridColor: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                                textColor: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            )
                          : CustomPaint(
                              painter: DonutPainter(
                                values: sorted.map((e) => e.value).toList(),
                                colors: palette,
                                bgColor: Theme.of(context).cardColor,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // ── Legenda kategori — selalu tampil ──
                    const Divider(),
                    const SizedBox(height: 4),
                    Text(
                      'Rincian per Kategori:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final cat = entry.value.key;
                      final val = entry.value.value;
                      final pct = total > 0 ? (val / total * 100) : 0.0;
                      final col = palette[i % palette.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%  Rp ${formatRibuan(val)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: col,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2 — ASET (Pie Donut + Saldo Akun)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAsetTab(bool isDark) {
    // ── Saldo tiap akun ─────────────────────────────────────────
    final List<Color> akunColors = const [
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFF8BC34A),
      Color(0xFF03A9F4),
      Color(0xFF00ACC1),
    ];
    final List<_AsetSlice> akunSlices = [];
    double totalSaldo = 0;
    for (int i = 0; i < masterAkun.length; i++) {
      final nama = masterAkun[i];
      double saldo = saldoAwalMap[nama] ?? 0.0;
      for (var t in daftarTransaksi) {
        if (t.akun == nama) {
          saldo += t.tipe == 'Pemasukan' ? t.nominal : -t.nominal;
        }
      }
      if (saldo > 0) {
        totalSaldo += saldo;
        akunSlices.add(
          _AsetSlice(
            label: nama,
            sublabel: 'Saldo Akun',
            nilai: saldo,
            color: akunColors[i % akunColors.length],
          ),
        );
      }
    }

    // ── Nilai tiap aset ─────────────────────────────────────────
    final List<_AsetSlice> asetSlices = daftarAsset.asMap().entries.map((e) {
      final a = e.value;
      double nilai;
      if (a.assetType == 'deposito') {
        nilai = a.buyPrice;
      } else {
        final livePrice = _hargaLive[a.symbol] ?? globalHargaCrypto[a.symbol];
        if (livePrice != null && livePrice > 0) {
          nilai = a.quantity * livePrice;
        } else {
          nilai = a.quantity * a.buyPrice; // fallback ke modal beli
        }
      }
      return _AsetSlice(
        label: a.assetType == 'deposito' ? a.name : a.symbol,
        sublabel: a.assetType == 'deposito' ? 'Deposito/Reksadana' : a.name,
        nilai: nilai,
        color: _asetColor(a, e.key),
      );
    }).toList()..sort((a, b) => b.nilai.compareTo(a.nilai));

    final totalAset = asetSlices.fold<double>(0, (s, e) => s + e.nilai);
    final grandTotal = totalAset + totalSaldo;
    final allSlices = [...asetSlices, ...akunSlices];

    if (allSlices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data aset atau akun.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header total keseluruhan ──
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C94FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Total Kekayaan Bersih',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rp ${_fmt(grandTotal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _subHeader('Aset Investasi', totalAset, Colors.white),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _subHeader(
                      'Saldo Akun',
                      totalSaldo,
                      const Color(0xFF80DEEA),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Donut + Legend ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Distribusi Kekayaan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${asetSlices.length} aset  ·  ${akunSlices.length} akun',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 230,
                    child: CustomPaint(
                      painter: DonutPainter(
                        values: allSlices.map((s) => s.nilai).toList(),
                        colors: allSlices.map((s) => s.color).toList(),
                        bgColor: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Aset section
                  if (asetSlices.isNotEmpty) ...[
                    const Divider(),
                    _sectionHeader(
                      '📈  Aset Investasi',
                      totalAset,
                      grandTotal,
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 4),
                    ...asetSlices.map((s) => _sliceRow(s, grandTotal)),
                  ],

                  // Akun section
                  if (akunSlices.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Divider(),
                    _sectionHeader(
                      '🏦  Saldo Akun',
                      totalSaldo,
                      grandTotal,
                      const Color(0xFF00BCD4),
                    ),
                    const SizedBox(height: 4),
                    ...akunSlices.map((s) => _sliceRow(s, grandTotal)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeader(String label, double val, Color valColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          'Rp ${_fmt(val)}',
          style: TextStyle(
            color: valColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, double sub, double grand, Color color) {
    final pct = grand > 0 ? sub / grand * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%  Rp ${_fmt(sub)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliceRow(_AsetSlice s, double grand) {
    final pct = grand > 0 ? s.nilai / grand * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  s.sublabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp ${_fmt(s.nilai)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: s.color,
                  fontSize: 13,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── shared widgets ────────────────────────────────────────────
  Widget _periodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(
                'Dari: ${rangeMulai.day}/${rangeMulai.month}/${rangeMulai.year}',
              ),
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: rangeMulai,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (p != null) setState(() => rangeMulai = p);
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(
                'Sampai: ${rangeSelesai.day}/${rangeSelesai.month}/${rangeSelesai.year}',
              ),
              onPressed: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: rangeSelesai,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (p != null) setState(() => rangeSelesai = p);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    List<String>? labels,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: items.asMap().entries.map((e) {
        final lbl = labels != null ? labels[e.key] : e.value;
        return DropdownMenuItem(value: e.value, child: Text(lbl));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _emptyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 10),
            const Text(
              'Tidak ada data pada periode ini.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────
class _AsetSlice {
  final String label;
  final String sublabel;
  final double nilai;
  final Color color;
  _AsetSlice({
    required this.label,
    required this.sublabel,
    required this.nilai,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════
//  PAINTERS
// ═══════════════════════════════════════════════════════════════

class DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color bgColor;

  DonutPainter({
    required this.values,
    required this.colors,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (s, v) => s + v);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double start = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      start += sweep;
    }

    // Donut hole
    canvas.drawCircle(center, radius * 0.55, Paint()..color = bgColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class LineChartPainter extends CustomPainter {
  final List<DateTime> days;
  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  LineChartPainter({
    required this.days,
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    double maxV = values.fold(0.0, (m, v) => v > m ? v : m);
    if (maxV == 0) maxV = 1;

    const lp = 52.0, bp = 30.0, tp = 10.0, rp = 10.0;
    final cw = size.width - lp - rp;
    final ch = size.height - tp - bp;

    // Grid
    for (int i = 0; i <= 4; i++) {
      final y = tp + ch * (1 - i / 4);
      canvas.drawLine(
        Offset(lp, y),
        Offset(size.width - rp, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = 0.5,
      );
      _drawText(
        canvas,
        _fmtK(maxV * i / 4),
        textColor,
        9,
        Offset(0, y - 5),
        lp - 5,
      );
    }

    // Points
    final pts = List.generate(n, (i) {
      final x = lp + (i + 0.5) * (cw / n);
      final y = tp + ch * (1 - values[i] / maxV);
      return Offset(x, y);
    });

    // Bars
    final bw = (cw / n * 0.5).clamp(4.0, 18.0);
    for (int i = 0; i < n; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            pts[i].dx - bw / 2,
            pts[i].dy,
            pts[i].dx + bw / 2,
            size.height - bp,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = lineColor.withValues(alpha: 0.35),
      );
    }

    // Line
    if (pts.length > 1) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Dots
    for (final p in pts) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 2.5, Paint()..color = lineColor);
    }

    // X labels
    final interval = (n / 6).ceil().clamp(1, n);
    for (int i = 0; i < n; i++) {
      if (i % interval == 0 || i == n - 1) {
        _drawText(
          canvas,
          '${days[i].day}/${days[i].month}',
          textColor,
          8,
          Offset(pts[i].dx - 10, size.height - bp + 5),
          24,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    double fontSize,
    Offset position,
    double maxW,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, position);
  }

  String _fmtK(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

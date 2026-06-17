import 'package:flutter/material.dart';
import '../data_model.dart';

class GrafikScreen extends StatefulWidget {
  const GrafikScreen({super.key});

  @override
  _GrafikScreenState createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen> {
  String _selectedTipe = "Pengeluaran"; // "Pengeluaran" atau "Pemasukan"
  String _chartType = "Pie"; // "Pie" atau "ColumnLine"
  String _selectedAkun = "Semua";
  String _selectedKategori = "Semua";

  // Filter Tanggal Default: Bulan Juni 2026 (Menyesuaikan waktu default saat ini)
  DateTime rangeMulai = DateTime(2026, 6, 1);
  DateTime rangeSelesai = DateTime(2026, 6, 30);

  final List<Color> paletteWarna = [
    const Color(0xFF00ADB5), // Teal
    const Color(0xFFFF2E93), // Pink
    const Color(0xFF3F72AF), // Blue
    const Color(0xFFFF8E25), // Orange
    const Color(0xFF8A3DFF), // Purple
    const Color(0xFF4E9F3D), // Green
    const Color(0xFFFFD369), // Yellow
    const Color(0xFFDE3B40), // Red
    const Color(0xFF00E676), // Bright Green
    const Color(0xFF2979FF), // Bright Blue
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<String> kategoriAktif = masterKategori
        .where((k) => k.tipe == _selectedTipe)
        .map((k) => k.nama)
        .toList();

    // Proteksi filter akun jika akun dihapus dari masterAkun
    if (!["Semua", ...masterAkun].contains(_selectedAkun)) {
      _selectedAkun = "Semua";
    }

    // Proteksi filter kategori jika kategori dihapus dari masterKategori
    if (!["Semua", ...kategoriAktif].contains(_selectedKategori)) {
      _selectedKategori = "Semua";
    }

    // Filter transaksi berdasarkan Tipe, Range Tanggal, Akun, dan Kategori
    List<Transaksi> transaksiTerfilter = daftarTransaksi.where((t) {
      bool masukTipe = t.tipe == _selectedTipe;
      bool masukRange =
          t.tanggal.isAfter(rangeMulai.subtract(const Duration(days: 1))) &&
          t.tanggal.isBefore(rangeSelesai.add(const Duration(days: 1)));
      bool masukAkun = _selectedAkun == "Semua" || t.akun == _selectedAkun;
      bool masukKategori = _selectedKategori == "Semua" || t.kategori == _selectedKategori;
      return masukTipe && masukRange && masukAkun && masukKategori;
    }).toList();

    // Hitung Total Nominal pada periode terfilter
    double totalNominal = transaksiTerfilter.fold(0, (sum, t) => sum + t.nominal);

    // ================= DATA UNTUK PIE CHART =================
    // Grouping berdasarkan Kategori
    Map<String, double> categorySums = {};
    for (var t in transaksiTerfilter) {
      categorySums[t.kategori] = (categorySums[t.kategori] ?? 0) + t.nominal;
    }

    // Urutkan kategori berdasarkan nominal terbesar
    var sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<double> pieValues = sortedCategories.map((e) => e.value).toList();
    List<String> pieLabels = sortedCategories.map((e) => e.key).toList();

    // ================= DATA UNTUK COLUMN/LINE CHART =================
    // Grouping harian dari rangeMulai sampai rangeSelesai
    List<DateTime> chartDates = [];
    List<double> chartValues = [];

    DateTime cur = DateTime(rangeMulai.year, rangeMulai.month, rangeMulai.day);
    DateTime end = DateTime(rangeSelesai.year, rangeSelesai.month, rangeSelesai.day);

    while (cur.isBefore(end) || cur.isAtSameMomentAs(end)) {
      chartDates.add(cur);

      double daySum = 0;
      for (var t in transaksiTerfilter) {
        if (t.tanggal.year == cur.year &&
            t.tanggal.month == cur.month &&
            t.tanggal.day == cur.day) {
          daySum += t.nominal;
        }
      }
      chartValues.add(daySum);

      cur = cur.add(const Duration(days: 1));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. FILTER RANGE TANGGAL
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Column(
                children: [
                  const Text(
                    "PERIODE GRAFIK",
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. TOGGLE TIPE (PENGELUARAN / PEMASUKAN) & TOGGLE BENTUK GRAFIK (PIE / COLUMN LINE)
          Row(
            children: [
              // Toggle Tipe
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTipe,
                  decoration: const InputDecoration(
                    labelText: "Tipe Transaksi",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ["Pengeluaran", "Pemasukan"].map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTipe = val!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Toggle Bentuk Grafik
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _chartType,
                  decoration: const InputDecoration(
                    labelText: "Bentuk Grafik",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Pie", child: Text("Grafik Pie")),
                    DropdownMenuItem(value: "ColumnLine", child: Text("Grafik Kolom & Garis")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _chartType = val!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // TOGGLE AKUN & TOGGLE KATEGORI
          Row(
            children: [
              // Filter Akun
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('akun_$_selectedAkun'),
                  initialValue: _selectedAkun,
                  decoration: const InputDecoration(
                    labelText: "Filter Akun",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ["Semua", ...masterAkun].map((a) {
                    return DropdownMenuItem(value: a, child: Text(a));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAkun = val!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Filter Kategori
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('kategori_${_selectedTipe}_$_selectedKategori'),
                  initialValue: _selectedKategori,
                  decoration: const InputDecoration(
                    labelText: "Filter Kategori",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ["Semua", ...kategoriAktif].map((k) {
                    return DropdownMenuItem(value: k, child: Text(k));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedKategori = val!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 3. RINGKASAN TOTAL
          Card(
            color: _selectedTipe == "Pengeluaran"
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Total $_selectedTipe",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Rp ${formatRibuan(totalNominal)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _selectedTipe == "Pengeluaran" ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          // 4. VIEWPORT GRAFIK
          if (transaksiTerfilter.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 10),
                    const Text(
                      "Tidak ada data transaksi pada periode ini.",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _chartType == "Pie"
                          ? "Distribusi per Kategori"
                          : "Tren Tren Harian ($_selectedTipe)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 220,
                      child: _chartType == "Pie"
                          ? CustomPaint(
                              painter: PieChartPainter(
                                values: pieValues,
                                colors: paletteWarna,
                                bgCircleColor: theme.cardColor,
                              ),
                            )
                          : CustomPaint(
                              painter: ColumnLineChartPainter(
                                dates: chartDates,
                                values: chartValues,
                                columnColor: _selectedTipe == "Pengeluaran"
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                lineColor: Colors.blueAccent,
                                gridColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                                textColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // 5. LEGENDA (HANYA UNTUK PIE CHART)
                    if (_chartType == "Pie") ...[
                      const Divider(),
                      const SizedBox(height: 5),
                      const Text(
                        "Rincian Kategori:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pieLabels.length,
                        itemBuilder: (c, i) {
                          final label = pieLabels[i];
                          final value = pieValues[i];
                          final percent = totalNominal > 0 ? (value / totalNominal) * 100 : 0.0;
                          final color = paletteWarna[i % paletteWarna.length];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text(
                                  "${percent.toStringAsFixed(1)}% (${formatRibuan(value)})",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= CUSTOM PAINTERS =================

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color bgCircleColor;

  PieChartPainter({
    required this.values,
    required this.colors,
    required this.bgCircleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    double startAngle = -3.141592653589793 / 2; // Mulai dari atas
    Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width < size.height ? size.width / 2 : size.height / 2,
    );

    // Gambar potongan busur pie
    for (int i = 0; i < values.length; i++) {
      double sweepAngle = (values[i] / total) * 2 * 3.141592653589793;
      Paint paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Gambar pembatas tipis antar potongan
      Paint borderPaint = Paint()
        ..color = bgCircleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      startAngle += sweepAngle;
    }

    // Gambar lingkaran tengah agar berbentuk Donut Chart (Lebih premium)
    Paint centerPaint = Paint()
      ..color = bgCircleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), rect.width * 0.35, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ColumnLineChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final List<double> values;
  final Color columnColor;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  ColumnLineChartPainter({
    required this.dates,
    required this.values,
    required this.columnColor,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    double maxValue = values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxValue == 0) maxValue = 1.0; // Hindari pembagian dengan nol

    double leftPadding = 50;
    double bottomPadding = 30;
    double topPadding = 10;
    double rightPadding = 10;

    double chartWidth = size.width - leftPadding - rightPadding;
    double chartHeight = size.height - topPadding - bottomPadding;

    // 1. Gambar Garis Kisi Horisontal & Label Y-axis
    int gridLinesCount = 4;
    for (int i = 0; i <= gridLinesCount; i++) {
      double yVal = maxValue * i / gridLinesCount;
      double yPos = topPadding + chartHeight * (1 - i / gridLinesCount);

      Paint gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(leftPadding, yPos), Offset(size.width - rightPadding, yPos), gridPaint);

      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: formatLabelK(yVal),
          style: TextStyle(color: textColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 5, yPos - textPainter.height / 2));
    }

    // 2. Gambar Kolom (Bar) & Hitung Titik Koordinat untuk Garis (Line)
    int n = values.length;
    double spacing = chartWidth / n;
    double barWidth = spacing * 0.55;
    if (barWidth > 20) barWidth = 20;

    List<Offset> points = [];

    for (int i = 0; i < n; i++) {
      double xPos = leftPadding + (i * spacing) + (spacing / 2);
      double yPos = topPadding + chartHeight * (1 - (values[i] / maxValue));

      // Gambar Bar
      Paint barPaint = Paint()
        ..color = columnColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;

      RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(xPos - barWidth / 2, yPos, xPos + barWidth / 2, size.height - bottomPadding),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, barPaint);

      points.add(Offset(xPos, yPos));

      // Label tanggal X-axis (Hanya tampilkan beberapa agar tidak tumpang tindih)
      int labelInterval = (n / 6).ceil();
      if (labelInterval == 0) labelInterval = 1;

      if (i % labelInterval == 0 || i == n - 1) {
        String labelStr = "${dates[i].day}/${dates[i].month}";
        TextPainter xPainter = TextPainter(
          text: TextSpan(
            text: labelStr,
            style: TextStyle(color: textColor, fontSize: 8),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        xPainter.paint(canvas, Offset(xPos - xPainter.width / 2, size.height - bottomPadding + 5));
      }
    }

    // 3. Gambar Garis Tren (Line Chart) menghubungkan titik-titik data
    if (points.length > 1) {
      Path path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      Paint linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    // 4. Gambar Titik Bulat (Dots) pada setiap koordinat garis
    for (var pt in points) {
      Paint dotOuterPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      Paint dotInnerPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pt, 4.0, dotOuterPaint);
      canvas.drawCircle(pt, 2.5, dotInnerPaint);
    }
  }

  String formatLabelK(double val) {
    if (val >= 1000000) {
      return "${(val / 1000000).toStringAsFixed(1)}jt";
    } else if (val >= 1000) {
      return "${(val / 1000).toStringAsFixed(0)}rb";
    }
    return val.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

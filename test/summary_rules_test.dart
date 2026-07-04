import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_digital/data_model.dart';

void main() {
  group('summary counting rules', () {
    test(
      'does not count hutang and piutang transactions in income or expense totals',
      () {
        final piutang = Transaksi(
          id: '1',
          nominal: 100000,
          catatan: 'Piutang',
          tipe: 'Pengeluaran',
          kategori: 'Piutang',
          akun: 'Cash Bank',
          tanggal: DateTime(2026, 7, 1),
        );
        final hutang = Transaksi(
          id: '2',
          nominal: 50000,
          catatan: 'Hutang',
          tipe: 'Pemasukan',
          kategori: 'Hutang',
          akun: 'Cash Bank',
          tanggal: DateTime(2026, 7, 1),
        );

        expect(shouldCountInSummary(piutang), isFalse);
        expect(shouldCountInSummary(hutang), isFalse);
      },
    );

    test('does not count sedekah or reimburse as expense', () {
      final sedekah = Transaksi(
        id: '3',
        nominal: 20000,
        catatan: 'Sedekah',
        tipe: 'Pengeluaran',
        kategori: 'Sedekah',
        akun: 'Cash Bank',
        tanggal: DateTime(2026, 7, 1),
      );
      final reimburseExpense = Transaksi(
        id: '4',
        nominal: 15000,
        catatan: 'Reimburse',
        tipe: 'Pengeluaran',
        kategori: 'Reimburse',
        akun: 'Cash Bank',
        tanggal: DateTime(2026, 7, 1),
      );

      expect(shouldCountInSummary(sedekah), isFalse);
      expect(shouldCountInSummary(reimburseExpense), isFalse);
    });

    test('does not count pemberian or reimburse as income', () {
      final pemberian = Transaksi(
        id: '5',
        nominal: 75000,
        catatan: 'Pemberian',
        tipe: 'Pemasukan',
        kategori: 'Pemberian',
        akun: 'Cash Bank',
        tanggal: DateTime(2026, 7, 1),
      );
      final reimburseIncome = Transaksi(
        id: '6',
        nominal: 30000,
        catatan: 'Reimburse',
        tipe: 'Pemasukan',
        kategori: 'Reimburse',
        akun: 'Cash Bank',
        tanggal: DateTime(2026, 7, 1),
      );

      expect(shouldCountInSummary(pemberian), isFalse);
      expect(shouldCountInSummary(reimburseIncome), isFalse);
    });
  });
}

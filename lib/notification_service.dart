import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'data_model.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> Function(String? payload)? _onTapPayload;
  late final tz.Location _tz;

  Future<void> init({
    required Future<void> Function(String? payload) onTapPayload,
  }) async {
    _onTapPayload = onTapPayload;
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Gagal init timezone: $e');
    }

    // Auto-detect timezone dari sistem Android. Fallback Asia/Jakarta
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      _tz = tz.getLocation(tzInfo.identifier);
    } catch (e) {
      debugPrint('Gagal detect system timezone: $e');
      try {
        _tz = tz.getLocation('Asia/Jakarta');
      } catch (_) {
        _tz = tz.local;
      }
    }
    final androidInit = const AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    final iosInit = const DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) async {
          await _handleNotificationResponse(response);
        },
      );
    } catch (e) {
      debugPrint('Gagal init notifikasi: $e');
      // JANGAN return — plugin tetap bisa dipake
    }

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        await _handleNotificationResponse(details!.notificationResponse!);
      }
    } catch (e) {
      debugPrint('Gagal cek launch details: $e');
    }
  }

  Future<void> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestPermission();
  }

  Future<void> scheduleReminder(RecurringReminder reminder) async {
    if (!reminder.enabled) return;

    final int notificationId = reminder.id.hashCode;
    try {
      await cancelReminder(reminder.id);
    } catch (_) {}

    final notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring_reminder_channel',
        'Pengingat Rutin',
        channelDescription: 'Notifikasi untuk pengingat tagihan rutin',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Pengingat Rutin',
        styleInformation: BigTextStyleInformation(
          'Jangan lupa untuk membayar <b>${reminder.title}</b>, dan tap untuk mencatat transaksi tagihan otomatis.',
          htmlFormatBigText: true,
        ),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // Jadwal sesuai reminder
    tz.TZDateTime scheduledDate = _computeScheduledDate(reminder);
    if (scheduledDate.isBefore(tz.TZDateTime.now(_tz))) {
      scheduledDate = tz.TZDateTime.now(_tz).add(const Duration(seconds: 5));
    }

    // Map recurrence ke Android repeat component biar otomatis berulang
    DateTimeComponents? matchComponents;
    switch (reminder.recurrenceType) {
      case 'Harian':
        matchComponents = DateTimeComponents.time;
        break;
      case 'Mingguan':
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
      case 'Bulanan':
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        break;
      // Custom: interval variable, ga pake matchComponents — handle manual
      default:
        matchComponents = null;
    }

    try {
      await _plugin.zonedSchedule(
        notificationId,
        reminder.title,
        'Jangan lupa untuk membayar ${reminder.title}, dan tap untuk mencatat transaksi tagihan otomatis.',
        scheduledDate,
        notifDetails,
        payload: reminder.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      debugPrint('Gagal jadwalkan notifikasi: $e');
    }
  }

  tz.TZDateTime _computeScheduledDate(RecurringReminder reminder) {
    return tz.TZDateTime(
      _tz,
      reminder.nextDue.year,
      reminder.nextDue.month,
      reminder.nextDue.day,
      reminder.hour,
      reminder.minute,
    );
  }

  Future<void> cancelReminder(String id) async {
    try {
      await _plugin.cancel(id.hashCode);
    } catch (e) {
      debugPrint('Gagal membatalkan notifikasi: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Gagal membatalkan semua notifikasi: $e');
    }
  }

  Future<void> scheduleAllReminders() async {
    for (var reminder in daftarPengingatRutin) {
      try {
        await scheduleReminder(reminder);
      } catch (e) {
        debugPrint('Gagal menjadwalkan pengingat: $e');
      }
    }
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      await _onTapPayload?.call(payload);
    }
  }
}

Future<void> processRecurringReminder(String? payload) async {
  if (payload == null || payload.isEmpty) return;

  final matched = daftarPengingatRutin.where((r) => r.id == payload).toList();
  if (matched.isEmpty) return;
  final reminder = matched.first;

  final now = DateTime.now();
  daftarTransaksi.add(
    Transaksi(
      id: 'reminder_${reminder.id}_${now.millisecondsSinceEpoch}',
      nominal: reminder.nominal,
      catatan: reminder.title,
      tipe: 'Pengeluaran',
      kategori: reminder.kategori,
      akun: reminder.akun,
      tanggal: reminder.nextDue,
    ),
  );

  switch (reminder.recurrenceType) {
    case 'Harian':
      reminder.nextDue = reminder.nextDue.add(const Duration(days: 1));
      break;
    case 'Mingguan':
      reminder.nextDue = reminder.nextDue.add(const Duration(days: 7));
      break;
    case 'Custom':
      reminder.nextDue = reminder.nextDue.add(
        Duration(days: reminder.customIntervalDays),
      );
      break;
    default:
      reminder.nextDue = DateTime(
        reminder.nextDue.year,
        reminder.nextDue.month + 1,
        reminder.nextDue.day,
      );
  }

  saveData();
  await NotificationService.instance.scheduleReminder(reminder);
}

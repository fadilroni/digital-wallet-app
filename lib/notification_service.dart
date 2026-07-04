import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'data_model.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> Function(String? payload)? _onTapPayload;

  Future<void> init({
    required Future<void> Function(String? payload) onTapPayload,
  }) async {
    _onTapPayload = onTapPayload;
    tz.initializeTimeZones();
    final androidInit = const AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    final iosInit = const DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        await _handleNotificationResponse(response);
      },
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      await _handleNotificationResponse(details!.notificationResponse!);
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
    await cancelReminder(reminder.id);

    tz.TZDateTime scheduledDate = _computeScheduledDate(reminder);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5));
    }

    await _plugin.zonedSchedule(
      notificationId,
      'Pengingat Tagihan Rutin',
      'Tap untuk mencatat ${reminder.title} otomatis.',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminder_channel',
          'Pengingat Rutin',
          channelDescription: 'Notifikasi untuk pengingat tagihan rutin',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Pengingat Rutin',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: reminder.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  tz.TZDateTime _computeScheduledDate(RecurringReminder reminder) {
    final nextDue = reminder.nextDue;
    return tz.TZDateTime(
      tz.local,
      nextDue.year,
      nextDue.month,
      nextDue.day,
      9,
      0,
    );
  }

  Future<void> cancelReminder(String id) async {
    await _plugin.cancel(id.hashCode);
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  Future<void> scheduleAllReminders() async {
    for (var reminder in daftarPengingatRutin) {
      await scheduleReminder(reminder);
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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'data.dart';

/// Sale alerts with no server: every few hours Android wakes the app in the
/// background, it downloads brands.json and compares it with what it saw last
/// time. If a favourite brand started a sale, or its discount went up,
/// it shows a notification on the phone.
class Alerts {
  static const _task = 'check-sales';
  static final _notes = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;
    await _notes.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 4),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> askPermission() async {
    if (kIsWeb) return;
    await _notes
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Compares fresh brand data with the last snapshot; returns messages to show.
  static Future<List<(String, String)>> check({bool notify = true}) async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('alertsOn') ?? true)) return [];
    final favs = (p.getStringList('favBrands') ?? const []).toSet();

    final r = await http
        .get(Uri.parse('$dataUrl/brands.json'))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return [];
    final brands = (jsonDecode(utf8.decode(r.bodyBytes))['brands'] as List)
        .cast<Map<String, dynamic>>();

    final old = Map<String, dynamic>.from(
        jsonDecode(p.getString('lastSnapshot') ?? '{}') as Map);
    final snap = <String, dynamic>{};
    final msgs = <(String, String)>[];
    for (final b in brands) {
      final id = b['id'] as String;
      final onSale = (b['on_sale'] ?? 0) as int;
      final maxOff = (b['max_off'] ?? 0) as int;
      snap[id] = {'on_sale': onSale, 'max_off': maxOff};
      final before = old[id] as Map<String, dynamic>?;
      if (before == null || !favs.contains(id) || onSale == 0) continue;
      final wasOnSale = (before['on_sale'] ?? 0) as int;
      final wasMax = (before['max_off'] ?? 0) as int;
      if (wasOnSale == 0) {
        msgs.add(('${b['name']} sale is live! 🎉',
            '$onSale items, up to $maxOff% off'));
      } else if (maxOff >= wasMax + 10) {
        msgs.add(('${b['name']}: bigger discounts',
            'Now up to $maxOff% off (was $wasMax%)'));
      } else if (onSale >= wasOnSale * 2 && onSale - wasOnSale >= 50) {
        msgs.add(('${b['name']} added more to the sale',
            '$onSale items now discounted, up to $maxOff% off'));
      }
    }
    await p.setString('lastSnapshot', jsonEncode(snap));

    if (notify) {
      var n = 0;
      for (final (title, body) in msgs) {
        await _notes.show(
          id: n++,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'sales',
              'Sale alerts',
              channelDescription: 'When a favourite brand starts a sale',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }
    return msgs;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Alerts._notes.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await Alerts.check();
    } catch (_) {
      // try again next time
    }
    return true;
  });
}

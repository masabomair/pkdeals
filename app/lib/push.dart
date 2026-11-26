import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'alerts.dart';
import 'data.dart';

/// Push alerts (Firebase Cloud Messaging).
///
/// Each followed brand is a topic (`brand_<id>`). A GitHub job checks the
/// brands every 15 minutes and sends one message per topic when a sale starts
/// or its discount jumps, so phones hear about it within minutes, even when
/// the app is closed. The phone's own hourly check stays as a backup and goes
/// quiet once push is working (see Alerts.check), so alerts aren't doubled.
class Push {
  static bool _started = false;

  static String topic(String brandId) => 'brand_$brandId';

  static Future<void> init() async {
    if (kIsWeb || !Account.i.ready || _started) return;
    _started = true;
    try {
      final fm = FirebaseMessaging.instance;
      await Alerts.ensureChannel();

      // app open: Android doesn't show push notifications itself, so show it
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        final brand = m.data['brand'] as String? ?? '';
        if (n != null)
          Alerts.showPush(brand, n.title ?? 'Sale Mela', n.body ?? '');
      });
      // tapped while the app was in the background
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final b = m.data['brand'] as String?;
        if (b != null && b.isNotEmpty) Alerts.onOpenBrand?.call(b);
      });
      // tapped while the app was closed
      final first = await fm.getInitialMessage();
      final b = first?.data['brand'] as String?;
      if (b != null && b.isNotEmpty) {
        Future.delayed(
          const Duration(milliseconds: 800),
          () => Alerts.onOpenBrand?.call(b),
        );
      }
      await sync();
    } catch (e) {
      debugPrint('Push not available: $e');
    }
  }

  /// Subscribes to exactly the followed brands (none while alerts are off).
  static Future<void> sync() async {
    if (kIsWeb || !_started) return;
    final p = await SharedPreferences.getInstance();
    final want = Prefs.alertsOn ? Prefs.favBrands : <String>{};
    final have = (p.getStringList('pushTopics') ?? const []).toSet();
    final fm = FirebaseMessaging.instance;
    try {
      for (final id in want.difference(have)) {
        await fm.subscribeToTopic(topic(id));
      }
      for (final id in have.difference(want)) {
        await fm.unsubscribeFromTopic(topic(id));
      }
      await p.setStringList('pushTopics', want.toList());
      await p.setBool('pushActive', true);
    } catch (e) {
      // no Google Play services or no network: the hourly check still alerts
      await p.setBool('pushActive', false);
      debugPrint('Topic sync failed: $e');
    }
  }
}

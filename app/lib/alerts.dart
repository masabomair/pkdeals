import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'data.dart';

/// One notification to show.
class SaleAlert {
  final String brandId, title, body;
  const SaleAlert(this.brandId, this.title, this.body);
  @override
  String toString() => '$title — $body';
}

/// Pure rule: compares the last snapshot with fresh brand data and decides
/// which favourite brands deserve a notification. Kept free of plugins so it
/// can be unit-tested.
///
/// - a sale starts (0 items on sale before, some now)
/// - the biggest discount rises by 10 points or more
/// - the number of items on sale at least doubles (and grows by 50+)
/// Brands seen for the first time never alert (no "before" to compare).
List<SaleAlert> saleChanges(
  Map<String, dynamic> before,
  List<Map<String, dynamic>> brands,
  Set<String> favs,
) {
  final out = <SaleAlert>[];
  for (final b in brands) {
    final id = b['id'] as String;
    final name = b['name'] as String? ?? id;
    final onSale = (b['on_sale'] ?? 0) as int;
    final maxOff = (b['max_off'] ?? 0) as int;
    final old = before[id] as Map<String, dynamic>?;
    if (old == null || !favs.contains(id) || onSale == 0) continue;
    final wasOnSale = (old['on_sale'] ?? 0) as int;
    final wasMax = (old['max_off'] ?? 0) as int;
    if (wasOnSale == 0) {
      out.add(
        SaleAlert(
          id,
          '$name sale is live!',
          '${plain(onSale)} items on sale, up to $maxOff% off. Tap to see the deals.',
        ),
      );
    } else if (maxOff >= wasMax + 10) {
      out.add(
        SaleAlert(
          id,
          '$name: bigger discounts',
          'Now up to $maxOff% off (was $wasMax%). Tap to see the deals.',
        ),
      );
    } else if (onSale >= wasOnSale * 2 && onSale - wasOnSale >= 50) {
      out.add(
        SaleAlert(
          id,
          '$name added more to the sale',
          '${plain(onSale)} items now on sale, up to $maxOff% off.',
        ),
      );
    }
  }
  return out;
}

Map<String, dynamic> snapshotOf(List<Map<String, dynamic>> brands) => {
  for (final b in brands)
    b['id'] as String: {
      'on_sale': (b['on_sale'] ?? 0) as int,
      'max_off': (b['max_off'] ?? 0) as int,
    },
};

/// Sale alerts with no server: every hour Android wakes the app in the
/// background (and the app also checks each time it opens). It downloads
/// brands.json, compares it with what it saw last time, and notifies about
/// favourite brands whose sale started or got bigger.
class Alerts {
  static const _task = 'check-sales';
  static final _notes = FlutterLocalNotificationsPlugin();

  /// Set by the app: opens a brand's deals when its notification is tapped.
  static void Function(String brandId)? onOpenBrand;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sales',
      'Sale alerts',
      channelDescription:
          'When a brand you follow starts a sale or cuts prices further',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification', // white tag silhouette for the status bar
      color: Color(0xFFD4246B),
      styleInformation: DefaultStyleInformation(true, true),
    ),
  );

  static Future<void> _initPlugin({bool foreground = false}) =>
      _notes.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: foreground
            ? (r) {
                final id = r.payload;
                if (id != null && id.isNotEmpty) onOpenBrand?.call(id);
              }
            : null,
      );

  static Future<void> init() async {
    if (kIsWeb) return;
    await _initPlugin(foreground: true);
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      // update: phones that registered the old 4-hour check switch to hourly
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    // app was opened by tapping a notification
    final launch = await _notes.getNotificationAppLaunchDetails();
    final id = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        id != null &&
        id.isNotEmpty) {
      Future.delayed(
        const Duration(milliseconds: 800),
        () => onOpenBrand?.call(id),
      );
    }
  }

  static Future<bool> askPermission() async {
    if (kIsWeb) return false;
    return await _notes
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  static Future<void> _show(SaleAlert a) => _notes.show(
    id: a.brandId.hashCode & 0x7fffffff, // one notification per brand
    title: a.title,
    body: a.body,
    notificationDetails: _details,
    payload: a.brandId,
  );

  /// Downloads fresh data, notifies about changes, and saves the new snapshot.
  /// With alerts switched off the snapshot is still kept current, so turning
  /// them back on never announces old news.
  static Future<List<SaleAlert>> check({bool notify = true}) async {
    final p = await SharedPreferences.getInstance();
    final on = p.getBool('alertsOn') ?? true;
    final favs = (p.getStringList('favBrands') ?? const []).toSet();

    final r = await http
        .get(Uri.parse('$dataUrl/brands.json'))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) return [];
    final brands = (jsonDecode(utf8.decode(r.bodyBytes))['brands'] as List)
        .cast<Map<String, dynamic>>();

    final old = Map<String, dynamic>.from(
      jsonDecode(p.getString('lastSnapshot') ?? '{}') as Map,
    );
    final msgs = on ? saleChanges(old, brands, favs) : <SaleAlert>[];
    await p.setString('lastSnapshot', jsonEncode(snapshotOf(brands)));

    if (notify && !kIsWeb) {
      for (final a in msgs) {
        await _show(a);
      }
    }
    return msgs;
  }

  /// Shows a real notification right now, using live data of a followed brand
  /// (or the brand with the biggest sale), so people can see alerts work.
  static Future<bool> sendTest() async {
    if (kIsWeb) return false;
    final allowed = await askPermission();
    final s = Store.i;
    final favs = Prefs.favBrands;
    final pool = s.brands.where((b) => b.hasSale).toList();
    final b =
        pool.where((x) => favs.contains(x.id)).firstOrNull ?? pool.firstOrNull;
    final alert = b == null
        ? const SaleAlert(
            '',
            'Sale Mela alerts are on',
            "You'll be notified when a brand you follow starts a sale.",
          )
        : SaleAlert(
            b.id,
            '${b.name} sale is live!',
            '${plain(b.onSale)} items on sale, up to ${b.maxOff}% off. Tap to see the deals.',
          );
    await _show(alert);
    return allowed;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // plugins must be registered again in this background isolate
    DartPluginRegistrant.ensureInitialized();
    try {
      await Alerts._initPlugin();
      await Alerts.check();
    } catch (_) {
      // no network or data not ready; WorkManager tries again next period
    }
    return true;
  });
}

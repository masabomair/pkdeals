import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the collector publishes its JSON (GitHub Pages).
/// Override at build time with --dart-define=DATA_URL=...
const String dataUrl = String.fromEnvironment(
  'DATA_URL',
  defaultValue: 'https://masabomair.github.io/pkdeals/data',
);

class Brand {
  final String id, name, domain;
  final int onSale, maxOff, products;
  final String? checked, saleSince;

  Brand.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        domain = j['domain'],
        onSale = j['on_sale'] ?? 0,
        maxOff = j['max_off'] ?? 0,
        products = j['products'] ?? 0,
        checked = j['checked'],
        saleSince = j['sale_since'];

  bool get hasSale => onSale > 0;
}

class Deal {
  final String id, brand, title, url, gender, category;
  final String? image;
  final int price, was, off;
  final List<String> sizes;

  Deal.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        brand = j['brand'],
        title = j['title'],
        url = j['url'],
        image = j['image'],
        price = j['price'],
        was = j['was'],
        off = j['off'],
        gender = j['gender'],
        category = j['category'],
        sizes = List<String>.from(j['sizes'] ?? const []);
}

class BrandsResult {
  final DateTime? generated;
  final List<Brand> brands;
  BrandsResult(this.generated, this.brands);
}

class Api {
  static final _client = http.Client();
  static final Map<String, List<Deal>> _cache = {};

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await _client
        .get(Uri.parse('$dataUrl/$path'))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw Exception('Server returned ${r.statusCode}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<BrandsResult> brands() async {
    final j = await _get('brands.json');
    final list = (j['brands'] as List)
        .map((e) => Brand.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.onSale.compareTo(a.onSale));
    return BrandsResult(DateTime.tryParse(j['generated'] ?? ''), list);
  }

  static Future<List<Deal>> _deals(String path, {bool refresh = false}) async {
    if (!refresh && _cache.containsKey(path)) return _cache[path]!;
    final j = await _get(path);
    final list = (j['deals'] as List)
        .map((e) => Deal.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache[path] = list;
  }

  static Future<List<Deal>> topDeals({bool refresh = false}) =>
      _deals('top.json', refresh: refresh);

  static Future<List<Deal>> brandDeals(String id, {bool refresh = false}) =>
      _deals('deals/$id.json', refresh: refresh);
}

/// Favourite brands and saved items, kept on the phone.
class Prefs {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static Set<String> get favBrands =>
      (_p.getStringList('favBrands') ?? const []).toSet();
  static Future<void> toggleFavBrand(String id) async {
    final s = favBrands;
    s.contains(id) ? s.remove(id) : s.add(id);
    await _p.setStringList('favBrands', s.toList());
  }

  static List<Map<String, dynamic>> get savedDeals =>
      (_p.getStringList('saved') ?? const [])
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
  static bool isSaved(String id) => savedDeals.any((d) => d['id'] == id);
  static Future<void> toggleSaved(Deal d) async {
    final list = savedDeals;
    if (list.any((e) => e['id'] == d.id)) {
      list.removeWhere((e) => e['id'] == d.id);
    } else {
      list.insert(0, {
        'id': d.id, 'brand': d.brand, 'title': d.title, 'url': d.url,
        'image': d.image, 'price': d.price, 'was': d.was, 'off': d.off,
        'gender': d.gender, 'category': d.category, 'sizes': d.sizes,
      });
    }
    await _p.setStringList('saved', list.map(jsonEncode).toList());
  }

  static bool get alertsOn => _p.getBool('alertsOn') ?? true;
  static Future<void> setAlertsOn(bool v) => _p.setBool('alertsOn', v);
}

String rupees(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs $b';
}

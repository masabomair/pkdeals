import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final String? checked;

  Brand.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        domain = j['domain'],
        onSale = j['on_sale'] ?? 0,
        maxOff = j['max_off'] ?? 0,
        products = j['products'] ?? 0,
        checked = j['checked'];

  bool get hasSale => onSale > 0;
}

const _genders = {'W': 'Women', 'M': 'Men', 'K': 'Kids'};

class Deal {
  final String id, brand, title, url, gender, category;
  final String? image, kind, fabric;
  final int price, was, off;
  final int? pieces, firstSeen;
  final List<String> colors, sizes;

  Deal({
    required this.id, required this.brand, required this.title, required this.url,
    required this.gender, required this.category, this.image, this.kind, this.fabric,
    required this.price, required this.was, required this.off, this.pieces,
    this.firstSeen, this.colors = const [], this.sizes = const [],
  });

  int get saving => was - price;

  /// First seen in the last 24 hours (hours since epoch, set by the collector).
  bool get isNew {
    if (firstSeen == null) return false;
    final nowHour = DateTime.now().millisecondsSinceEpoch ~/ 3600000;
    return nowHour - firstSeen! < 24;
  }

  bool get isClothing => category == 'Ready to Wear' || category == 'Unstitched';

  Map<String, dynamic> toJson() => {
        'id': id, 'brand': brand, 'title': title, 'url': url, 'gender': gender,
        'category': category, 'image': image, 'kind': kind, 'fabric': fabric,
        'price': price, 'was': was, 'off': off, 'pieces': pieces,
        'first_seen': firstSeen, 'colors': colors, 'sizes': sizes,
      };

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
        id: j['id'], brand: j['brand'], title: j['title'], url: j['url'],
        gender: j['gender'] ?? 'Women', category: j['category'] ?? 'Ready to Wear',
        image: j['image'], kind: j['kind'], fabric: j['fabric'],
        price: j['price'], was: j['was'], off: j['off'], pieces: j['pieces'],
        firstSeen: j['first_seen'],
        colors: List<String>.from(j['colors'] ?? const []),
        sizes: List<String>.from(j['sizes'] ?? const []),
      );
}

List<Deal> _parseAll(Map<String, Object> args) {
  final j = jsonDecode(args['body'] as String) as Map<String, dynamic>;
  final domains = Map<String, String>.from(args['domains'] as Map);
  final cols = List<String>.from(j['cols']);
  int c(String n) => cols.indexOf(n);
  final iId = c('id'), iBrand = c('brand'), iTitle = c('title'), iPath = c('path'),
      iImg = c('image'), iPrice = c('price'), iWas = c('was'), iOff = c('off'),
      iG = c('gender'), iCat = c('category'), iKind = c('kind'), iPcs = c('pieces'),
      iFab = c('fabric'), iCol = c('colors'), iSz = c('sizes'), iSeen = c('first_seen');
  final out = <Deal>[];
  for (final r in (j['rows'] as List)) {
    final row = r as List;
    final brand = row[iBrand] as String;
    final path = row[iPath] as String;
    out.add(Deal(
      id: '$brand-${row[iId]}',
      brand: brand,
      title: row[iTitle] as String,
      url: path.startsWith('http') ? path : 'https://${domains[brand] ?? ''}$path',
      image: row[iImg] as String?,
      price: row[iPrice] as int,
      was: row[iWas] as int,
      off: row[iOff] as int,
      gender: _genders[row[iG]] ?? 'Women',
      category: row[iCat] as String,
      kind: row[iKind] as String?,
      pieces: row[iPcs] as int?,
      fabric: row[iFab] as String?,
      colors: List<String>.from(row[iCol] as List),
      sizes: List<String>.from(row[iSz] as List),
      firstSeen: iSeen >= 0 ? row[iSeen] as int? : null,
    ));
  }
  return out;
}

/// All app data: brands and every deal, loaded once and shared by screens.
class Store extends ChangeNotifier {
  static final Store i = Store._();
  Store._();

  List<Brand> brands = [];
  List<Deal> deals = [];
  Map<String, Brand> brandById = {};
  Map<String, Deal> dealById = {};
  DateTime? updated;
  bool loading = false;
  Object? error;
  bool serverError = false;

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$dataUrl/$path')).timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      serverError = true;
      throw Exception('Server returned ${r.statusCode}');
    }
    return {'body': utf8.decode(r.bodyBytes)};
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    serverError = false;
    notifyListeners();
    try {
      final b = jsonDecode((await _get('brands.json'))['body']) as Map<String, dynamic>;
      final list = (b['brands'] as List).map((e) => Brand.fromJson(e)).toList()
        ..sort((a, b) => b.onSale.compareTo(a.onSale));
      final domains = {for (final x in list) x.id: x.domain};
      final body = (await _get('all.json'))['body'] as String;
      final parsed = await compute(_parseAll, {'body': body, 'domains': domains});
      brands = list;
      brandById = {for (final x in list) x.id: x};
      deals = parsed;
      dealById = {for (final d in parsed) d.id: d};
      updated = DateTime.tryParse(b['generated'] ?? '');
    } catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  String brandName(String id) => brandById[id]?.name ?? id;
}

/// Favourite brands, saved items and settings, kept on the phone.
class Prefs {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static Set<String> get favBrands => (_p.getStringList('favBrands') ?? const []).toSet();
  static Future<void> toggleFavBrand(String id) async {
    final s = favBrands;
    s.contains(id) ? s.remove(id) : s.add(id);
    await _p.setStringList('favBrands', s.toList());
  }

  static List<Deal> get saved => (_p.getStringList('saved') ?? const [])
      .map((e) => Deal.fromJson(jsonDecode(e) as Map<String, dynamic>))
      .toList();
  static bool isSaved(String id) =>
      (_p.getStringList('saved') ?? const []).any((e) => e.contains('"id":"$id"'));
  static Future<void> toggleSaved(Deal d) async {
    final list = _p.getStringList('saved') ?? [];
    final i = list.indexWhere((e) => e.contains('"id":"${d.id}"'));
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.insert(0, jsonEncode(d.toJson()));
    }
    await _p.setStringList('saved', list);
  }

  static bool get alertsOn => _p.getBool('alertsOn') ?? true;
  static Future<void> setAlertsOn(bool v) => _p.setBool('alertsOn', v);

  static String get gender => _p.getString('gender') ?? 'All';
  static Future<void> setGender(String g) => _p.setString('gender', g);
}

// ---------------------------------------------------------------- filters

enum SortBy { off, saving, low, high, newest }

const sortLabels = {
  SortBy.off: 'Biggest discount',
  SortBy.saving: 'Most money saved',
  SortBy.low: 'Price: low to high',
  SortBy.high: 'Price: high to low',
  SortBy.newest: 'Newest first',
};

/// Price steps for the range slider (last step means "and above").
const priceSteps = [0, 500, 1000, 1500, 2000, 3000, 4000, 5000, 7000, 10000, 15000, 20000, 30000, 50000];

class Filters {
  String gender = 'All';
  String query = '';
  String? brand; // fixed brand (brand page)
  Set<String> types = {}; // empty = clothes (Ready to Wear + Unstitched)
  Set<String> kinds = {};
  Set<int> pieces = {};
  Set<String> fabrics = {};
  Set<String> colors = {};
  Set<String> brands = {};
  int minStep = 0, maxStep = priceSteps.length - 1;
  int minOff = 0;
  bool newOnly = false;
  SortBy sort = SortBy.off;

  Filters copy() => Filters()
    ..gender = gender
    ..query = query
    ..brand = brand
    ..types = {...types}
    ..kinds = {...kinds}
    ..pieces = {...pieces}
    ..fabrics = {...fabrics}
    ..colors = {...colors}
    ..brands = {...brands}
    ..minStep = minStep
    ..maxStep = maxStep
    ..minOff = minOff
    ..newOnly = newOnly
    ..sort = sort;

  /// Number of sheet filters in use (not gender, search or sort).
  int get count =>
      (types.isNotEmpty ? 1 : 0) + (kinds.isNotEmpty ? 1 : 0) + (pieces.isNotEmpty ? 1 : 0) +
      (fabrics.isNotEmpty ? 1 : 0) + (colors.isNotEmpty ? 1 : 0) + (brands.isNotEmpty ? 1 : 0) +
      (minStep > 0 || maxStep < priceSteps.length - 1 ? 1 : 0) + (minOff > 0 ? 1 : 0) +
      (newOnly ? 1 : 0);

  void clearSheet() {
    types = {};
    kinds = {};
    pieces = {};
    fabrics = {};
    colors = {};
    brands = {};
    minStep = 0;
    maxStep = priceSteps.length - 1;
    minOff = 0;
    newOnly = false;
  }

  bool matches(Deal d, {bool ignorePrice = false}) {
    if (brand != null && d.brand != brand) return false;
    if (gender != 'All' && d.gender != gender) return false;
    if (types.isEmpty ? !d.isClothing : !types.contains(d.category)) return false;
    if (kinds.isNotEmpty && !kinds.contains(d.kind)) return false;
    if (pieces.isNotEmpty && !pieces.contains(d.pieces)) return false;
    if (fabrics.isNotEmpty && !fabrics.contains(d.fabric)) return false;
    if (colors.isNotEmpty && !d.colors.any(colors.contains)) return false;
    if (brands.isNotEmpty && !brands.contains(d.brand)) return false;
    if (d.off < minOff) return false;
    if (newOnly && !d.isNew) return false;
    if (!ignorePrice) {
      if (d.price < priceSteps[minStep]) return false;
      if (maxStep < priceSteps.length - 1 && d.price > priceSteps[maxStep]) return false;
    }
    if (query.isNotEmpty) {
      final hay = '${d.title} ${d.fabric ?? ''} ${d.kind ?? ''} ${Store.i.brandName(d.brand)}'.toLowerCase();
      for (final w in query.toLowerCase().split(RegExp(r'\s+'))) {
        if (w.isNotEmpty && !hay.contains(w)) return false;
      }
    }
    return true;
  }

  List<Deal> apply(List<Deal> all) {
    final out = all.where(matches).toList();
    switch (sort) {
      case SortBy.saving:
        out.sort((a, b) => b.saving.compareTo(a.saving));
      case SortBy.low:
        out.sort((a, b) => a.price.compareTo(b.price));
      case SortBy.high:
        out.sort((a, b) => b.price.compareTo(a.price));
      case SortBy.newest:
        out.sort((a, b) => (b.firstSeen ?? 0).compareTo(a.firstSeen ?? 0));
      case SortBy.off:
        out.sort((a, b) => b.off != a.off ? b.off.compareTo(a.off) : b.saving.compareTo(a.saving));
    }
    return out;
  }
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

String plain(int v) => rupees(v).substring(3);

String ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

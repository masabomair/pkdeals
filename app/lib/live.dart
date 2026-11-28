import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data.dart';

/// What the brand's own website says about a product right now.
class LiveInfo {
  final bool inStock; // any size available
  final bool onSale; // an available size is still discounted
  final int? price, was;
  final List<String> sizes; // sizes in stock
  final List<String> images;
  const LiveInfo({
    required this.inStock,
    required this.onSale,
    this.price,
    this.was,
    this.sizes = const [],
    this.images = const [],
  });

  int? get off => (price != null && was != null && was! > 0)
      ? ((was! - price!) * 100 / was!).round()
      : null;
}

final _cache = <String, LiveInfo>{};
final _sizeOpt = RegExp(r'size|\bage\b|waist', caseSensitive: false);
final _notSize = RegExp(
  r'colou?r|shade|fabric|material|title|style|piece',
  caseSensitive: false,
);

/// Asks the brand's Shopify store for the product (its public `.js` feed)
/// when it is opened, so a sold-out item or a changed price shows at once
/// instead of at the next data refresh. Returns null when it can't tell
/// (no network, a non-Shopify brand, or the web version, where browsers
/// block reading other sites).
Future<LiveInfo?> liveCheck(Deal d) async {
  if (kIsWeb) return null;
  final uri = Uri.tryParse(d.url);
  if (uri == null ||
      !uri.path.contains('/products/') ||
      uri.path.endsWith('.html'))
    return null;
  final cached = _cache[d.id];
  if (cached != null) return cached;
  try {
    final r = await http
        .get(
          uri.replace(path: '${uri.path}.js', query: ''),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 404) {
      // product removed from the store
      return _cache[d.id] = const LiveInfo(inStock: false, onSale: false);
    }
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return _cache[d.id] = parseLive(j);
  } catch (_) {
    return null;
  }
}

/// Reads a Shopify product feed (`/products/<handle>.js`).
LiveInfo parseLive(Map<String, dynamic> j) {
  final variants = (j['variants'] as List? ?? const [])
      .cast<Map<String, dynamic>>();

  // which option is the size
  final rawOpts = (j['options'] as List? ?? const []);
  final names = [for (final o in rawOpts) o is Map ? '${o['name']}' : '$o'];
  var sizeIdx = names.indexWhere((n) => _sizeOpt.hasMatch(n));
  if (sizeIdx < 0 && names.length == 1 && !_notSize.hasMatch(names[0]))
    sizeIdx = 0;

  var inStock = false, onSale = false;
  int? salePrice, saleWas, fullPrice;
  final sizes = <String>[];
  int cents(dynamic v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
  for (final v in variants) {
    if (v['available'] != true) continue;
    inStock = true;
    final price = cents(v['price']) ~/ 100;
    final was = cents(v['compare_at_price']) ~/ 100;
    if (was > price && price > 0) {
      onSale = true;
      // keep the deepest discount among the sizes in stock
      if (salePrice == null ||
          (was - price) / was > (saleWas! - salePrice) / saleWas) {
        salePrice = price;
        saleWas = was;
      }
    } else {
      fullPrice ??= price;
    }
    if (sizeIdx >= 0) {
      final s = '${v['option${sizeIdx + 1}'] ?? ''}'.trim();
      if (s.isNotEmpty && s != 'Default Title' && !sizes.contains(s))
        sizes.add(s);
    }
  }
  final images = <String>[
    for (final i in (j['images'] as List? ?? const []))
      if (i is String && i.isNotEmpty)
        '${i.startsWith('//') ? 'https:$i' : i}${i.contains('?') ? '&' : '?'}width=1200',
  ];
  return LiveInfo(
    inStock: inStock,
    onSale: onSale,
    price: onSale ? salePrice : fullPrice,
    was: onSale ? saleWas : null,
    sizes: sizes,
    images: images,
  );
}

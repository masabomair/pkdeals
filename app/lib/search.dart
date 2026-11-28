import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'ui.dart';

/// What the person picked on the search screen.
class SearchPick {
  final String? query; // plain text search
  final String? brandId; // open this brand
  final void Function(Filters)? apply; // a category: set this filter
  const SearchPick({this.query, this.brandId, this.apply});
}

class _Cat {
  final String label, group;
  final bool Function(Deal) test;
  final void Function(Filters) apply;
  const _Cat(this.label, this.group, this.test, this.apply);
}

const _stop = {
  'the',
  'and',
  'with',
  'for',
  'pcs',
  'piece',
  'pieces',
  'pc',
  'new',
  'by',
  'of',
  'in',
  'on',
  'set',
  'off',
  'sale',
  'per',
  'stitched',
  'women',
  'men',
  'kids',
  'boys',
  'girls',
  'mens',
  'womens',
  'ladies',
};

List<_Cat> _categories() => [
  for (final g in const ['Women', 'Men', 'Kids'])
    _Cat(g, 'Shopping for', (d) => d.gender == g, (f) => f.gender = g),
  _Cat(
    'Pret / Ready to Wear',
    'Type',
    (d) => d.category == 'Ready to Wear',
    (f) => f.types = {'Ready to Wear'},
  ),
  _Cat(
    'Unstitched',
    'Type',
    (d) => d.category == 'Unstitched',
    (f) => f.types = {'Unstitched'},
  ),
  for (final k in kindOrder)
    _Cat(k, 'Garment', (d) => d.kind == k, (f) => f.kinds = {k}),
  for (final p in const [1, 2, 3])
    _Cat('$p Piece', 'Pieces', (d) => d.pieces == p, (f) => f.pieces = {p}),
  for (final x in fabricOrder)
    _Cat(x, 'Fabric', (d) => d.fabric == x, (f) => f.fabrics = {x}),
  for (final c in colorNames)
    _Cat(c, 'Colour', (d) => d.colors.contains(c), (f) => f.colors = {c}),
];

/// Words and two-word phrases from product names, with how many deals use them.
class _Terms {
  static Object? _builtFor;
  static List<MapEntry<String, int>> _terms = [];

  static List<MapEntry<String, int>> of(List<Deal> deals) {
    if (identical(_builtFor, deals)) return _terms;
    final counts = <String, int>{};
    final word = RegExp(r'[a-z]+');
    for (final d in deals) {
      final w = word
          .allMatches(d.title.toLowerCase())
          .map((m) => m.group(0)!)
          .toList();
      final seen = <String>{};
      for (var i = 0; i < w.length; i++) {
        if (w[i].length >= 3 && !_stop.contains(w[i])) seen.add(w[i]);
        if (i + 1 < w.length &&
            w[i].length >= 3 &&
            w[i + 1].length >= 3 &&
            !_stop.contains(w[i]) &&
            !_stop.contains(w[i + 1])) {
          seen.add('${w[i]} ${w[i + 1]}');
        }
      }
      for (final t in seen) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    _terms = counts.entries.where((e) => e.value >= 3).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _builtFor = deals;
    return _terms;
  }
}

Future<SearchPick?> openSearch(
  BuildContext context, {
  Brand? brand,
  String initial = '',
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => SearchScreen(brand: brand, initial: initial),
  ),
);

class SearchScreen extends StatefulWidget {
  final Brand? brand; // search inside one brand
  final String initial;
  const SearchScreen({super.key, this.brand, this.initial = ''});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _c = TextEditingController(text: widget.initial);
  List<String> _recent = [];

  List<Deal> get _pool => widget.brand == null
      ? Store.i.deals
      : Store.i.deals.where((d) => d.brand == widget.brand!.id).toList();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (p) => setState(() => _recent = p.getStringList('recent') ?? []),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _remember(String q) async {
    final p = await SharedPreferences.getInstance();
    final list = [
      q,
      ...(p.getStringList('recent') ?? []).where((x) => x != q),
    ].take(8).toList();
    await p.setStringList('recent', list);
  }

  void _pickQuery(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    _remember(q);
    Navigator.pop(context, SearchPick(query: q));
  }

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final q = _c.text.trim().toLowerCase();
    final pool = _pool;

    Widget head(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        t.toUpperCase(),
        style: TextStyle(
          color: r.muted,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: .8,
        ),
      ),
    );
    Widget count(int n) => Text(
      '${plain(n)} deals',
      style: TextStyle(color: r.muted, fontSize: 12.5),
    );
    // the typed part in normal weight, the rest bold, like most search boxes
    Widget highlight(String text) {
      final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
      if (i < 0)
        return Text(text, style: TextStyle(color: r.ink, fontSize: 15));
      return Text.rich(
        TextSpan(
          style: TextStyle(color: r.ink, fontSize: 15),
          children: [
            TextSpan(
              text: text.substring(0, i),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.substring(i, i + q.length)),
            TextSpan(
              text: text.substring(i + q.length),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    if (q.isEmpty) {
      if (_recent.isNotEmpty) {
        children.add(
          Row(
            children: [
              Expanded(child: head('Recent searches')),
              TextButton(
                onPressed: () async {
                  final p = await SharedPreferences.getInstance();
                  await p.remove('recent');
                  setState(() => _recent = []);
                },
                child: Text(
                  'Clear',
                  style: TextStyle(color: r.pink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _recent)
                  ActionChip(
                    avatar: Icon(Icons.history, size: 16, color: r.muted),
                    label: Text(t),
                    onPressed: () => _pickQuery(t),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ),
        );
      }
      children.add(head('Popular right now'));
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _Terms.of(
                pool,
              ).where((e) => !e.key.contains(' ')).take(12))
                ActionChip(
                  label: Text(t.key),
                  onPressed: () => _pickQuery(t.key),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ),
      );
      if (widget.brand == null) {
        final top = Store.i.brands.where((b) => b.hasSale).take(8);
        children.add(head('Biggest sales'));
        for (final b in top) {
          children.add(
            ListTile(
              leading: Monogram(b.id, b.name, size: 38),
              title: Text(
                b.name,
                style: TextStyle(fontWeight: FontWeight.w600, color: r.ink),
              ),
              subtitle: Text(
                '${plain(b.onSale)} on sale · up to ${b.maxOff}% off',
                style: TextStyle(color: r.muted, fontSize: 12.5),
              ),
              onTap: () => Navigator.pop(context, SearchPick(brandId: b.id)),
            ),
          );
        }
      }
    } else {
      // brands
      if (widget.brand == null) {
        final brands =
            Store.i.brands
                .where((b) => b.hasSale && b.name.toLowerCase().contains(q))
                .toList()
              ..sort(
                (a, b) =>
                    (b.name.toLowerCase().startsWith(q) ? 1 : 0) -
                    (a.name.toLowerCase().startsWith(q) ? 1 : 0),
              );
        if (brands.isNotEmpty) {
          children.add(head('Brands'));
          for (final b in brands.take(5)) {
            children.add(
              ListTile(
                leading: Monogram(b.id, b.name, size: 38),
                title: highlight(b.name),
                subtitle: Text(
                  '${plain(b.onSale)} on sale · up to ${b.maxOff}% off',
                  style: TextStyle(color: r.muted, fontSize: 12.5),
                ),
                trailing: Icon(Icons.chevron_right, color: r.muted),
                onTap: () => Navigator.pop(context, SearchPick(brandId: b.id)),
              ),
            );
          }
        }
      }
      // categories
      final cats = <(_Cat, int)>[];
      for (final c in _categories()) {
        final l = c.label.toLowerCase();
        if (!(l.startsWith(q) ||
            l.contains(' $q') ||
            l.contains('/$q') ||
            l.contains(q) && q.length >= 3))
          continue;
        final n = pool.where(c.test).length;
        if (n > 0) cats.add((c, n));
      }
      if (cats.isNotEmpty) {
        children.add(head('Categories'));
        for (final (c, n) in cats.take(5)) {
          children.add(
            ListTile(
              leading: CircleAvatar(
                backgroundColor: r.soft,
                child: Icon(Icons.sell_outlined, color: r.pink, size: 20),
              ),
              title: highlight(c.label),
              subtitle: Text(
                c.group,
                style: TextStyle(color: r.muted, fontSize: 12.5),
              ),
              trailing: count(n),
              onTap: () {
                _remember(c.label);
                Navigator.pop(context, SearchPick(apply: c.apply));
              },
            ),
          );
        }
      }
      // words from product names
      final terms = _Terms.of(pool)
          .where((e) => e.key.startsWith(q) || e.key.contains(' $q'))
          .take(7)
          .toList();
      children.add(head('Search for'));
      children.add(
        ListTile(
          leading: Icon(Icons.search, color: r.ink),
          title: Text(
            '"${_c.text.trim()}"',
            style: TextStyle(color: r.ink, fontWeight: FontWeight.w700),
          ),
          trailing: count(
            pool
                .where(
                  (d) =>
                      '${d.title} ${d.fabric ?? ''} ${d.kind ?? ''} ${Store.i.brandName(d.brand)}'
                          .toLowerCase()
                          .contains(q),
                )
                .length,
          ),
          onTap: () => _pickQuery(_c.text),
        ),
      );
      for (final t in terms) {
        if (t.key == q) continue;
        children.add(
          ListTile(
            leading: Icon(Icons.north_west, color: r.muted, size: 20),
            title: highlight(t.key),
            trailing: count(t.value),
            onTap: () => _pickQuery(t.key),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: r.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: _pickQuery,
          style: TextStyle(color: r.ink, fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.brand == null
                ? 'Search brands, fabrics, kurtas…'
                : 'Search ${widget.brand!.name}',
            hintStyle: TextStyle(color: r.muted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_c.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_c.clear),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: r.line),
        ),
      ),
      body: Centered(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: children,
        ),
      ),
    );
  }
}

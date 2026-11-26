import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alerts.dart';
import 'data.dart';
import 'ui.dart';

// ---------------------------------------------------------------- deals (home + brand page)

class _Tile {
  final String label;
  final bool Function(Filters) isOn;
  final void Function(Filters, bool) set;
  const _Tile(this.label, this.isOn, this.set);
}

void _setIn<T>(Set<T> s, T v, bool on) => on ? s.add(v) : s.remove(v);

final _tiles = <_Tile>[
  _Tile('New today', (f) => f.newOnly, (f, on) => f.newOnly = on),
  _Tile('Lawn', (f) => f.fabrics.contains('Lawn'), (f, on) => _setIn(f.fabrics, 'Lawn', on)),
  _Tile('Khaddar', (f) => f.fabrics.contains('Khaddar'), (f, on) => _setIn(f.fabrics, 'Khaddar', on)),
  _Tile('Pret', (f) => f.types.contains('Ready to Wear'), (f, on) => _setIn(f.types, 'Ready to Wear', on)),
  _Tile('Unstitched', (f) => f.types.contains('Unstitched'), (f, on) => _setIn(f.types, 'Unstitched', on)),
  _Tile('3 Piece', (f) => f.pieces.contains(3), (f, on) => _setIn(f.pieces, 3, on)),
  _Tile('Kurtas & Tops', (f) => f.kinds.contains('Shirts & Tops'), (f, on) => _setIn(f.kinds, 'Shirts & Tops', on)),
  _Tile('Bottoms', (f) => f.kinds.contains('Bottoms'), (f, on) => _setIn(f.kinds, 'Bottoms', on)),
  _Tile('Under Rs 2,000', (f) => f.maxStep == 4 && f.minStep == 0,
      (f, on) => f.maxStep = on ? 4 : priceSteps.length - 1),
  _Tile('Cambric', (f) => f.fabrics.contains('Cambric'), (f, on) => _setIn(f.fabrics, 'Cambric', on)),
];

class DealsScreen extends StatefulWidget {
  final Brand? brand;
  final VoidCallback? onAlerts;
  const DealsScreen({super.key, this.brand, this.onAlerts});
  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  late final Filters f = Filters()
    ..gender = widget.brand == null ? Prefs.gender : 'All'
    ..brand = widget.brand?.id;
  final _search = TextEditingController();
  Timer? _debounce;
  int _limit = 60;
  List<Deal> _results = [];
  int _dataVersion = -1;
  int _filterVersion = 0, _builtFilterVersion = -1;

  bool get _home => widget.brand == null;

  @override
  void initState() {
    super.initState();
    Store.i.addListener(_onStore);
  }

  @override
  void dispose() {
    Store.i.removeListener(_onStore);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onStore() => setState(() {});

  void _changed() => setState(() {
        _filterVersion++;
        _limit = 60;
      });

  List<Deal> get results {
    final v = identityHashCode(Store.i.deals);
    if (v != _dataVersion || _builtFilterVersion != _filterVersion) {
      _results = f.apply(Store.i.deals);
      _dataVersion = v;
      _builtFilterVersion = _filterVersion;
    }
    return _results;
  }

  Future<void> _openFilters() async {
    final pool = Store.i.deals;
    final res = await showFilters(context, f, pool);
    if (res == null) return;
    f
      ..types = res.types
      ..kinds = res.kinds
      ..pieces = res.pieces
      ..fabrics = res.fabrics
      ..colors = res.colors
      ..brands = res.brands
      ..minStep = res.minStep
      ..maxStep = res.maxStep
      ..minOff = res.minOff
      ..newOnly = res.newOnly;
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final s = Store.i;
    final list = results;
    final browsing = _home && f.query.isEmpty && f.count == 0;
    final live = s.brands.where((b) => b.hasSale).toList();

    return Scaffold(
      body: RefreshIndicator(
        color: r.pink,
        onRefresh: s.load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 1200 && _limit < list.length) setState(() => _limit += 60);
            return false;
          },
          child: CustomScrollView(slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: r.bg,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: _home
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset('assets/icon/rounded.png', width: 34, height: 34),
                      ),
                      const SizedBox(width: 10),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'SALE ', style: TextStyle(color: r.ink)),
                        TextSpan(text: 'MELA', style: TextStyle(color: r.pink)),
                      ]), style: GoogleFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 25, height: 1.1)),
                    ])
                  : Row(children: [
                      Monogram(widget.brand!.id, widget.brand!.name, size: 30),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(widget.brand!.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800, color: r.ink)),
                      ),
                    ]),
              actions: [
                if (_home)
                  IconButton(
                    tooltip: 'Sale alerts',
                    onPressed: widget.onAlerts,
                    icon: Icon(Icons.notifications_none_rounded, color: r.ink),
                  )
                else
                  IconButton(
                    tooltip: 'Open ${widget.brand!.name} website',
                    onPressed: () => launchUrl(Uri.parse('https://${widget.brand!.domain}'),
                        mode: LaunchMode.externalApplication),
                    icon: Icon(Icons.open_in_new, color: r.ink),
                  ),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: GenderSwitch(
                  value: f.gender,
                  onChanged: (g) {
                    f.gender = g;
                    if (_home) Prefs.setGender(g);
                    _changed();
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(child: _searchRow(r, s)),
            if (browsing && live.isNotEmpty) ...[
              SliverToBoxAdapter(child: _sectionHead(r, 'Sales live now', '${live.length} brands')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: live.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (c, i) {
                      final b = live[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DealsScreen(brand: b))),
                        child: SizedBox(
                          width: 62,
                          child: Column(children: [
                            Monogram(b.id, b.name, size: 50, ring: true),
                            const SizedBox(height: 5),
                            Text(b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r.ink)),
                            Text('${b.maxOff}%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: r.pink)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_home || f.count > 0) SliverToBoxAdapter(child: _tilesRow(r)),
            SliverToBoxAdapter(child: _resultsHead(r, list.length)),
            if (s.deals.isEmpty && s.loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (s.deals.isEmpty && s.error != null)
              SliverFillRemaining(hasScrollBody: false, child: _errorView(r, s))
            else if (list.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _emptyView(r))
            else
              DealGrid(deals: list, limit: _limit, showBrand: _home),
          ]),
        ),
      ),
    );
  }

  Widget _searchRow(RC r, Store s) {
    final n = f.count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                f.query = v.trim();
                _changed();
              });
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: _home
                  ? (s.deals.isEmpty ? 'Search deals' : 'Search ${plain(s.deals.length)} deals')
                  : 'Search ${widget.brand!.name}',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: f.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        f.query = '';
                        _changed();
                      }),
              filled: true,
              fillColor: r.field,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          backgroundColor: r.pink,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              foregroundColor: r.ink,
              side: BorderSide(color: n > 0 ? r.ink : r.line, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: s.deals.isEmpty ? null : _openFilters,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Filters'),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(RC r, String title, String? note) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: r.ink)),
          const Spacer(),
          if (note != null) Text(note, style: TextStyle(color: r.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ]),
      );

  Widget _tilesRow(RC r) => SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          itemCount: _tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, i) {
            final t = _tiles[i];
            final on = t.isOn(f);
            return Material(
              color: on ? r.pink : r.soft,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  t.set(f, !on);
                  _changed();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (on) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check, size: 15, color: Colors.white)),
                      Text(t.label,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : r.pink)),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _resultsHead(RC r, int n) {
    final title = f.query.isNotEmpty || f.count > 0
        ? '${plain(n)} deals'
        : (_home ? 'Biggest drops' : '${plain(n)} deals');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 4),
      child: Row(children: [
        Flexible(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: r.ink)),
        ),
        if (f.count > 0)
          TextButton(
            onPressed: () {
              f.clearSheet();
              _changed();
            },
            child: Text('Clear filters', style: TextStyle(color: r.pink, fontWeight: FontWeight.w700)),
          ),
        const Spacer(),
        PopupMenuButton<SortBy>(
          tooltip: 'Sort',
          initialValue: f.sort,
          onSelected: (v) {
            f.sort = v;
            _changed();
          },
          itemBuilder: (_) => [
            for (final e in sortLabels.entries) CheckedPopupMenuItem(value: e.key, checked: f.sort == e.key, child: Text(e.value)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert, size: 18, color: r.muted),
              const SizedBox(width: 4),
              Text(sortLabels[f.sort]!, style: TextStyle(color: r.ink, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _emptyView(RC r) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 44, color: r.muted),
          const SizedBox(height: 12),
          Text('No deals match', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: r.ink)),
          const SizedBox(height: 4),
          Text('Try fewer filters or a different search.',
              textAlign: TextAlign.center, style: TextStyle(color: r.muted)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: r.pink),
            onPressed: () {
              _search.clear();
              f
                ..query = ''
                ..clearSheet();
              _changed();
            },
            child: const Text('Clear search and filters'),
          ),
        ]),
      );
}

Widget _errorView(RC r, Store s) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.serverError ? Icons.cloud_off : Icons.wifi_off, size: 44, color: r.muted),
        const SizedBox(height: 12),
        Text(
            s.serverError
                ? 'Deals are being updated. Please try again in a few minutes.'
                : "Couldn't load deals. Check your internet connection.",
            textAlign: TextAlign.center,
            style: TextStyle(color: r.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: r.pink), onPressed: s.load, child: const Text('Try again')),
      ]),
    );

// ---------------------------------------------------------------- brands

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});
  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  String q = '';

  @override
  void initState() {
    super.initState();
    Store.i.addListener(_on);
  }

  @override
  void dispose() {
    Store.i.removeListener(_on);
    super.dispose();
  }

  void _on() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final s = Store.i;
    final favs = Prefs.favBrands;
    final match = s.brands.where((b) => b.name.toLowerCase().contains(q.toLowerCase())).toList();
    final on = match.where((b) => b.hasSale).toList();
    final off = match.where((b) => !b.hasSale).toList()..sort((a, b) => a.name.compareTo(b.name));
    final top = on.isEmpty ? 1 : on.first.onSale;

    Widget row(Brand b) {
      final fav = favs.contains(b.id);
      return InkWell(
        onTap: b.hasSale
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DealsScreen(brand: b)))
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            Monogram(b.id, b.name, size: 42, grey: !b.hasSale),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: r.ink)),
                const SizedBox(height: 2),
                if (b.hasSale) ...[
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${plain(b.onSale)} on sale', style: TextStyle(color: r.green, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' · up to ${b.maxOff}% off'),
                  ]), style: TextStyle(fontSize: 12.5, color: r.muted)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: b.onSale / top,
                      minHeight: 4,
                      backgroundColor: r.line,
                      color: r.pink,
                    ),
                  ),
                ] else
                  Text(fav ? "We'll tell you when the sale starts" : 'No sale right now',
                      style: TextStyle(fontSize: 12.5, color: r.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Switch(
                value: fav,
                activeThumbColor: Colors.white,
                activeTrackColor: r.pink,
                onChanged: (_) async {
                  if (!fav) await Alerts.askPermission();
                  await Prefs.toggleFavBrand(b.id);
                  setState(() {});
                },
              ),
              Text('Alert', style: TextStyle(fontSize: 10.5, color: r.muted, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: r.pink,
        onRefresh: s.load,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: r.bg,
            surfaceTintColor: Colors.transparent,
            title: Text('Brands', style: TextStyle(fontWeight: FontWeight.w800, color: r.ink)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search ${s.brands.length} brands',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: r.field,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Turn on Alert to get a notification when a brand starts a sale or cuts prices further.',
                    style: TextStyle(color: r.muted, fontSize: 12.5)),
              ]),
            ),
          ),
          if (s.brands.isEmpty && s.error != null)
            SliverFillRemaining(hasScrollBody: false, child: _errorView(r, s))
          else if (s.brands.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else ...[
            if (on.isNotEmpty) SliverToBoxAdapter(child: _groupHead(r, 'Sale on · ${on.length}')),
            SliverList.builder(itemCount: on.length, itemBuilder: (c, i) => row(on[i])),
            if (off.isNotEmpty) SliverToBoxAdapter(child: _groupHead(r, 'No sale right now · ${off.length}')),
            SliverList.builder(itemCount: off.length, itemBuilder: (c, i) => row(off[i])),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ]),
      ),
    );
  }
}

Widget _groupHead(RC r, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t.toUpperCase(),
          style: TextStyle(color: r.muted, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: .8)),
    );

// ---------------------------------------------------------------- saved

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    Store.i.addListener(_on);
  }

  @override
  void dispose() {
    Store.i.removeListener(_on);
    super.dispose();
  }

  void _on() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final s = Store.i;
    final saved = Prefs.saved;
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: r.bg,
          surfaceTintColor: Colors.transparent,
          title: Text('Saved', style: TextStyle(fontWeight: FontWeight.w800, color: r.ink)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(color: r.soft, borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                value: Prefs.alertsOn,
                activeThumbColor: Colors.white,
                activeTrackColor: r.pink,
                title: Text('Sale alerts', style: TextStyle(fontWeight: FontWeight.w700, color: r.ink)),
                subtitle: Text('${Prefs.favBrands.length} brands chosen in the Brands tab',
                    style: TextStyle(color: r.muted, fontSize: 12.5)),
                onChanged: (v) async {
                  if (v) await Alerts.askPermission();
                  await Prefs.setAlertsOn(v);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
        if (saved.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_border, size: 44, color: r.pink),
                const SizedBox(height: 12),
                Text('Nothing saved yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: r.ink)),
                const SizedBox(height: 4),
                Text('Tap ♡ on any deal to keep it here. We show you if its price drops or the sale ends.',
                    textAlign: TextAlign.center, style: TextStyle(color: r.muted)),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: w > 900 ? 5 : w > 600 ? 3 : 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: 0.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (c, i) {
                  final old = saved[i];
                  final now = s.dealById[old.id];
                  String? status;
                  if (s.deals.isNotEmpty && now == null) {
                    status = 'SALE ENDED';
                  } else if (now != null && now.price < old.price) {
                    status = 'PRICE DROPPED';
                  }
                  return DealCard(deal: now ?? old, status: status, onSavedChanged: () => setState(() {}));
                },
                childCount: saved.length,
              ),
            ),
          ),
      ]),
    );
  }
}

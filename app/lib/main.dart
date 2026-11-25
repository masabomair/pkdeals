import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alerts.dart';
import 'data.dart';

const _seed = Color(0xFF0F6E5A);
const _saleRed = Color(0xFFD7263D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  try {
    await Alerts.init();
  } catch (_) {}
  runApp(const DealsApp());
}

class DealsApp extends StatelessWidget {
  const DealsApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sale Wala',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomeShell(),
      );
}

// ---------------------------------------------------------------- shell

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  List<Brand> _brands = [];
  DateTime? _updated;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    // record a baseline so alerts only fire for changes after install
    Alerts.check(notify: false).catchError((_) => <(String, String)>[]);
  }

  Future<void> _loadBrands() async {
    try {
      final r = await Api.brands();
      setState(() {
        _brands = r.brands;
        _updated = r.generated;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DealsPage(brands: _brands, updated: _updated, onRefresh: _loadBrands),
      BrandsPage(brands: _brands, error: _error, onRefresh: _loadBrands),
      SavedPage(brands: _brands),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Top deals'),
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Brands'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Saved'),
        ],
      ),
    );
  }
}

String brandName(List<Brand> brands, String id) =>
    brands.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? id;

String ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

// ---------------------------------------------------------------- filters

class Filters {
  String gender = 'All';
  String category = 'Clothes';
  String kind = 'All';
  int pieces = 0;
  String color = 'Any';
  int minOff = 0;
  String sort = 'off';
  String query = '';

  static const genders = ['All', 'Women', 'Men', 'Kids'];
  static const categories = [
    'Clothes', 'Ready to Wear', 'Unstitched', 'Footwear',
    'Bags & Accessories', 'Fragrance & Beauty', 'Home', 'Everything',
  ];
  static const kinds = [
    'All', 'Suits & Sets', 'Shirts & Tops', 'Bottoms', 'Outerwear',
    'Dupattas & Shawls',
  ];
  static const piecesList = [0, 1, 2, 3];
  static const colors = <String, Color>{
    'Any': Colors.transparent,
    'Black': Color(0xFF1B1B1B),
    'White': Color(0xFFFFFFFF),
    'Beige': Color(0xFFE6D5B8),
    'Grey': Color(0xFF9E9E9E),
    'Brown': Color(0xFF7B4A2A),
    'Red': Color(0xFFD32F2F),
    'Maroon': Color(0xFF7B1C2E),
    'Pink': Color(0xFFEC7FA9),
    'Purple': Color(0xFF8E5CC4),
    'Blue': Color(0xFF2F6BD8),
    'Green': Color(0xFF3E8E41),
    'Yellow': Color(0xFFF2C230),
    'Orange': Color(0xFFF07F2E),
    'Multi': Colors.transparent,
  };
  static const offs = [0, 30, 50, 70];

  bool get any =>
      gender != 'All' || category != 'Clothes' || kind != 'All' ||
      pieces != 0 || color != 'Any' || minOff != 0;

  void reset() {
    gender = 'All';
    category = 'Clothes';
    kind = 'All';
    pieces = 0;
    color = 'Any';
    minOff = 0;
  }

  List<Deal> apply(List<Deal> all) {
    final q = query.trim().toLowerCase();
    final out = all.where((d) {
      if (gender != 'All' && d.gender != gender) return false;
      if (category == 'Clothes') {
        if (d.category != 'Ready to Wear' && d.category != 'Unstitched') {
          return false;
        }
      } else if (category != 'Everything' && d.category != category) {
        return false;
      }
      if (kind != 'All' && d.kind != kind) return false;
      if (pieces != 0 && d.pieces != pieces) return false;
      if (color != 'Any' && !d.colors.contains(color)) return false;
      if (d.off < minOff) return false;
      if (q.isNotEmpty && !d.title.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    switch (sort) {
      case 'low':
        out.sort((a, b) => a.price.compareTo(b.price));
      case 'high':
        out.sort((a, b) => b.price.compareTo(a.price));
      default:
        out.sort((a, b) => b.off != a.off
            ? b.off.compareTo(a.off)
            : a.price.compareTo(b.price));
    }
    return out;
  }
}

class ColorDot extends StatelessWidget {
  final String name;
  final double size;
  const ColorDot(this.name, {super.key, this.size = 18});
  @override
  Widget build(BuildContext context) {
    final c = Filters.colors[name] ?? Colors.transparent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: name == 'Multi' ? null : c,
        gradient: name == 'Multi'
            ? const SweepGradient(colors: [
                Color(0xFFD32F2F), Color(0xFFF2C230), Color(0xFF3E8E41),
                Color(0xFF2F6BD8), Color(0xFF8E5CC4), Color(0xFFD32F2F)])
            : null,
        border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
      ),
      child: name == 'Any'
          ? Icon(Icons.block, size: size - 4, color: Theme.of(context).colorScheme.outline)
          : null,
    );
  }
}

class FilterBar extends StatelessWidget {
  final Filters f;
  final VoidCallback onChanged;
  const FilterBar({super.key, required this.f, required this.onChanged});

  Widget _menu<T>(BuildContext context, String label, T value, List<T> items,
      String Function(T) text, void Function(T) set,
      {Widget Function(T)? icon}) {
    final active = value != items.first;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T>(
        onSelected: (v) {
          set(v);
          onChanged();
        },
        itemBuilder: (_) => [
          for (final i in items)
            CheckedPopupMenuItem(
              value: i,
              checked: i == value,
              child: icon == null
                  ? Text(text(i))
                  : Row(children: [icon(i), const SizedBox(width: 10), Text(text(i))]),
            )
        ],
        child: Chip(
          avatar: active
              ? (icon != null ? icon(value) : const Icon(Icons.check, size: 16))
              : null,
          label: Text(active ? text(value) : label),
          backgroundColor:
              active ? Theme.of(context).colorScheme.secondaryContainer : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (f.any)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.close, size: 16),
                label: const Text('Clear'),
                onPressed: () {
                  f.reset();
                  onChanged();
                },
              ),
            ),
          _menu(context, 'Gender', f.gender, Filters.genders, (s) => s,
              (v) => f.gender = v),
          _menu(context, 'Garment', f.kind, Filters.kinds, (s) => s,
              (v) => f.kind = v),
          _menu(context, 'Pieces', f.pieces, Filters.piecesList,
              (v) => v == 0 ? 'Any pieces' : '$v Piece', (v) => f.pieces = v),
          _menu(context, 'Color', f.color, Filters.colors.keys.toList(),
              (s) => s == 'Any' ? 'Any colour' : s, (v) => f.color = v,
              icon: (c) => ColorDot(c)),
          _menu(context, 'Discount', f.minOff, Filters.offs,
              (v) => v == 0 ? 'Any discount' : '$v%+ off', (v) => f.minOff = v),
          _menu(context, 'Type', f.category, Filters.categories, (s) => s,
              (v) => f.category = v),
          _menu(context, 'Sort', f.sort, const ['off', 'low', 'high'],
              (v) => {'off': 'Biggest discount', 'low': 'Price: low to high', 'high': 'Price: high to low'}[v]!,
              (v) => f.sort = v),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- deal grid

class DealGrid extends StatelessWidget {
  final List<Deal> deals;
  final List<Brand> brands;
  final bool showBrand;
  const DealGrid(
      {super.key, required this.deals, required this.brands, this.showBrand = true});

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No deals match these filters.'))),
      );
    }
    final w = MediaQuery.sizeOf(context).width;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: w > 900 ? 5 : w > 600 ? 3 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        delegate: SliverChildBuilderDelegate(
          (c, i) => DealCard(
              deal: deals[i],
              brand: showBrand ? brandName(brands, deals[i].brand) : null),
          childCount: deals.length,
        ),
      ),
    );
  }
}

class DealCard extends StatefulWidget {
  final Deal deal;
  final String? brand;
  const DealCard({super.key, required this.deal, this.brand});
  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    final cs = Theme.of(context).colorScheme;
    final saved = Prefs.isSaved(d.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(d.url), mode: LaunchMode.externalApplication),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                if (d.image != null)
                  CachedNetworkImage(
                    imageUrl: d.image!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) =>
                        const Center(child: Icon(Icons.image_not_supported_outlined)),
                  )
                else
                  ColoredBox(color: cs.surfaceContainerHighest),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _saleRed, borderRadius: BorderRadius.circular(6)),
                    child: Text('-${d.off}%',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border,
                        color: saved ? _saleRed : null),
                    onPressed: () async {
                      await Prefs.toggleSaved(d);
                      setState(() {});
                    },
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.brand != null)
                    Text(widget.brand!.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: .6,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                  Text(d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.25)),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(rupees(d.price),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(rupees(d.was),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- top deals

class DealsPage extends StatefulWidget {
  final List<Brand> brands;
  final DateTime? updated;
  final Future<void> Function() onRefresh;
  const DealsPage(
      {super.key, required this.brands, required this.updated, required this.onRefresh});
  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  final _f = Filters();
  List<Deal>? _all;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    try {
      final d = await Api.topDeals(refresh: refresh);
      setState(() {
        _all = d;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.brands.where((b) => b.hasSale).toList();
    final shown = _all == null ? <Deal>[] : _f.apply(_all!);
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(refresh: true), widget.onRefresh()]);
      },
      child: CustomScrollView(slivers: [
        SliverAppBar.medium(
          title: const Text('Sale Wala'),
          actions: [
            if (widget.updated != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: Text('Updated ${ago(widget.updated)}',
                        style: Theme.of(context).textTheme.bodySmall)),
              ),
          ],
        ),
        if (live.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: live.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (c, i) => _LiveSaleChip(brand: live[i], brands: widget.brands),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SearchBar(
              hintText: 'Search top deals (e.g. lawn, kurta, jeans)',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _f.query = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
            child: FilterBar(f: _f, onChanged: () => setState(() {}))),
        if (_error != null && _all == null)
          SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorView(error: _error!, onRetry: () => _load(refresh: true)))
        else if (_all == null)
          const SliverFillRemaining(
              hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
        else
          DealGrid(deals: shown, brands: widget.brands),
      ]),
    );
  }
}

class _LiveSaleChip extends StatelessWidget {
  final Brand brand;
  final List<Brand> brands;
  const _LiveSaleChip({required this.brand, required this.brands});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openBrand(context, brand, brands),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
            Text('Up to ${brand.maxOff}% off',
                style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  // our server answered but had no data (e.g. 404 while publishing)
  bool get _server => error.toString().contains('Server returned');
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(_server ? Icons.cloud_off : Icons.wifi_off, size: 40),
            const SizedBox(height: 12),
            Text(
                _server
                    ? "Deals are being updated. Please try again in a few minutes."
                    : "Couldn't load deals. Check your internet connection.",
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- brands

void openBrand(BuildContext context, Brand b, List<Brand> brands) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BrandPage(brand: b, brands: brands)));
}

class BrandsPage extends StatefulWidget {
  final List<Brand> brands;
  final Object? error;
  final Future<void> Function() onRefresh;
  const BrandsPage(
      {super.key, required this.brands, required this.error, required this.onRefresh});
  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  @override
  Widget build(BuildContext context) {
    final favs = Prefs.favBrands;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(slivers: [
        const SliverAppBar.medium(title: Text('Brands')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
                'Tap the bell on a brand to get a notification when its sale starts.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
        if (widget.brands.isEmpty && widget.error != null)
          SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorView(error: widget.error!, onRetry: widget.onRefresh))
        else if (widget.brands.isEmpty)
          const SliverFillRemaining(
              hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
        else
          SliverList.builder(
            itemCount: widget.brands.length,
            itemBuilder: (c, i) {
              final b = widget.brands[i];
              final fav = favs.contains(b.id);
              return ListTile(
                onTap: () => openBrand(context, b, widget.brands),
                leading: CircleAvatar(
                  backgroundColor: b.hasSale ? _saleRed : cs.surfaceContainerHighest,
                  foregroundColor: b.hasSale ? Colors.white : cs.onSurfaceVariant,
                  child: Text(b.hasSale ? '${b.maxOff}%' : '–',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(b.hasSale
                    ? '${b.onSale} items on sale · up to ${b.maxOff}% off'
                    : 'No sale right now'),
                trailing: IconButton(
                  tooltip: fav ? 'Stop sale alerts' : 'Alert me when on sale',
                  icon: Icon(fav ? Icons.notifications_active : Icons.notifications_none,
                      color: fav ? cs.primary : null),
                  onPressed: () async {
                    if (!fav) await Alerts.askPermission();
                    await Prefs.toggleFavBrand(b.id);
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(fav
                              ? 'Alerts off for ${b.name}'
                              : "We'll notify you when ${b.name} has a sale")));
                    }
                  },
                ),
              );
            },
          ),
      ]),
    );
  }
}

class BrandPage extends StatefulWidget {
  final Brand brand;
  final List<Brand> brands;
  const BrandPage({super.key, required this.brand, required this.brands});
  @override
  State<BrandPage> createState() => _BrandPageState();
}

class _BrandPageState extends State<BrandPage> {
  final _f = Filters();
  List<Deal>? _all;
  Object? _error;
  int _limit = 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    try {
      final d = await Api.brandDeals(widget.brand.id, refresh: refresh);
      setState(() {
        _all = d;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brand;
    final shown = _all == null ? <Deal>[] : _f.apply(_all!);
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 800 && _limit < shown.length) {
            setState(() => _limit += 60);
          }
          return false;
        },
        child: CustomScrollView(slivers: [
          SliverAppBar.medium(
            title: Text(b.name),
            actions: [
              IconButton(
                tooltip: 'Open website',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launchUrl(Uri.parse('https://${b.domain}'),
                    mode: LaunchMode.externalApplication),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                  _all == null
                      ? ''
                      : '${shown.length} of ${_all!.length} deals · up to ${b.maxOff}% off',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SearchBar(
                hintText: 'Search ${b.name}',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (v) => setState(() {
                  _f.query = v;
                  _limit = 60;
                }),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: FilterBar(f: _f, onChanged: () => setState(() => _limit = 60))),
          if (_error != null && _all == null)
            SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorView(error: _error!, onRetry: () => _load(refresh: true)))
          else if (_all == null)
            const SliverFillRemaining(
                hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else
            DealGrid(
                deals: shown.take(_limit).toList(),
                brands: widget.brands,
                showBrand: false),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- saved

class SavedPage extends StatefulWidget {
  final List<Brand> brands;
  const SavedPage({super.key, required this.brands});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  @override
  Widget build(BuildContext context) {
    final saved = Prefs.savedDeals.map(Deal.fromJson).toList();
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: CustomScrollView(slivers: [
        SliverAppBar.medium(
          title: const Text('Saved'),
          actions: [
            Row(children: [
              const Text('Sale alerts'),
              Switch(
                value: Prefs.alertsOn,
                onChanged: (v) async {
                  if (v) await Alerts.askPermission();
                  await Prefs.setAlertsOn(v);
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
            ]),
          ],
        ),
        if (saved.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Tap ♡ on any item to save it here.\nPrices shown are from when you saved it.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          DealGrid(deals: saved, brands: widget.brands),
      ]),
    );
  }
}

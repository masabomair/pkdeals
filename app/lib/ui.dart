import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';

/// Content never gets wider than this on big screens; it is centred instead.
const double maxContentWidth = 1240;

/// Centres a screen's content and caps its width on laptops and PCs.
class Centered extends StatelessWidget {
  final Widget child;
  const Centered({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxContentWidth),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------- "Rang" theme

class Rang {
  static const pink = Color(0xFFD4246B);
  static const ink = Color(0xFF1F1A3D);
  static const soft = Color(0xFFFBE9F0);
  static const green = Color(0xFF138A55);
  static const line = Color(0xFFEEE6EF);
  static const muted = Color(0xFF6F6A82);
  static const field = Color(0xFFF3F1F7);

  // dark mode
  static const dBg = Color(0xFF14111F);
  static const dCard = Color(0xFF1F1A30);
  static const dPink = Color(0xFFFF5C9A);
  static const dSoft = Color(0xFF3A1F33);
  static const dLine = Color(0xFF2E2840);
  static const dMuted = Color(0xFFA9A3BD);
  static const dGreen = Color(0xFF4CCB8C);
}

/// Colours that change with light/dark mode.
class RC {
  final bool dark;
  const RC(this.dark);
  factory RC.of(BuildContext c) =>
      RC(Theme.of(c).brightness == Brightness.dark);
  Color get pink => dark ? Rang.dPink : Rang.pink;
  Color get ink => dark ? const Color(0xFFF1EEF8) : Rang.ink;
  Color get bg => dark ? Rang.dBg : Colors.white;
  Color get card => dark ? Rang.dCard : Colors.white;
  Color get soft => dark ? Rang.dSoft : Rang.soft;
  Color get line => dark ? Rang.dLine : Rang.line;
  Color get muted => dark ? Rang.dMuted : Rang.muted;
  Color get field => dark ? Rang.dCard : Rang.field;
  Color get green => dark ? Rang.dGreen : Rang.green;
  Color get chipOn => dark ? const Color(0xFFF1EEF8) : Rang.ink;
  Color get chipOnText => dark ? Rang.ink : Colors.white;
}

ThemeData rangTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Rang.pink,
      brightness: b,
      primary: dark ? Rang.dPink : Rang.pink,
      surface: dark ? Rang.dBg : Colors.white,
    ),
    scaffoldBackgroundColor: dark ? Rang.dBg : Colors.white,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? Rang.dBg : Colors.white,
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      // minimal: no pill behind the selected tab, label only under it
      backgroundColor: dark ? Rang.dBg : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      height: 56,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? (dark ? Rang.dPink : Rang.pink)
              : null,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? (dark ? Rang.dPink : Rang.pink)
              : (dark ? Rang.dMuted : Rang.muted),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- brand badge

const _monoColors = [
  Color(0xFF0B5D3B),
  Color(0xFFB5121B),
  Color(0xFF3B2A6B),
  Color(0xFF9C6B2F),
  Color(0xFF1D1D1D),
  Color(0xFF2B4C7E),
  Color(0xFF5A3B22),
  Color(0xFFC1440E),
  Color(0xFF7A1E5A),
  Color(0xFF1F6F78),
  Color(0xFF4E5B1F),
  Color(0xFF6B2E2E),
];

String initials(String name) {
  final words = RegExp(r'[A-Za-z]+')
      .allMatches(name)
      .map((m) => m.group(0)!)
      .where((w) => !const {'by', 'of', 'the', 'and'}.contains(w.toLowerCase()))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    // first letter + next consonant (Monark → MN, Mohagni → MH) so badges differ
    final w = words[0];
    final c = RegExp(r'[^aeiouAEIOU]').firstMatch(w.substring(1));
    return (w[0] + (c?.group(0) ?? (w.length > 1 ? w[1] : ''))).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

class Monogram extends StatelessWidget {
  final String id, name;
  final double size;
  final bool ring, grey;
  const Monogram(
    this.id,
    this.name, {
    super.key,
    this.size = 44,
    this.ring = false,
    this.grey = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final color = grey
        ? const Color(0xFF9AA0A8)
        : _monoColors[id.hashCode.abs() % _monoColors.length];
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.3,
        ),
      ),
    );
    if (!ring) return badge;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: r.pink, width: 2.2),
      ),
      child: badge,
    );
  }
}

// ---------------------------------------------------------------- chips

class PillChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Widget? leading;
  const PillChip(
    this.label, {
    super.key,
    required this.on,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    return Material(
      color: on ? r.chipOn : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: on ? r.chipOn : r.line, width: 1.2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: on ? r.chipOnText : r.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GenderSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const GenderSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: r.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final g in const ['All', 'Women', 'Men', 'Kids'])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == g ? r.chipOn : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: value == g ? r.chipOnText : r.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- deal card + grid

class DealCard extends StatefulWidget {
  final Deal deal;
  final bool showBrand;
  final String? status; // e.g. "Price dropped" on Saved
  final VoidCallback? onSavedChanged;
  const DealCard({
    super.key,
    required this.deal,
    this.showBrand = true,
    this.status,
    this.onSavedChanged,
  });
  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    final r = RC.of(context);
    final saved = Prefs.isSaved(d.id);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showProduct(
          context,
          d,
          onSavedChanged: () {
            setState(() {});
            widget.onSavedChanged?.call();
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DealImage(d.image),
                    Positioned(left: 8, top: 8, child: OffBadge(d.off)),
                    if (d.isNew)
                      const Positioned(left: 8, bottom: 8, child: Tag('NEW')),
                    if (widget.status != null)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Tag(widget.status!),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: .92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            await Prefs.toggleSaved(d);
                            setState(() {});
                            widget.onSavedChanged?.call();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              saved ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: saved ? Rang.pink : Rang.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            if (widget.showBrand)
              Text(
                Store.i.brandName(d.brand).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w800,
                  color: r.muted,
                ),
              ),
            Text(
              d.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: r.ink,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  rupees(d.price),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: r.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    plain(d.was),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.muted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Save ${rupees(d.saving)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: r.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DealImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const DealImage(this.url, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    if (url == null) return ColoredBox(color: r.field);
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      memCacheWidth: 600,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => ColoredBox(color: r.field),
      errorWidget: (_, _, _) => ColoredBox(
        color: r.field,
        child: Icon(Icons.image_not_supported_outlined, color: r.muted),
      ),
    );
  }
}

class OffBadge extends StatelessWidget {
  final int off;
  const OffBadge(this.off, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: RC.of(context).pink,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      '-$off%',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Rang.ink,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: .5,
      ),
    ),
  );
}

/// Lazily built two-column grid; grows by 60 as you scroll.
class DealGrid extends StatelessWidget {
  final List<Deal> deals;
  final int limit;
  final bool showBrand;
  final VoidCallback? onSavedChanged;
  const DealGrid({
    super.key,
    required this.deals,
    required this.limit,
    this.showBrand = true,
    this.onSavedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width.clamp(0.0, maxContentWidth);
    final cols = w > 1100
        ? 5
        : w > 840
        ? 4
        : w > 600
        ? 3
        : 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: 0.5,
        ),
        delegate: SliverChildBuilderDelegate(
          (c, i) => DealCard(
            deal: deals[i],
            showBrand: showBrand,
            onSavedChanged: onSavedChanged,
          ),
          childCount: deals.length < limit ? deals.length : limit,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- product preview

const _colorSwatch = <String, Color>{
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
  'Multi': Color(0x00000000),
};
List<String> get colorNames => _colorSwatch.keys.toList();

class Swatch extends StatelessWidget {
  final String name;
  final double size;
  final bool on;
  const Swatch(this.name, {super.key, this.size = 26, this.on = false});
  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? r.ink : Colors.transparent, width: 2),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: name == 'Multi' ? null : _colorSwatch[name],
          gradient: name == 'Multi'
              ? const SweepGradient(
                  colors: [
                    Color(0xFFD32F2F),
                    Color(0xFFF2C230),
                    Color(0xFF3E8E41),
                    Color(0xFF2F6BD8),
                    Color(0xFF8E5CC4),
                    Color(0xFFD32F2F),
                  ],
                )
              : null,
          border: Border.all(color: Colors.black.withValues(alpha: .12)),
        ),
      ),
    );
  }
}

/// Wide screens (laptop, PC, tablet landscape) get dialogs instead of bottom sheets.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

Future<void> showProduct(
  BuildContext context,
  Deal d, {
  VoidCallback? onSavedChanged,
}) {
  if (isWide(context)) {
    return showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: RC.of(c).bg,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ProductSheet(
            deal: d,
            onSavedChanged: onSavedChanged,
            wide: true,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => ProductSheet(deal: d, onSavedChanged: onSavedChanged),
  );
}

class ProductSheet extends StatefulWidget {
  final Deal deal;
  final VoidCallback? onSavedChanged;
  final bool wide;
  const ProductSheet({
    super.key,
    required this.deal,
    this.onSavedChanged,
    this.wide = false,
  });
  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    final r = RC.of(context);
    final brand = Store.i.brandName(d.brand);
    final saved = Prefs.isSaved(d.id);
    final h = MediaQuery.sizeOf(context).height;
    final facts = [
      d.category,
      if (d.fabric != null) d.fabric!,
      if (d.pieces != null) '${d.pieces} Piece',
      if (d.kind != null && d.kind != 'Other') d.kind!,
      d.gender,
    ];
    Widget image(double height) => Stack(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: DealImage(d.image),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Rang.ink,
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ),
        Positioned(left: 14, top: 14, child: OffBadge(d.off)),
        if (d.isNew)
          const Positioned(left: 14, bottom: 14, child: Tag('NEW TODAY')),
      ],
    );
    final info = Padding(
      padding: EdgeInsets.fromLTRB(
        widget.wide ? 28 : 20,
        widget.wide ? 28 : 16,
        20,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Monogram(d.brand, brand, size: 26),
              const SizedBox(width: 8),
              Text(
                brand.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                  fontSize: 12,
                  color: r.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: r.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rupees(d.price),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: r.ink,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                rupees(d.was),
                style: TextStyle(
                  fontSize: 15,
                  color: r.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'You save ${rupees(d.saving)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: r.green,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in facts)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: r.soft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: r.pink,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
          if (d.colors.isNotEmpty) ...[
            const SizedBox(height: 18),
            _label(context, 'Colour'),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final c in d.colors)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Swatch(c, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        c,
                        style: TextStyle(
                          color: r.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (d.sizes.isNotEmpty) ...[
            const SizedBox(height: 18),
            _label(context, 'Sizes in stock'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in d.sizes)
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: r.line, width: 1.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Price checked ${ago(Store.i.updated)}. Check the final price on $brand\'s site.',
            style: TextStyle(fontSize: 12, color: r.muted),
          ),
        ],
      ),
    );
    final actions = SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: r.line)),
        ),
        child: Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(54, 52),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: r.line, width: 1.4),
              ),
              onPressed: () async {
                await Prefs.toggleSaved(d);
                setState(() {});
                widget.onSavedChanged?.call();
              },
              child: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                color: saved ? r.pink : r.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: r.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                onPressed: () => launchUrl(
                  Uri.parse(d.url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Shop on $brand', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.wide) {
      // laptop / PC: photo on the left, details and buttons on the right
      final height = (h * 0.86).clamp(420.0, 720.0);
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: height * 0.72, child: image(height)),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(padding: EdgeInsets.zero, children: [info]),
                  ),
                  actions,
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [image(h * 0.46), info],
            ),
          ),
          actions,
        ],
      ),
    );
  }
}

Widget _label(BuildContext context, String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    t,
    style: TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      color: RC.of(context).ink,
    ),
  ),
);

// ---------------------------------------------------------------- filter sheet

const fabricOrder = [
  'Lawn',
  'Khaddar',
  'Cotton',
  'Cambric',
  'Silk',
  'Linen',
  'Karandi',
  'Velvet',
  'Chiffon',
  'Organza',
  'Net',
  'Jacquard',
  'Slub',
  'Dobby',
  'Viscose',
  'Wool',
  'Marina',
  'Twill',
  'Satin',
  'Georgette',
  'Crepe',
  'Denim',
  'Fleece',
  'Corduroy',
  'Jersey',
  'Interlock',
  'Wash & Wear',
  'Cross Hatch',
  'Blended',
  'Muslin',
  'Poplin',
];
const kindOrder = [
  'Suits & Sets',
  'Shirts & Tops',
  'Bottoms',
  'Outerwear',
  'Dupattas & Shawls',
];

/// Opens the filter sheet; returns the new filters, or null if dismissed.
Future<Filters?> showFilters(
  BuildContext context,
  Filters current,
  List<Deal> pool,
) {
  return showModalBottomSheet<Filters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => FilterSheet(start: current, pool: pool),
  );
}

class FilterSheet extends StatefulWidget {
  final Filters start;
  final List<Deal> pool;
  const FilterSheet({super.key, required this.start, required this.pool});
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Filters f = widget.start.copy();
  bool allFabrics = false;
  bool allBrands = false;

  void _toggle<T>(Set<T> s, T v) =>
      setState(() => s.contains(v) ? s.remove(v) : s.add(v));

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final count = widget.pool.where(f.matches).length;
    // price histogram for deals matching everything except price
    final buckets = List<int>.filled(priceSteps.length - 1, 0);
    for (final d in widget.pool) {
      if (!f.matches(d, ignorePrice: true)) continue;
      var i = priceSteps.lastIndexWhere((p) => d.price >= p);
      if (i >= buckets.length) i = buckets.length - 1;
      buckets[i]++;
    }
    final peak = buckets.fold<int>(1, (a, b) => b > a ? b : a);
    final fabrics = allFabrics ? fabricOrder : fabricOrder.take(8).toList();
    final brandList = Store.i.brands.where((b) => b.hasSale).toList();
    final brands = allBrands ? brandList : brandList.take(10).toList();
    final maxLabel = f.maxStep == priceSteps.length - 1
        ? 'any'
        : rupees(priceSteps[f.maxStep]);

    Widget section(String title, Widget child, {String? note}) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: r.ink,
                ),
              ),
              const Spacer(),
              if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    color: r.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: r.ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: f.count == 0 ? null : () => setState(f.clearSheet),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: f.count == 0 ? r.muted : r.pink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: r.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              children: [
                section(
                  'Type',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in const [
                        'Ready to Wear',
                        'Unstitched',
                        'Fragrance & Beauty',
                      ])
                        PillChip(
                          t == 'Ready to Wear' ? 'Ready to Wear (Pret)' : t,
                          on: f.types.contains(t),
                          onTap: () => _toggle(f.types, t),
                        ),
                    ],
                  ),
                ),
                section(
                  'Garment',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in kindOrder)
                        PillChip(
                          k,
                          on: f.kinds.contains(k),
                          onTap: () => _toggle(f.kinds, k),
                        ),
                    ],
                  ),
                ),
                section(
                  'Pieces',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in const [1, 2, 3])
                        PillChip(
                          '$p Piece',
                          on: f.pieces.contains(p),
                          onTap: () => _toggle(f.pieces, p),
                        ),
                    ],
                  ),
                ),
                section(
                  'Fabric',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final x in fabrics)
                        PillChip(
                          x,
                          on: f.fabrics.contains(x),
                          onTap: () => _toggle(f.fabrics, x),
                        ),
                      if (!allFabrics)
                        ActionChip(
                          label: Text('+${fabricOrder.length - 8} more'),
                          onPressed: () => setState(() => allFabrics = true),
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  note: f.fabrics.isEmpty
                      ? null
                      : '${f.fabrics.length} selected',
                ),
                section(
                  'Colour',
                  Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    children: [
                      for (final c in colorNames)
                        Tooltip(
                          message: c,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _toggle(f.colors, c),
                            child: Swatch(
                              c,
                              size: 30,
                              on: f.colors.contains(c),
                            ),
                          ),
                        ),
                    ],
                  ),
                  note: f.colors.isEmpty ? null : f.colors.join(', '),
                ),
                section(
                  'Price',
                  Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < buckets.length; i++)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  height: 4 + 40 * buckets[i] / peak,
                                  decoration: BoxDecoration(
                                    color: i >= f.minStep && i < f.maxStep
                                        ? r.pink.withValues(alpha: .55)
                                        : r.line,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      RangeSlider(
                        values: RangeValues(
                          f.minStep.toDouble(),
                          f.maxStep.toDouble(),
                        ),
                        min: 0,
                        max: (priceSteps.length - 1).toDouble(),
                        divisions: priceSteps.length - 1,
                        activeColor: r.pink,
                        inactiveColor: r.line,
                        onChanged: (v) => setState(() {
                          f.minStep = v.start.round();
                          f.maxStep = v.end.round();
                        }),
                      ),
                    ],
                  ),
                  note: '${rupees(priceSteps[f.minStep])} – $maxLabel',
                ),
                section(
                  'Discount',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in const [0, 30, 50, 70])
                        PillChip(
                          o == 0 ? 'Any' : '$o%+ off',
                          on: f.minOff == o,
                          onTap: () => setState(() => f.minOff = o),
                        ),
                    ],
                  ),
                ),
                section(
                  'Show only',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PillChip(
                        'New today',
                        on: f.newOnly,
                        onTap: () => setState(() => f.newOnly = !f.newOnly),
                      ),
                    ],
                  ),
                ),
                if (widget.start.brand == null)
                  section(
                    'Brands',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in brands)
                          PillChip(
                            b.name,
                            on: f.brands.contains(b.id),
                            onTap: () => _toggle(f.brands, b.id),
                          ),
                        if (!allBrands && brandList.length > 10)
                          ActionChip(
                            label: Text('+${brandList.length - 10} more'),
                            onPressed: () => setState(() => allBrands = true),
                            shape: const StadiumBorder(),
                          ),
                      ],
                    ),
                    note: f.brands.isEmpty
                        ? null
                        : '${f.brands.length} selected',
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: r.line)),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: r.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                onPressed: count == 0 ? null : () => Navigator.pop(context, f),
                child: Text(
                  count == 0 ? 'No deals match' : 'Show ${plain(count)} deals',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

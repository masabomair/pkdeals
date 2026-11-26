import 'package:material_ui/material_ui.dart';

import 'account.dart';
import 'alerts.dart';
import 'data.dart';
import 'screens.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  themeChoice.value = Prefs.theme;
  try {
    await Alerts.init();
  } catch (_) {}
  Store.i.load();
  // optional login + analytics (does nothing until firebase_config.dart is filled in)
  Prefs.onChanged = Account.i.pushPrefs;
  Account.i.init();
  // record a baseline so alerts only fire for changes after install
  // tapping a sale notification opens that brand's deals
  Alerts.onOpenBrand = _openBrand;
  // check for sale changes every time the app opens (the background check
  // also runs every hour while the app is closed)
  Alerts.check().catchError((_) => <SaleAlert>[]);
  runApp(const SaleMela());
}

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> _openBrand(String id) async {
  // wait (up to 15 s) for the deals to load, then open the brand page
  for (var i = 0; i < 30 && Store.i.brandById[id] == null; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  final b = Store.i.brandById[id];
  if (b == null) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => DealsScreen(brand: b)),
  );
}

/// The chosen theme ('system', 'light' or 'dark'), changed from Profile.
final themeChoice = ValueNotifier<String>('system');

ThemeMode _mode(String t) => t == 'light'
    ? ThemeMode.light
    : t == 'dark'
    ? ThemeMode.dark
    : ThemeMode.system;

class SaleMela extends StatelessWidget {
  const SaleMela({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: themeChoice,
    builder: (_, t, _) => MaterialApp(
      themeMode: _mode(t),
      title: 'Sale Mela',
      debugShowCheckedModeBanner: false,
      theme: rangTheme(Brightness.light),
      darkTheme: rangTheme(Brightness.dark),
      navigatorKey: navigatorKey,
      home: const Shell(),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _tab,
      children: [
        DealsScreen(onAlerts: () => setState(() => _tab = 1)),
        const BrandsScreen(),
        SavedScreen(key: ValueKey(_tab == 2)),
        ProfileScreen(key: ValueKey(_tab == 3), theme: themeChoice),
      ],
    );
    if (isWide(context)) {
      // laptop / PC: navigation down the left side
      final r = RC.of(context);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: r.bg,
              indicatorColor: r.soft,
              selectedIconTheme: IconThemeData(color: r.pink),
              selectedLabelTextStyle: TextStyle(
                color: r.pink,
                fontWeight: FontWeight.w700,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/rounded.png',
                    width: 44,
                    height: 44,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: Text('Brands'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite),
                  label: Text('Saved'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: r.line),
            Expanded(child: pages),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Brands',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import 'alerts.dart';
import 'data.dart';
import 'screens.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  try {
    await Alerts.init();
  } catch (_) {}
  Store.i.load();
  // record a baseline so alerts only fire for changes after install
  Alerts.check(notify: false).catchError((_) => <(String, String)>[]);
  runApp(const SaleMela());
}

class SaleMela extends StatelessWidget {
  const SaleMela({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sale Mela',
    debugShowCheckedModeBanner: false,
    theme: rangTheme(Brightness.light),
    darkTheme: rangTheme(Brightness.dark),
    home: const Shell(),
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
        ],
      ),
    );
  }
}

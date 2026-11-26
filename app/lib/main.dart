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
  runApp(const SaleWala());
}

class SaleWala extends StatelessWidget {
  const SaleWala({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sale Wala',
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
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        DealsScreen(onAlerts: () => setState(() => _tab = 1)),
        const BrandsScreen(),
        SavedScreen(key: ValueKey(_tab == 2)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Brands'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
        ],
      ),
    );
  }
}

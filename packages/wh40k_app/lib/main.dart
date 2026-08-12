import 'package:flutter/material.dart';

import 'src/data/army.dart';
import 'src/screens/army_screen.dart';
import 'src/screens/turn_screen.dart';
import 'src/theme.dart';

void main() => runApp(const Wh40kApp());

class Wh40kApp extends StatelessWidget {
  const Wh40kApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wh40k Companion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Army> _army = Army.loadReference();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<Army>(
          future: _army,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Error(error: snapshot.error!);
            }
            final army = snapshot.data;
            if (army == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return IndexedStack(
              index: _tab,
              children: [
                ArmyScreen(army: army),
                TurnScreen(army: army),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 60,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Army',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: 'Turn',
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;

  const _Error({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the reference army.\n\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

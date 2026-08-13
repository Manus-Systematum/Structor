import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'src/data/army.dart';
import 'src/data/database.dart';
import 'src/data/roster_store.dart';
import 'src/screens/army_screen.dart';
import 'src/screens/roster_list_screen.dart';
import 'src/screens/turn_screen.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RosterStore(await openAppDatabase());
  await store.seedIfEmpty();
  runApp(StructorApp(store: store));
}

class StructorApp extends StatelessWidget {
  final RosterStore store;

  const StructorApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Structor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (context) => RosterListScreen(
            store: store,
            onOpen: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArmyPage(store: store, rosterId: id),
              ),
            ),
          ),
        ),
      );
}

/// One saved army, with the two in-play surfaces.
class ArmyPage extends StatefulWidget {
  final RosterStore store;
  final String rosterId;

  const ArmyPage({super.key, required this.store, required this.rosterId});

  @override
  State<ArmyPage> createState() => _ArmyPageState();
}

class _ArmyPageState extends State<ArmyPage> {
  late final Future<Army?> _army = widget.store.load(widget.rosterId);
  int _tab = 0;
  BattleLog _log = const BattleLog();

  @override
  void initState() {
    super.initState();
    widget.store.loadBattle(widget.rosterId).then((log) {
      if (mounted) setState(() => _log = log);
    });
  }

  /// Every change appends to the log and persists it, so a game survives the
  /// app being killed mid-turn (DESIGN.md §7.4).
  Future<void> _apply(BattleLog next) async {
    setState(() => _log = next);
    await widget.store.saveBattle(widget.rosterId, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<Army?>(
          future: _army,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                  text: 'Could not open this roster.\n\n${snapshot.error}');
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final army = snapshot.data;
            if (army == null) {
              return const _Message(text: 'This roster is no longer saved.');
            }
            return IndexedStack(
              index: _tab,
              children: [
                ArmyScreen(army: army),
                TurnScreen(
                  army: army,
                  log: _log,
                  onEvent: (event) => _apply(_log.add(event)),
                  onUndo: () => _apply(_log.undo()),
                ),
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

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

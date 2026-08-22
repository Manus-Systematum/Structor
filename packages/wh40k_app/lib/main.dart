import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'src/data/army.dart';
import 'src/data/database.dart';
import 'src/data/roster_store.dart';
import 'src/screens/army_screen.dart';
import 'src/screens/battles_screen.dart';
import 'src/data/dataset_repository.dart';
import 'src/screens/editor_screen.dart';
import 'src/screens/objectives_screen.dart';
import 'src/screens/reference_screen.dart';
import 'src/screens/roster_list_screen.dart';
import 'src/screens/setup_screen.dart';
import 'src/screens/turn_screen.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RosterStore(await openAppDatabase());
  final datasets = DatasetRepository(cache: await BundleCache.open());
  runApp(StructorApp(store: store, datasets: datasets));
}

class StructorApp extends StatelessWidget {
  final RosterStore store;
  final DatasetRepository datasets;

  const StructorApp({
    super.key,
    required this.store,
    required this.datasets,
  });

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
            datasets: datasets,
            onOpen: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArmyPage(
                  store: store,
                  datasets: datasets,
                  rosterId: id,
                ),
              ),
            ),
          ),
        ),
      );
}

/// One saved army, with the two in-play surfaces.
class ArmyPage extends StatefulWidget {
  final RosterStore store;
  final DatasetRepository datasets;
  final String rosterId;

  const ArmyPage({
    super.key,
    required this.store,
    required this.datasets,
    required this.rosterId,
  });

  @override
  State<ArmyPage> createState() => _ArmyPageState();
}

class _ArmyPageState extends State<ArmyPage> {
  late Future<Army?> _army = widget.store.load(widget.rosterId);
  int _tab = 0;
  BattleLog _log = const BattleLog();
  MissionPack _pack = const MissionPack();

  @override
  void initState() {
    super.initState();
    widget.store.loadBattle(widget.rosterId).then((log) {
      if (mounted) setState(() => _log = log);
    });
    widget.datasets.missions().then((pack) {
      if (mounted) setState(() => _pack = pack);
    });
  }

  /// Setup is mandatory before play, so the Turn tab routes through the wizard
  /// until it has been completed (DESIGN.md §7.3.1).
  Future<void> _runSetup(Army army) async {
    final setup = await Navigator.of(context).push<MissionSetup>(
      MaterialPageRoute(
        builder: (_) => SetupScreen(army: army, pack: _pack),
      ),
    );
    if (setup != null) await _apply(_log.add(ConfigureBattle(setup)));
  }

  /// Opens the builder on this roster. Editing works against the faction
  /// dataset and re-snapshots on save, so the list stops moving under the
  /// player at the next dataset update (§2.2).
  Future<void> _editArmy(Army army) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          store: widget.store,
          datasets: widget.datasets,
          initial: army.roster,
          rosterId: army.id,
        ),
      ),
    );
    // Reloaded whatever comes back. The old builder returned `true` only
    // from its Save button; with the button gone every exit is a save, and
    // keying the reload on `true` meant an edit made and backed out of was
    // written to the database and never read again on this screen.
    if (mounted) {
      setState(() => _army = widget.store.load(widget.rosterId));
    }
  }

  /// Files the finished game away and clears the board (§7.3.12).
  ///
  /// Confirmed, because it is the one action here that is not undoable: the
  /// log leaves the roster, and the Turn tab goes back to the list of past
  /// battles. The record keeps the whole log, so nothing is lost — but the
  /// game in progress is over, and that is worth one tap to be sure of.
  Future<void> _finishBattle(Army army) async {
    final state = _log.state;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish this battle?'),
        content: Text(
          'It is filed under past battles at '
          '${state.me.total}–${state.opponent.total} after '
          '${state.round} round${state.round == 1 ? '' : 's'}, and the Turn '
          'tab is cleared for the next game.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (finish != true) return;

    await widget.store.finishBattle(army, _log);
    if (mounted) setState(() => _log = const BattleLog());
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
                ArmyScreen(army: army, onEdit: () => _editArmy(army)),
                // With no game in progress the tab rests on the record of
                // past ones rather than a screen that exists to hold a
                // button (§7.3.12).
                if (_log.state.setup == null)
                  BattlesScreen(
                    store: widget.store,
                    pack: _pack,
                    rosterId: army.id,
                    armyName: army.roster.name,
                    onStart: _pack.isEmpty ? null : () => _runSetup(army),
                  )
                else
                  TurnScreen(
                    army: army,
                    log: _log,
                    deck: SecondaryDeck.of(_pack),
                    pack: _pack,
                    onEvent: (event) => _apply(_log.add(event)),
                    onUndo: () => _apply(_log.undo()),
                    onFinish: () => _finishBattle(army),
                  ),
                ObjectivesScreen(
                  state: _log.state,
                  pack: _pack,
                  deck: SecondaryDeck.of(_pack),
                  // Only once there is a game to finish; the page shows a
                  // prompt to set one up otherwise.
                  onFinish: _log.state.setup == null
                      ? null
                      : () => _finishBattle(army),
                ),
                ReferenceScreen(army: army),
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
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Objectives',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Rules',
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
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.left,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

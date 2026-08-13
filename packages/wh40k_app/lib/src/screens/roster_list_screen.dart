import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/dataset_repository.dart';
import '../data/roster_store.dart';
import 'about_screen.dart';
import 'import_screen.dart';

/// Saved rosters. The app's front door.
class RosterListScreen extends StatelessWidget {
  final RosterStore store;
  final DatasetRepository datasets;
  final void Function(String rosterId) onOpen;

  const RosterListScreen({
    super.key,
    required this.store,
    required this.datasets,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Structor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AboutScreen(datasets: datasets),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final army = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ImportScreen(datasets: datasets)),
          );
          if (army != null) await store.save(army);
        },
        icon: const Icon(Icons.download),
        label: const Text('Import'),
      ),
      body: StreamBuilder<List<RosterRow>>(
        stream: store.watch(),
        builder: (context, snapshot) {
          final rows = snapshot.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No rosters yet.\nImport a text export to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Dismissible(
                key: ValueKey(row.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: scheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: scheme.onErrorContainer),
                ),
                onDismissed: (_) => store.delete(row.id),
                child: ListTile(
                  title: Text(row.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${row.factionId.replaceAll('-', ' ')} · '
                    '${row.points} pts · ${row.unitCount} units',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(row.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

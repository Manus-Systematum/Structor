import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/dataset_repository.dart';
import '../data/roster_store.dart';
import 'about_screen.dart';
import 'editor_screen.dart';
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: 'Import a list',
            onPressed: () async {
              final army = await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => ImportScreen(datasets: datasets)),
              );
              if (army != null) await store.save(army);
            },
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'build',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditorScreen(store: store, datasets: datasets),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Build'),
          ),
        ],
      ),
      body: StreamBuilder<List<RosterRow>>(
        stream: store.watch(),
        builder: (context, snapshot) =>
            RosterListView(store: store, rows: snapshot.data, onOpen: onOpen),
      ),
    );
  }
}

/// The list itself, given the rows rather than a stream.
///
/// Split from the screen for the same reason [BattlesView] is (§7.3.12): a
/// database stream inside a widget test leaves a timer pending when the tree
/// is disposed, and the test fails on the invariant rather than on anything
/// it was checking.
class RosterListView extends StatelessWidget {
  final RosterStore store;

  /// Null while the first read is still in flight.
  final List<RosterRow>? rows;

  final void Function(String rosterId) onOpen;

  const RosterListView({
    super.key,
    required this.store,
    required this.rows,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = this.rows;
    if (rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
      if (rows.isEmpty) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No armies yet.\n\n'
              'Build one from the datasheets, or import a text export '
              'from the list you already have.',
              textAlign: TextAlign.left,
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
            // An army is hours of work and a swipe is easy to make by
            // accident while scrolling. There is no undo behind this.
            confirmDismiss: (_) => confirmDelete(context, row.name),
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
              // The swipe is a shortcut, not the only way in: it is
              // undiscoverable, and it is the only route to duplicating.
              trailing: _RowMenu(
                onDuplicate: () => _duplicate(context, row, rows),
                onDelete: () async {
                  if (await confirmDelete(context, row.name) ?? false) {
                    await store.delete(row.id);
                  }
                },
              ),
              onTap: () => onOpen(row.id),
            ),
          );
        },
      );
  }

  Future<void> _duplicate(
      BuildContext context, RosterRow row, List<RosterRow> rows) async {
    final name = await askForName(
      context,
      initial: copyName(row.name, rows.map((r) => r.name)),
    );
    if (name == null) return;
    await store.duplicate(row.id, name: name);
  }
}

/// The name for a copy, or null if the dialog was dismissed.
///
/// A copy is nearly always made to become a *variant* — the same list with one
/// thing swapped — so the name is asked for up front rather than left to be
/// corrected afterwards, and it comes pre-selected so it can be typed over.
Future<String?> askForName(BuildContext context,
    {required String initial}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: initial),
  );
  return (name?.isEmpty ?? true) ? null : name;
}

/// Owns the field's controller.
///
/// The controller cannot be disposed as soon as `showDialog` returns: the
/// dialog is still animating out, and the field it left behind goes on
/// reading the controller for the length of that animation.
class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Duplicate army'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Duplicate')),
      ],
    );
  }
}

/// Asks before an army is destroyed. True only on an explicit Delete.
Future<bool?> confirmDelete(BuildContext context, String name) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
            'The list is removed. Finished battles keep their own record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

class _RowMenu extends StatelessWidget {
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _RowMenu({required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Army actions',
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: onDuplicate,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_outlined, size: 20),
            title: Text('Duplicate'),
          ),
        ),
        PopupMenuItem(
          onTap: onDelete,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, size: 20),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }
}

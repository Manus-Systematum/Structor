import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/roster_store.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../data/dataset_repository.dart';

/// Credits, attribution and provenance.
///
/// This screen is **required**, not decorative. 40kdc-data's licence obliges
/// any public deployment to display "Powered by 40kdc-data" with a link, and a
/// TestFlight build counts. The rules data the entire app runs on comes from
/// there (DESIGN.md §3.0).
///
/// It also surfaces the dataset revision and whether any of it is still on a
/// provisional dataslate, which §3.0 requires be visible rather than presented
/// as current.
class AboutScreen extends StatefulWidget {
  final DatasetRepository datasets;

  /// Null in tests that only read the page. The Legends switch is hidden
  /// without it rather than shown doing nothing.
  final RosterStore? store;

  const AboutScreen({super.key, required this.datasets, this.store});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _package;
  DatasetManifest? _manifest;
  bool? _provisional;
  bool _showLegends = false;

  @override
  void initState() {
    super.initState();
    widget.store?.showLegends().then((on) {
      if (mounted) setState(() => _showLegends = on);
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _package = info);
    });
    widget.datasets.manifest().then((manifest) {
      if (mounted) setState(() => _manifest = manifest);
    });
    widget.datasets.faction('tau-empire').then((dataset) {
      if (mounted) setState(() => _provisional = dataset.hasProvisionalContent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final package = _package;
    final manifest = _manifest;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text('Structor',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (widget.store case final store?) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Legends datasheets',
                  style: TextStyle(fontSize: 14)),
              // What it costs, not what it is for. 485 of 1,857 datasheets
              // are Legends, so the picker is a third longer with them in.
              subtitle: Text(
                'Adds 485 shelved datasheets to the unit picker.',
                style:
                    TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
              value: _showLegends,
              onChanged: (on) {
                setState(() => _showLegends = on);
                store.setShowLegends(on);
              },
            ),
            const Divider(height: 16),
          ],
          Text(
            package == null
                ? 'version …'
                : 'version ${package.version} (build ${package.buildNumber})',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text('A companion for Warhammer 40,000, 11th edition.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),

          const _Heading('Rules data'),
          // The licence requires this exact phrase and a link. Do not reword.
          const Text('Powered by 40kdc-data',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const SelectableText('https://40kdc.alpacasoft.dev',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          const _Body(
            'Datasheets, weapons, abilities, missions and stratagems come from '
            'the 40kdc-data project, licensed CC BY 4.0 © Alpaca Software and '
            'the 40kdc community contributors. Its schemas are CC0. Changes '
            'were made: the data is repackaged into compressed bundles and '
            'rendered by this app.',
          ),

          const SizedBox(height: 14),
          // Wahapedia's data export asks for exactly this phrase: "When
          // publishing your work, mentioning Wahapedia is highly recommended.
          // For example, with the inscription 'powered by Wahapedia'."
          const Text('Powered by Wahapedia',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const SelectableText('https://wahapedia.ru/wh40k11ed/',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          const _Body(
            'Stratagem rules text comes from the Wahapedia 11th edition data '
            'export. The eleven Core Stratagems are transcribed from the free '
            'Warhammer 40,000 Core Rules published by Games Workshop, by way '
            'of the stratagem card generator by pguetschow.',
          ),
          const SizedBox(height: 2),
          const SelectableText(
            'https://github.com/pguetschow/warhammer-40k-stratagem-card-generator',
            style: TextStyle(fontSize: 12),
          ),

          const SizedBox(height: 14),
          // The trademark disclaimer is stated once, further down; repeating
          // it here would be two answers to the same question.
          const _Body(
            'Datasheet and ability text are drawn from BSData, and mission '
            'card text from gdmissions.app.',
          ),

          const SizedBox(height: 14),
          const Text('Warhammer Community downloads',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const SelectableText(
            'https://www.warhammer-community.com/en-gb/downloads/warhammer-40000/',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Named as its own source rather than folded into the line above.
          // The sources above are community projects that set their own
          // terms; this one is Games Workshop's, and a reader deciding
          // whether to trust a stratagem's wording should be able to see
          // which of the two it came from (§3.15).
          const _Body(
            'Where the community sources have not caught up with a rules '
            'update, the wording comes from Games Workshop’s own free Faction '
            'Pack downloads. These corrections arrive as a separate data '
            'update and are removed once the sources above publish the same '
            'rules.',
          ),
          if (manifest != null) ...[
            const SizedBox(height: 10),
            _Row(label: 'Dataset', value: manifest.generated),
            for (final bundle in manifest.bundles)
              _Row(
                  label: bundle.name,
                  value: '${(bundle.bytes / 1024).toStringAsFixed(0)} KB'),
          ],
          if (_provisional == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some of this data is on a pre-launch provisional '
                      'dataslate, carried over from 10th edition. Check '
                      'anything that matters against your own book.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const _Heading('Rules text'),
          const _Body(
            'Mission and ability descriptions are original summaries written '
            'by the 40kdc project, not Games Workshop’s printed wording. They '
            'are enough to play from, but they are not authoritative — for a '
            'rules dispute, use the card or the book.',
          ),

          const _Heading('Licence'),
          const _Body(
            'Structor’s own code is MIT licensed. The data it shows is not: '
            'each source above keeps the terms named with it.',
          ),

          const _Heading('Trademarks'),
          // This paragraph used to end "No Games Workshop rules text is
          // distributed with it." That was true when it was written and
          // stopped being true at DESIGN.md §3.12, which bundled the printed
          // stratagem wording by way of Wahapedia's export. A compliance
          // statement that has quietly gone false is worse than none.
          //
          // What replaced it says how far their rights reach rather than what
          // this app does or does not carry: naming the marks while staying
          // quiet about the text is the narrower claim, and the narrower claim
          // reads as avoidance. Same wording as the site.
          const _Body(
            'Everything above was collected from openly published sources, '
            'some of them Games Workshop’s own free downloads. Warhammer '
            '40,000, all associated names, marks and imagery, and any wording '
            'here that matches Games Workshop’s printed rules, remain © Games '
            'Workshop Limited. This app is unofficial and is neither endorsed '
            'by nor affiliated with Games Workshop.',
          ),

          const _Heading('Privacy'),
          const _Body(
            'Structor collects nothing. There are no accounts, no analytics '
            'and no tracking. Your rosters and games stay on this device.',
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}

class _Body extends StatelessWidget {
  final String text;

  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

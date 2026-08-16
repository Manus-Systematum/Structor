# Warhammer 40,000 (11th Edition) — Companion App

Design document. Living file: updated as each design step is settled.

**Status:** design phase, no code yet.
**Started:** 2026-08-11 · **11e rules research + BSData data audit:** 2026-08-11

---

## 0. Scope & constraints

A cross-platform (iOS/Android) companion app for Warhammer 40,000 11th edition, built in three parts:

1. **Army builder** — import from common formats, QR exchange between app instances, community rules database, statistics preview.
2. **Play mode** — swappable screens: a mission/setup screen (customisable for new missions and house rules), plus in-game reference screens for unit and weapon stats, army rules, and stratagems.
3. **Sharing server** — a backend with its own web interface for sharing armies. Deliberately deferred.

### Constraint: rules data and copyright

Games Workshop's rules text is copyrighted. The app therefore ships with **no bundled rules data** and fetches community-maintained catalogues at runtime — the same path BattleScribe and New Recruit took. A downloadable, versioned, replaceable content bundle is a day-one architectural requirement, not a later feature.

> ✅ **Resolved, twice over.**
>
> **By architecture.** §3.0 made `40kdc-data` the primary source, and it is explicitly licensed: CC BY 4.0 for data, CC0 for schemas. Nothing derived from BSData is used, built or shipped — the published bundles carry `source: 40kdc-data`, and BSData now survives only in two source comments explaining design history.
>
> **By the maintainers.** Asked directly ([BSData/wh40k-11e#918](https://github.com/BSData/wh40k-11e/issues/918)), they replied that the organisation often does not attach licences, that the repository *is* intended to be open source, and that it may be cloned and altered freely.
>
> Worth holding that second point at the right strength: it is **permission, not a licence**. A maintainer's statement in an issue does not set terms, does not obviously bind every contributor who holds copyright in their own contributions, and is not as durable as a file in the repository. The useful follow-up is to ask them to add an actual `LICENSE` — the reply suggests they would be receptive, and it would settle it for every downstream project rather than just this one.
>
> What it unblocked was the **cross-check**, now built — though against a better source than the catalogue repo. See §3.5.
>
> ⚠ **Original finding, kept for the record.** `BSData/wh40k-11e` has **no `LICENSE`, `LICENSE.md` or `LICENSE.txt` at the repository root** (all three returned 404, checked 2026-08-11).

Related: the **Chapter Approved Mission Deck** is a physical GW product. The play-mode setup screen must let the user *record which cards they drew*, not reproduce card text. See §7.

### Constraint: the source data is not the rules

Established by the audit in §3.2: **BSData's encoding disagrees with the printed rules in at least two places** — enhancement slot counts, and how Unit Upgrades consume slots. The ETL must therefore treat BSData as a *structural* source, not an *authoritative* one, and validate its derived limits against a small hand-maintained table of rule values. See §3.3 step 5.

---

## 1. Locked decisions

| Decision | Choice |
| --- | --- |
| Stack | **Flutter** |
| Rules data | **`40kdc-data` as primary source** (CC BY 4.0, already normalised, includes stratagems + missions); BSData/MFM retained as an independent cross-check. See §3.0 |
| Local storage | **Drift (SQLite)**, with FTS5 for datasheet search |
| v1 import formats | Plain-text list export · BattleScribe `.rosz`/`.ros` · New Recruit / Army Forge JSON · QR from another app instance |
| Backend for v1 | **None.** Datasets are static hosted files; QR sharing is peer-to-peer |

---

## 2. Architecture: three layers

The governing split. Everything downstream — import, QR, sharing, the play screen — is easy or hard depending on this separation holding.

```
Content Layer  ──ref──>  Roster Layer  <──reads──  Validation Engine
(versioned,              (user-owned,              (edition plugin,
 immutable)               mutable)                  pure Dart)
```

The validation engine is a pure Dart package with **no Flutter dependency**, so the identical code runs in the ETL, in the app, and later in the server.

### 2.1 Content layer

```
Dataset        { id, edition:"11e", version:semver, sourceRev, pointsRev, publishedAt }
BattleSize     { id, name, points, detachmentPoints, enhancementSlots }
Faction        { id, name, parentId?, armyRules[] }
Detachment     { id, factionId, name, rule[], stratagemIds[], enhancementIds[],
                 upgradeIds[], dpCost:1..3, uniqueTags[], forceDisposition,
                 restrictions }
Datasheet      { id, factionId, name, keywords[], factionKeywords[],
                 composition[], modelProfiles[], wargearOptions[], abilities[],
                 leaderTargets[], transport{capacity, keywordFilter},
                 damagedProfile?, pointsTable[PointsBracket],
                 maxCopies:{ perBattleSizeId: int } }
PointsBracket  { models, modelsMax?, cost, unitCountMin, unitCountMax? }
ModelProfile   { id, name, M, T, Sv, Inv?, W, Ld, OC }
WeaponProfile  { id, name, kind:ranged|melee, range, A, skill, S, AP, D,
                 keywords:[{key:"SUSTAINED_HITS", value:1}, ...] }
Ability        { id, name, scope:core|army|detachment|datasheet|wargear, text, phases[] }
Stratagem      { id, name, cp, turn, phases[], when, target, effect, detachmentId? }

Enhancement    { id, detachmentId, name, points, targetFilter, effects[], text }
UnitUpgrade    { id, detachmentId, name, points, targetFilter, maxInstances:3,
                 effects[], text }
```

**Enhancements and Unit Upgrades are separate entities.** They share the same slot pool, but nothing else:

| | Enhancement | Unit Upgrade |
| --- | --- | --- |
| Target | one **Character** | **non-Character** units |
| Instances | 1 | up to 3, one per unit |
| Slots consumed | 1 | **1 total**, regardless of how many instances |
| Points | once | **per instance** |

Modelling Unit Upgrades as `Enhancement { isUpgrade: true }` was the earlier draft and it is wrong — the slot arithmetic differs (one slot for up to three instances, not one per instance), so a shared `slotCost` field would silently miscount every list using them.

**`WeaponProfile.keywords` must be parsed into structured key/value pairs, never stored as the printed string.** `ANTI-VEHICLE 4+`, `SUSTAINED HITS 1`, `MELTA 2` have to be data so the play screen can filter, sort and highlight on them, and so the builder can compute keyword coverage. BSData exposes this as a single `Keywords` characteristic string (§3.2), so the parser is the only thing standing between raw text and every keyword-driven feature in the app.

**`Datasheet.maxCopies` is a per-battle-size map, not a constant.** The cap is authored per datasheet in the source data and modified by battle size (§3.2), so it is read, not inferred.

**Pricing is `base bracket + Σ per-instance wargear costs`.** Verified in implementation against the reference 2,000 pt list (§6.7):

```
Crisis Fireknife Battlesuits   base 100  (3 models, copies 1-2)
  + 6 × missile-pod @ 5                30
                                      ---
                                      130   ← matches the printed list exactly
```

Two independent mechanisms feed it, and both are easy to miss:

1. **Copy-scaled brackets.** Crisis Fireknife is 100 for the first or second unit and **110 for the third**; Krootox Rampagers 85 then 95. `PointsBracket` therefore carries `unitCountMin`/`unitCountMax` alongside model count, and pricing needs a unit's index among same-datasheet units — so **points are a roster-level computation, not a per-unit lookup**. 17 of 47 T'au datasheets are copy-scaled.
2. **Wargear costs.** `wargear_costs` prices items per instance (`missile-pod` at 5); `wargear_budgets` grants free but count-capped items (3 shield drones per 3 models) that contribute legality bounds and no points.

A naive `sum(bracket.cost)` under-prices the reference list by 30 points *per Crisis unit* — 60 points on a 2,000 pt army, which reads as legal when it is not.

**`effects[]` is not decoration.** Both Enhancements and Unit Upgrades can mutate weapon profiles — a real example from the Necron data appends `Assault` to the `Keywords` characteristic of every ranged weapon in the bearer's unit. The play screen must therefore render *roster-resolved* weapon profiles, not raw datasheet ones. See §7.

`Detachment.forceDisposition` is load-bearing well beyond the builder — it is what the play-mode setup screen reads to determine the primary mission. See §4.4.

### 2.2 Roster layer

```
Roster       { id, name, datasetRef{id, version}, factionId,
               detachments:[{detachmentId, dpCost}],
               battleSizeId, pointsLimitOverride?, units[],
               enhancements[], upgrades[],
               warlordUnitId, snapshot?, schemaVersion }
RosterUnit   { instanceId(uuid), datasheetId, customName?,
               models:[{profileId, count, weapons:[{weaponId, count}]}],
               notes }
EnhancementSel { enhancementId, target:instanceId }    // exactly one CHARACTER
UpgradeSel     { upgradeId, targets:[instanceId] }     // 1–3 units, 1 slot total
Link           { type: LEADS | EMBARKED_IN, fromInstanceId, toInstanceId }
```

Four deliberate choices:

1. **Detachments are a list, not a field.** 11e allows multiple detachments bought from a Detachment Points budget (§4.4). This is the single biggest structural difference from a 10e-shaped model, and retrofitting it later would touch the builder UI, validation, import, and the mission screen at once.
2. **Enhancements and Upgrades are roster-level selections with targets**, not fields on the unit. An Upgrade with three targets is one selection, one slot, three point charges — irreducible to a per-unit field.
3. **Attachments are explicit edges, not nesting.** A Captain leading an Intercessor Squad is two `RosterUnit`s plus a `LEADS` link. Nesting looks natural until the play screen must show them as one combat unit, the builder must price them separately, and the leader can detach mid-game. Edges handle all three.
4. **Rosters pin a dataset version and carry a snapshot.** A points update must never silently mutate a saved list; upgrading to a newer dataset is an explicit action with a visible diff. The `snapshot` — a denormalised copy of every datasheet the roster touches — is what makes the play screen work fully offline and lets an imported list from a stranger render even when you lack their catalogue.

`pointsLimitOverride` exists because the source data supports it (§3.2) and because casual and narrative play needs it.

> **A roster records a unit's complete loadout, not only its paid upgrades.** Learned the hard way: a fixture listing just the point-bearing wargear priced correctly and then rendered four units with *no weapons at all* on the shooting screen. Pricing needs the paid items; the play screen needs everything the unit actually carries. Import paths must populate the full loadout — War Organ's text export does list every weapon including defaults (§6.7), so this costs nothing at the import boundary and is expensive to discover later.

**Stable semantic IDs**, e.g. `wh40k11.adeptus_astartes.datasheet.intercessor_squad`. Never renumbered. An alias table maps BSData GUIDs onto them so ingest survives upstream churn. QR and cross-app import depend entirely on this stability.

### 2.3 Validation engine

Data-driven where possible, hand-written per edition where not. Every result is a **finding with a severity** (`error` / `warning` / `info`) and never a hard block — people build illegal lists on purpose, for narrative games, works in progress, and proxies.

All numeric limits come from `BattleSize` and `Datasheet.maxCopies`, never from constants. 11e scales almost everything with game size.

Checks:

- Points ≤ battle size limit (or `pointsLimitOverride`)
- Σ detachment DP cost ≤ `battleSize.detachmentPoints`, **with the Incursion 3 DP exception** (§4.4)
- At most one **3DP Detachment** per force
- No two detachments sharing a Unique Tag; no detachment taken twice
- Copies of each datasheet ≤ `datasheet.maxCopies[battleSizeId]`
- **Slot budget:** `count(enhancements) + count(distinct upgrades) ≤ battleSize.enhancementSlots`
- Each enhancement at most once per roster; targets exactly one **Character**
- Each upgrade at most once per roster; 1–3 targets, all **non-Character**, at most one instance per unit; points charged per instance
- Exactly one **Warlord**
- Unique / named **Epic Hero** at most once
- Unit composition and wargear ratios
- Leader legality (`leaderTargets`) and transport capacity

The slot-budget line is the one to get right: **`count(distinct upgrades)`, not `count(upgrade instances)`.**

---

## 3. The ingest pipeline

### 3.0 Source decision — `40kdc-data` as primary

Audited 2026-08-11: [`wn-mitch/40kdc-data`](https://github.com/wn-mitch/40kdc-data), "community-owned data schemas for Warhammer 40,000 developer tooling". It resolves both of the project's blocking problems and substantially replaces §3.1–3.3.

**Licensing is explicit and permissive** — the reason §0 existed:

| Layer | Licence |
| --- | --- |
| Data | **CC BY 4.0** — redistribute and adapt, commercially, with attribution |
| Schemas | **CC0** |
| Tools | **MIT**, plus a "Powered by 40kdc-data" notice + link for public deployments |

(GitHub reports `NOASSERTION` only because the licence is split across three files.)

**It contains what BSData does not.** 35 faction directories, each with `units`, `weapons`, `wargear`, `wargear-options`, `unit-compositions`, `detachments`, `enhancements`, `leader-attachments` and **`stratagems`** — plus core-level `missions`, `mission-matchups`, `secondary-cards`, `deployment-patterns`, `force-dispositions`, `terrain-layouts`, `terrain-templates`, `target-profiles`, `weapon-keywords`.

Sample T'au stratagem — precisely the fields §7.3's tracker needs, none of which can be derived:

```json
{ "id": "a-tempting-trap-kauyon", "name": "A TEMPTING TRAP",
  "category": "detachment", "type": "battle-tactic", "detachment_id": "kauyon",
  "cp_cost": 1, "phases": ["shooting"], "player_turn": "your-turn",
  "timing": "once-per-phase", "target_restrictions": null }
```

`mission-matchups.json` holds 25 disposition pairings at the **`launch`** dataslate — the §4.4 table, as data. `leader-attachments.json` supplies the `LEADS` relationships that §6.5 flagged as the biggest lossy import relationship.

**It is already normalised**, so §3.3's link resolution, modifier evaluation and constraint flattening — the genuinely hard parts — largely disappear. An `enrichment/` layer goes further, carrying structured ability effects rather than prose:

```json
{ "ability_id": "scouts-7", "effect": { "type": "movement-modifier",
    "modifier": { "move_type": "scout", "distance": 7 } } }
```

That is a more developed version of §2.1's `effects[]`, and it is what makes §7.6's honesty requirement tractable.

**It carries no GW rules text.** Deliberate, and the correct copyright posture — but it means the app can show a stratagem's name, cost, phase and timing, not its printed wording. Good enough to *track*; not a substitute for the player's own codex. Only 7 of 43 T'au stratagems currently link to a structured ability.

#### Risks

1. **Maturity and bus factor.** ~21 stars, effectively one maintainer, active but young (`11e-migration.md`, `gap_analysis.md`, `todo.md` all in flight). BSData has ~2,000 stars and a large contributor base. Mitigation: CC BY permits vendoring and forking — pin a revision, vendor it, and the project survives upstream stalling.
2. **Mixed dataslates.** Mission data is at `launch` (2026-06-20). All 43 T'au stratagems are still `pre-launch-provisional`, ported from the 10e archive. **Filter and surface `game_version.dataslate` in the UI** — never present provisional data as current.
3. **No rules text**, as above.

#### Resulting architecture

**`40kdc-data` primary, BSData/MFM as an independent verification source.** Two lineages disagreeing on a points value or a constraint is a high-quality data signal, and it reuses the override-and-assert machinery already specified in §3.3 step 5. The coverage report becomes a three-way diff: 40kdc vs. BSData vs. the hand-maintained rules table.

### 3.5 Cross-checking against the Munitorum

`BSData/wh40k-11e-mfm` is **MIT licensed** — unlike the catalogue repo — and is parsed from `mfm.warhammer-community.com`, Games Workshop's own published points. That makes it a better cross-check than the catalogue: independent of 40kdc, unambiguously licensed, and closer to the source of truth for points.

`tools/fetch-mfm.sh` retrieves it; `bin/crosscheck.dart` compares. **Nothing from it is shipped.** It exists to answer one question: where do two independently derived lineages disagree?

Compared: unit points per (copy index, model count) bracket, detachment points, force disposition, unique tags, and enhancement costs.

> **The cross-check does not decide who is right.** It reports and leaves the judgement to a person. One that silently picked a winner would just be a second, quieter source of error — and that caution earned itself immediately: the T'au tag divergence resolved **against** the Munitorum. `Retaliation` is the correct tag; the Munitorum parse says `Battlesuit`. Neither source is authoritative.
>
> Settled disagreements go in `crosscheck-accepted.yaml`, keyed by faction, kind and a subject prefix, and are suppressed from the report while still being counted. **A reason is mandatory** — an accepted divergence with no explanation is indistinguishable from one nobody looked at. Without this the tool could never gate a build, because known-and-fine findings would fail it forever.

**Faction slugs differ between the sources.** The primary data calls the Space Marines `adeptus-astartes`; the Munitorum calls them `space-marines`. `mfmSlugFor` holds the alias table — only genuine renamings belong in it, since chapters with their own file in both sources are not aliases.

**Results across the three shipped factions:**

| Faction | Compared | Divergences |
| --- | --- | --- |
| Necrons | 52 units, 12 detachments | **none** |
| T'au Empire | 43 units, 7 detachments | 2, cosmetic |
| Adeptus Astartes | 103 units, 15 detachments | **6, real** |

T'au's two are a naming difference, and are now **settled in 40kdc's favour**: the tag is `Retaliation`, and the Munitorum parse is the wrong one. Both sources agree the two detachments *share* a tag, so validation behaved identically regardless. They are recorded in `crosscheck-accepted.yaml` and no longer reported.

**Adeptus Astartes has genuinely stale points**, verified against both raw sources:

```
Repulsor Executioner                     40kdc 240 / 260   MFM 255 / 275
Vanguard Veteran Squad with Jump Packs   40kdc 100 / 200   MFM 105 / 210
                                  (3rd+) 40kdc 110 / 210   MFM 115 / 220
```

Every gap runs the same direction — 40kdc is cheap — which is the signature of a missed points update rather than a transcription slip. **This is the failure the cross-check exists to catch:** a 2,000 pt list carrying a Repulsor Executioner validates as legal in the app while actually being 2,015. Worth reporting upstream, and worth running before every dataset build.

Two lessons came from its own false positives, and both are now pinned by test:

- **Match model counts through `bracketFor`, not by key.** A primary bracket may cover 4–6 models where the Munitorum lists the endpoint; exact-matching reported every such bracket as missing.
- **Exclude `addon: true` entries.** A Tidewall Defence Platform is priced at the same model count as the unit it attaches to, so treating it as the unit's cost made the unit look 65 points cheaper.

That is the pattern to expect from any cross-check: the first run is mostly your own bugs, and the real signal only appears once they are weeded out.

### 3.6 Corrections — when the data is simply wrong

The cross-check catches *disagreement*. It cannot catch the case where both sources are silent about something the rulebook says, and that turns out to be the more dangerous failure, because it renders as confident text.

The founding case: Broadside Battlesuits' **Advanced Armour** is encoded upstream as

```json
{"type": "feel-no-pain", "target": "unit", "modifier": {"threshold": 4}}
```

which the renderer faithfully turned into `Feel No Pain 4+`. The actual rule applies **only to mortal wounds**. Nothing in the data was contradictory — it was incomplete in a direction that promised the player a save they do not have.

Three ways to fix that, and only one is honest:

- **Special-case it in the renderer.** Rejected. §7.6 says the renderer states what the data says; a renderer that knows one ability by name is lying about where its knowledge comes from, and the next such ability gets missed.
- **Fork the snapshot.** Rejected. `tools/fetch-40kdc.sh` would overwrite it, and nobody could see what had been changed or why.
- **Correct the data at build time, from a file a person can read.** Taken.

`data-corrections.yaml` at the repo root lists ability effects to replace, each with a mandatory `reason` and an `upstream` field recording where the problem has been reported. `DatasetLoader` applies them as it reads, so the bundler, the snapshot writer and the coverage report all see the same corrected data — while the cross-check deliberately constructs its loader **without** them, so it keeps comparing upstream against upstream.

Two rules stop this becoming a private fork:

- **No reason, no correction** — the same bar as an accepted divergence. Unexplained is indistinguishable from unexamined.
- **A correction that matches nothing is reported.** The bundler warns and a test fails. Otherwise an entry upstream has since adopted goes on shadowing data that is now correct, forever, and silently.

The corrected record carries its own provenance: a `corrected: {reason, upstream}` key travels with the ability into the shipped bundle, so the explanation is in the data rather than in a build log nobody kept.

`faction: "*"` matches an ability in every faction that carries it. Core abilities are transcribed once per faction file, so a mistake in one is usually a mistake in all of them — **Stealth is wrong identically in all three**. A wildcard is only reported stale once a whole run has gone by without it firing anywhere; a faction that simply lacks the ability is not evidence of anything.

**Aliases — one rule under two ids.** Upstream transcribes an ability once per datasheet that has it, and the datasheets do not agree on the plural: a Ghostkeel has a Battlesuit Support System, a Crisis Starscythe has Battlesuit Support Systems, and the effect records are identical. Left alone that is untidy; under §7.3.9 it is wrong, because whether a rule is *shared* is decided by counting the datasheets carrying its id, so a stray plural splits one shared rule into two rules nobody shares and files the same sentence in two different places.

An `aliases:` entry names the duplicate and the `canonical` id it folds into. Every reference is rewritten — ability lists and wargear budgets both, since a support system is offered as wargear and named there by the same id — and the duplicate record is dropped. Two safeguards: the duplicate is removed **only once its canonical twin is confirmed present**, so a typo in `canonical` can never be the reason a rule disappears; and an alias is a merge, never a rename, so it cannot introduce an id upstream does not have. A test fails if two ids in any faction differ only by a plural and render the same effect, so the next one gets noticed rather than quietly splitting a tier.

### 3.7 What the first play-test found

Seven complaints from one game, and the useful thing about them is that they sort into three quite different causes. Worth recording, because the ratio is not what it looks like from the screen: **most of what read as bad data was our own rendering.**

**Our bugs** — the data was right and the app was not:

- **Twelve operations rendered as two.** `_signed()` knew `add` and `subtract`. The data uses `set`, `improve`, `worsen`, `multiply`, `halve`, `crit-on`, `improve-vs-D1`, `set-on-crit-wound` and more. So the Coldstar Commander's *Move set to 12* rendered as **`+12 Move`** — on a suit that already moves 12, a plausible-looking lie. Thirty-odd abilities were affected.
- **`{operation: add, value: -1}` lost its sign**, because the magnitude was taken before the sign was applied. Thirteen AP *improvements* across three factions read as `+1 AP`, the opposite of what they do. Starscythe was one.
- **Whose characteristic changes was never stated.** Enforcer Commander worsens the **attacker's** AP; rendered ownerless as `+1 AP` it reads as a buff to the Commander. Only `attacker` and `defender` get an owner prefix — the data uses `attacker` inconsistently enough (defensively for Stealth, offensively for Hunter's Instincts) that inventing a longer sentence would be guessing.
- **Weapon keyword parameters were discarded at parse.** `melta` is Melta **2**; `anti` is Anti-**Infantry 4+**; `rapid-fire` is Rapid Fire **N**. **201 of 920 keyword instances** in the snapshot carry a parameter, and every one of them was being dropped — twice, in fact, since the import screen re-serialised profiles as bare `keyword_id`s on the way into a snapshot. The parameters are now part of the profile key too, so a Melta 2 and a Melta 4 no longer aggregate into one row.
- **An invulnerable save granted by an ability never reached the statline.** Both encodings exist upstream: most models carry `invuln_sv`, but the Coldstar's 4+ lives only in its `shield-generator` ability. The INV column read the profile alone, so a unit with an invulnerable save showed none. Conditional grants are deliberately *not* folded in — a save that applies sometimes is a rule to read, not a number in a column that says "always".
- **An attached unit's abilities were listed unattributed.** The Shield Generator belongs to the Commander in Coldstar Battlesuit, not to the Crisis Starscythe suits it leads, and a flat union said otherwise. Rules now name their datasheet whenever the group has more than one.

**Wrong data** — corrected in `data-corrections.yaml` (§3.6): Stealth, and Broadside Advanced Armour.

**The seventh, the missing drones, took a wrong turn first.** See §3.8.

### 3.8 Drones are wargear, and the model gets the rules

My first reading of the missing drone profiles was wrong, and worth recording because the wrong reading was the expensive one. I took "no drone statline in the data" as an upstream gap that could only be closed by authoring drone datasheets. It is not a gap. **In 11th edition a drone is not a model — it is wargear, and the model that takes one gains its rules.** The data models exactly that: a name-only `wargear` stub for the choice, and an ability for what it does. Nothing was missing from the encoding.

What was missing was on our side, in three places.

**The importer recognised drones and then threw them away.** `_tallyWargear` matched `Gun Drone With Twin Pulse Carbine and Shield Drone` against the datasheet's abilities, concluded "yes, that is a real thing" — and returned without recording it. The real export carries drones on nine of sixteen units and **not one reached the roster**. Consequences that all read as separate bugs: no twin pulse carbines in the shooting table; Shield Drones absent; and every drone a datasheet *could* take listed on units that had bought none, because the rules list was reading `ability_ids` while the roster knew nothing.

Drones are now recorded as ordinary `WargearSelection`s keyed by the ability id. That one change makes the roster the single answer to "what does this unit have", which the rest hangs off.

**Wargear that is an ability can still bring a gun.** `gun-drone` is not a weapon id, so the aggregator called it unresolved. It now follows an `ability-grant`'s `weapon_id` to the weapon, and so does the snapshot builder — otherwise a list rebuilt from a snapshot alone, the case snapshots exist for, would be short a weapon.

**Optional is not the same as fitted.** A Crisis suit may take a Gun, Marker or Shield Drone. Showing all three on a unit that bought two is three rules to read and one of them false. An ability that appears in `wargear_budgets` is now shown only when the roster unit carries it — and the statline reads the same filtered set, so the INV column and the rules text cannot disagree about whether a Shield Generator was bought.

That last rule exposed a contradiction upstream: the Commander in Coldstar Battlesuit lists `shield-generator` in **both** `ability_ids` and `wargear_budgets`, so a list that never mentions buying one is ambiguous. Corrections gained `standard_wargear` to settle it.

Six T'au datasheets do not list the drones their units demonstrably carry — Commanders, Starscythe, Stealth, Broadsides, and the Ghostkeel's support system. Those are `units:` corrections, evidenced by a validated export of a legal 2,000 point list.

**And some drones name a weapon that does not exist.** `missile-drone` and `mv15-gun-drone` recorded `{grant_type: ranged-weapon}` with nothing to resolve, and the Recon Drone names `drone-burst-cannon`, which is simply absent from `weapons.json`. A grant pointing at no record is silently no weapon at all, so corrections gained a `weapons:` section that can **add** a record, not only patch one.

The rule turned out to be general, and worth encoding as a rule rather than four stat blocks: **a drone's gun is its namesake fired at BS5+.** `derive_from` builds the record from another weapon and overrides the skill, so an upstream revision to the missile pod carries to the drone's automatically — copying the stat block would silently stop tracking it.

That generalisation also caught a mistake. The Gun Drone's grant had been pointed at the plain `twin-pulse-carbine`, which is BS4+: the drone was firing at the skill of the battlesuit carrying it. Three derived weapons now exist — `drone-missile-pod`, `drone-burst-cannon`, `drone-twin-pulse-carbine` — and one written out, `twin-pulse-blaster`, because the MV15's gun is 12" with TWIN LINKED where upstream's `pulse-blaster` is 10" without, so it is *not* simply its namesake at BS5+.

A test walks every ability grant and fails on a weapon id with no record. Its known-exceptions set is now empty, and it fails in both directions, so a new dangling grant and an upstream fix are both noticed. That check is what found the Recon Drone's missing weapon in the first place.
Two more turned out to be wrong data rather than gaps, once the exact wording was to hand. Both are now corrections:

- **Coldstar Commander** grants ASSAULT to the whole squad's ranged weapons as well as setting Move to 12. Upstream had only the Move part, so the app advertised a mobility buff and said nothing about shooting after Advancing — which is the reason to field it.
- **Starscythe** improves AP by 1 against everything *except* VEHICLE and MONSTER. Upstream had no restriction, so the app promised the bonus against precisely the targets where it does not apply.

The second needed a small renderer addition. Two negated `target-has-keyword` conditions joined by "and" is unreadable at the table, so an `excluded_keywords` form renders as `except vs VEHICLE or MONSTER`, and an `and` chain joins an exclusion with a comma rather than another "and".

### 3.9 Every faction, and the twelve that have no datasheets

Upstream publishes **35 playable factions**. Twenty-three carry a full catalogue. The other twelve — Black Templars, Blood Angels, Crimson Fists, Dark Angels, Deathwatch, Imperial Fists, Iron Hands, Raven Guard, Salamanders, Space Wolves, Ultramarines, White Scars — are **Space Marine chapters, and they publish no datasheets at all**. A Blood Angels army fields Adeptus Astartes units; what the chapter adds is its own detachments, stratagems, enhancements and army rule.

`factions.json` says so directly, in `parent_faction_id`. The chapters' own files are *already merged* — Blood Angels' `detachments.json` holds 15 of the 16 Astartes detachments plus 9 of its own — so the inheritance is needed for datasheets and nothing else.

**The parent is followed at load time, not flattened at build time.** Copying the Astartes datasheets into each of the twelve would add roughly 840 KB to a 725 KB download, for data already present. Instead the manifest names `parentId`, and both readers — `DatasetLoader` for the CLI, `DatasetRepository` for the app — fall through to the parent for the datasheet files only. A chapter bundle is 5–8 KB.

Two things this arrangement has to get right, both pinned by test:

- **Corrections are keyed by the faction that owns the record.** An inherited datasheet is corrected as the parent's, or every one of the twelve chapters would need its own copy of every Adeptus Astartes correction.
- **A chapter keeps its own army rule.** Blood Angels is The Red Thirst, not Oath of Moment. Only datasheets are inherited.

**A faction with no datasheets *and* no parent is skipped** — that is an upstream stub, not something to offer in the picker.

> **The faction record was never bundled.** `factions.json` carries the display name and the army rule, and `_factionFiles` did not list it — so `factionRuleId` arrived null in the app and **every roster built or imported there lost the one rule its whole army has**. The CLI reads the snapshot directly and kept it, which is exactly why nothing noticed: the reference snapshot in `assets/` was built by the CLI and has `for-the-greater-good` in it. Same shape as the corrections bug of §3.6 — two readers, one of them tested. A test now asserts the rule survives the trip through the bundle and into a snapshot.

Bundling the record also fixes the names: the manifest said *Tau Empire*, because it title-cased the id. It now says **T’au Empire**, because the data does.

**Upstream integrity gaps, in 4 of 35.** Adeptus Astartes, Crimson Fists, Raven Guard and Orks each carry stratagems whose `detachment_id` names a detachment the data never publishes — `shadowmark-talon`, `vengeful-hosts`, `equatorial-hordes`, `liberator-assault-group` on the wrong chapter. Harmless in play, because stratagems are scoped to the detachments a roster actually took, so these can never appear; but `bin/coverage.dart` exits non-zero on them and should keep doing so. Worth reporting upstream rather than suppressing.

### 3.1 Upstream sources (BSData — now the cross-check, not the primary)

Two repositories, both community-maintained:

| Repo | Contents | Use |
| --- | --- | --- |
| `BSData/wh40k-11e` | Game system + per-faction catalogues | Structure: datasheets, profiles, detachments, stratagems, constraints |
| `BSData/wh40k-11e-mfm` | Snapshots parsed from `mfm.warhammer-community.com` | Points. Drives the `pointsRev` bump and the dataset-upgrade diff |

**The 11e data is JSON, not the older `.cat`/`.gst` XML.** Files are per-faction (`Necrons.json` ≈ 2 MB, `Aeldari - Craftworlds.json`, …) plus a `Warhammer 40,000.json` game-system file (≈ 1.2 MB) with a top-level `gameSystem` key. The logical model is still BattleScribe's — `costTypes`, `profileTypes`, `categoryEntries`, `forceEntries`, `entryLinks`, `sharedSelectionEntries`, `sharedSelectionEntryGroups`, `sharedProfiles`, `sharedRules` — so everything below applies, but the parser is a JSON reader.

### 3.2 What the source data gives us — verified by direct audit

Read from `Warhammer 40,000.json` and `Necrons.json` on 2026-08-11.

**Cost types are the budget system.** `pts` (`51b2-306e-1021-d207`), **`Detachment Points`** (`82ae-1066-5107-6ae0`), **`Enhancements`** (`f759-1bc4-cb3a-f0d2`), plus Crusade trackers. DP and enhancement slots are budgets in the same machinery as points, so one extraction path in the ETL yields all three.

**Profile types** map onto the schema directly:

| Profile type | Characteristics |
| --- | --- |
| `Unit` | M, T, Sv, W, LD, OC, **InSv** |
| `Ranged Weapons` | Range, A, BS, S, AP, D, **Keywords** |
| `Melee Weapons` | Range, A, WS, S, AP, D, **Keywords** |
| `Abilities` | Description |
| `Transport` | Capacity |

**Battle-size budgets live as modifiers on the `Army Roster` force entry** (`bb9d-299a-ed60-2d8a`), whose base constraints are DP max 2, points max 0, enhancements max 2 — Incursion is the baseline and larger sizes are modifiers on top.

**Force Dispositions are categories in the game system** — `Take and Hold` (`1cc1-f11a-4e8f-1bcc`), `Purge the Foe` (`6fe0-3dbe-f7e0-10bb`), `Reconnaissance` (`b4a7-5083-fe94-4d24`), `Priority Assets` (`0936-9767-1cc7-52ae`), `Disruption` (`ecf8-cf72-7d5b-1b5b`) — and every detachment carries one as a `categoryLink`. **No side-table needed**; the ETL reads disposition for free.

**Detachments** are selection entries carrying a `Detachment Points` cost, `max=1/parent`, a disposition category, a `3DP Detachment` category when applicable, and their Unique Tag as a category. From Necrons:

| Detachment | DP | Disposition | Unique Tag |
| --- | --- | --- | --- |
| Awakened Dynasty | 3 | Take and Hold | Dynasty |
| Canoptek Court | 3 | Take and Hold | — |
| Starshatter Arsenal | 3 | Priority Assets | — |
| Annihilation Legion | 2 | Purge the Foe | — |
| Hypercrypt Legion | 2 | Reconnaissance | Hypercrypt |
| Hand of the Dynasty | 1 | Take and Hold | Dynasty |
| The Phaeron's Armoury | 1 | Priority Assets | Hypercrypt |

**Unique Tags are catalogue-level categories with `max=1/force`** — `Dynasty` (`d887-58b7-5a1c-5ef0`), `Hypercrypt` (`822d-f1bf-4a26-6d70`). Identical mechanism to Epic Hero uniqueness, so one validator handles both.

**Per-datasheet caps are per-datasheet categories with a battle-size modifier.** `Royal Warden` is `max=3/force`, set to `2` when Incursion is selected. `Necron Warriors` (Battleline) is `max=6`, set to `4` at Incursion. `Ghost Ark` (Dedicated Transport) is `max=6`. Epic Heroes are `max=1/force`. Onslaught has no modifier, so it inherits the Strike Force caps.

**Enhancements and Unit Upgrades are distinguishable by constraint shape.** Of the 38 slot-costing entries in Necrons: 33 are `max=1/roster` (Enhancements) and 5 are `max=1/parent` + `max=3/force` (Unit Upgrades). That shape difference is the classifier the ETL should key on.

> ⚠ **Two places where BSData contradicts the rules.** Both concern slots, and both would silently produce illegal lists if trusted:
>
> 1. **Slot count at Strike Force.** BSData applies a single modifier — "4 if Incursion is not selected" — which is correct at Onslaught but wrong at Strike Force, where the rule is **3**. A one-line omission rather than a design decision: the modifier is missing its Strike Force case. Worth reporting upstream.
> 2. **Upgrade slot cost.** BSData charges **1 slot per upgrade instance**, with no modifier discounting instances 2 and 3. The rule is **1 slot for up to three instances**.
>
> Neither can be detected from within the data. The ETL needs an explicit override table (§3.3 step 5), and the app must compute upgrade slots itself rather than summing the `Enhancements` cost type.

**Unit Upgrades can rewrite weapon profiles.** *Deepening Madness* (20 pts, `max=1/parent` + `max=3/force`) carries a modifier appending `Assault` to the `Keywords` characteristic of every ranged weapon in the bearer's unit, recursively. The most consequential finding for play mode — see §7.

**Custom points limits are supported** via an `Override points limit?` toggle (`c6ea-562c-984f-6c25`) and an incrementing `Points limit` entry (`83ac-f5e5-d3da-5441`), which is what `Roster.pointsLimitOverride` maps onto.

**Exactly one Warlord** — the `Warlord` category (`5c0e-4c31-d51b-e470`) is `min=1 max=1` at roster scope. There is no separate min-Character constraint; the Warlord requirement carries it.

Also present and not yet investigated: `Leader` (`1556-9b56-fba6-4370`) and `Support` (`7dcd-7f61-69a7-0294`) categories at the system level.

### 3.3 Transformation steps

In rough order of difficulty:

1. **Link resolution** — `entryLink` → `sharedSelectionEntries`, `infoLink` → `sharedProfiles`/`sharedRules`, plus `catalogueLink` imports across faction files. Everything is indirection; resolve it into flat inlined entries.
2. **Profile extraction** — map the profile types in §3.2 onto `ModelProfile` / `WeaponProfile` / `Ability` / transport capacity.
3. **Cost extraction** — pull `pts`, `Detachment Points` and `Enhancements` per entry; flatten point brackets into `pointsTable[{modelCount, points}]`.
4. **Category classification** — one pass over `categoryLinks` yields force disposition, unique tags, `3DP Detachment`, Battleline/Dedicated Transport, Epic Hero, and faction keywords. Also splits Enhancements from Unit Upgrades by constraint shape. Cheap and high-value; do it early.
5. **Battle-size resolution, with a rules override table.** Evaluate the force-entry and per-datasheet constraint modifiers once per battle size and emit a resolved `BattleSize` table plus `Datasheet.maxCopies` maps — then **assert every derived value against a hand-maintained table of known rule values and fail the build on mismatch**. The §3.2 warning is why: "read the limits from the data" is the right default and the wrong absolute. The override table has exactly one entry today: `enhancementSlots` = **2 / 3 / 4** against BSData's 2 / 4 / 4 — a single wrong value, at Strike Force.
6. **Keyword parsing** — split the `Keywords` characteristic into structured pairs. Keep a keyword registry with an `unknown` bucket and **fail loudly** on unrecognised tokens.
7. **Composition & wargear constraints** — `constraints` with min/max and scope (`parent` / `force` / `roster`), plus `repeats` / `includeChildSelections` for "1 in every 5". Normalise into the declarative form.
8. **Modifiers** — the rest of BattleScribe's conditional modifier system is the part **not** to reimplement wholesale. Evaluate static ones; capture enhancement and upgrade → profile effects (§3.2) as structured `effects[]`; emit anything else into a `raw` escape-hatch field.

> **Governing principle: be a normaliser with a documented coverage gap, not a BattleScribe engine.**

Every build publishes a per-faction **coverage report** (`93% of datasheets fully resolved, 14 with raw fallbacks`) plus the **override-table diff**, so both data quality and rules divergence stay visible.

### 3.4 Distribution

Output is per-faction JSON bundles plus a signed manifest, gzipped and content-hashed, hosted as **static files** (GitHub Releases, Pages, or R2). The ETL runs as a scheduled GitHub Action watching both upstream repos. **Gated on the §0 licence check.**

---

## 4. Army builder

### 4.1 Screen structure

```
Rosters (home)
 └ New roster wizard:  faction → battle size → detachment(s), spending DP
 └ Builder
     ├ Units tab        — grouped by role; attachments shown indented under their
     │                     leader; sticky points/CP/DP bar; validation chip
     ├ Detachments tab  — DP budget, Unique Tag conflicts, resulting Force
     │                     Dispositions, combined stratagem + enhancement pool
     ├ Datasheet picker — FTS search + filters (role, keywords, points band)
     ├ Unit config sheet— composition stepper, wargear options, "attach to…" picker
     ├ Enhancements     — shared slot budget; Enhancements assigned to Characters,
     │                     Unit Upgrades assigned to 1–3 non-Character units
     ├ Stats tab        — see §4.2
     └ Share sheet      — see §6
```

The **Detachments tab is new and non-optional**. With multiple detachments, a DP budget, Unique Tag exclusions, and a merged stratagem/enhancement pool, detachment selection stops being a one-off wizard step and becomes a screen you return to throughout list building.

The Enhancements screen must show slots as **`used / total` where a three-target Upgrade reads as 1** — the most likely place for the app to quietly mislead someone into an illegal list.

### 4.2 Statistics preview

- Total points, CP, **DP spent / available**, **slots used / available**
- Model count, total wounds, total OC
- Drop count
- Toughness / Save distribution (including invulnerables, via `InSv`)
- **Keyword coverage** — ANTI-TANK, DEVASTATING WOUNDS, PRECISION, sticky objectives, deep strike, scout
- **Force Dispositions** the list produces, and therefore which primary missions it can draw

Keyword coverage is the stat that actually changes list decisions, and it is only computable because weapon keywords are parsed at ingest. Force disposition is the stat unique to 11e — your detachment choice picks your missions, so it belongs on the list-building screen, not only in play mode.

### 4.3 Flutter implementation notes

- **Drift (SQLite)** for both datasets and rosters. FTS5 is the decider — the datasheet picker lives or dies on fast fuzzy search — and Drift also brings a real migration story. Avoid Isar; its maintenance situation is shaky.
- **freezed + json_serializable** for the model layer. `Roster.schemaVersion` from day one.
- Downloaded bundles are ingested into SQLite **tables**, not stored as JSON blobs.

### 4.4 11th edition army-building rules

Sourced from the rulebook where marked ✓, from BSData where marked ▣, unconfirmed where marked ⚠.

**Battle sizes**

| Battle size | Points | Detachment Points | Slots | Max copies / datasheet | Battleline & Dedicated Transport |
| --- | --- | --- | --- | --- | --- |
| Incursion | 1,000 | 2 (→3, see below) ▣ | **2** ✓ | 2 ▣ | 4 ▣ |
| Strike Force | 2,000 | 3 ▣ | **3** ✓ | 3 ▣ | 6 ▣ |
| Onslaught | 3,000 | 4 ▣ | **4** ✓ | 3 ▣ | 6 ▣ |

Onslaught gets more Detachment Points but **not** a higher unit cap — it inherits Strike Force's. Dedicated Transport does still receive the doubled cap.

**Detachment Points.** The defining change of the edition: an army takes **multiple detachments** from a DP budget, each costing 1–3 DP by scope — 1 DP for narrow or conditional buffs, 2 DP for classic codex-style detachments, 3 DP for army-wide powerhouses. Detachments carry **Unique Tags**; no two in an army may share one, and no detachment may be taken twice.

> **The Incursion 3 DP exception.** At Incursion your budget rises from 2 to 3 DP *if you take a 3 DP detachment* — so a single big detachment is always legal at any size, but taking one leaves you 0 DP of change. At most **one 3 DP detachment per force**, at any battle size. This is encoded in the data as a conditional modifier and is easy to miss; it is the kind of rule a naive budget check gets wrong.

**Enhancements** attach to a single **Character**, cost one slot plus points, and each may be taken only once per roster.

**Unit Upgrades** are a distinct mechanic sharing the same slot pool. They can be given to **non-Characters**, may be applied to **up to three units** (one instance each), and **all three instances together consume a single slot** — while each instance pays its own points. They exist so detachments built around unit types with no Characters can still spend slots.

**Force Dispositions.** Each detachment is associated with one of five — **Take and Hold, Purge the Foe, Reconnaissance, Priority Assets, Disruption** — and the pairing of your dispositions selects your primary mission from 15 combinations. This is the mechanism that ties list building to the mission you play.

**Other confirmed changes** (reference content, not structural):

- **Stratagems no longer stack** — one stratagem per unit per phase, Command Re-Roll included. See §7.
- **Cover** grants −1 to hit on incoming ranged attacks for Infantry/Swarms/Beasts fully within terrain, rather than a save bonus. Monsters and Vehicles no longer get cover from footprint overlap.
- **Objective markers are gone** — terrain pieces and key positions are the objectives, standardised by a 16-template Terrain Area set.
- **10e codexes remain legal** at launch, so the dataset spans both 10e-era and 11e detachments.

---

## 5. Open questions

- [ ] ⚠ **Licence on `BSData/wh40k-11e`** — see §0. Blocks §3.4.
- [ ] **MFM publication cadence** — how often `mfm.warhammer-community.com` updates, which sets the dataset refresh rhythm. Observable over time from the `wh40k-11e-mfm` commit history.
- [ ] What the system-level **`Leader`** and **`Support`** categories mean in 11e — new battlefield roles, or detachment-slot machinery?
- [ ] Whether the **15 disposition-pair → primary mission** mapping can be derived, or must be entered by the user from the Mission Deck (§0 copyright).
- [ ] Worth checking during ETL bring-up: does BSData's Upgrade-vs-Enhancement constraint shape (`max=1/parent` + `max=3/force`) hold across all factions, or is Necrons' encoding idiosyncratic?

**Closed:** Onslaught DP and unit caps · Dedicated Transport cap · min-one-Character (it is the Warlord constraint) · Epic Hero uniqueness · no flat detachment-count cap — the "max 2" was max 2 *Detachment Points* · Force Disposition is in the data, no side-table needed · Enhancements vs Unit Upgrades are separate mechanics · slots are 2 / 3 / 4, against BSData's 2 / 4 / 4.

**Battle sizes are now fully specified** (§4.4) — the validation engine can be built without further input.

---

## 6. Sharing & import

**v1 scope: QR, BattleScribe `.rosz`/`.ros`, New Recruit** — with the plain-text question reopened, see §6.0.

### 6.0 Source-tool reality check

The scope above assumed lists originate in New Recruit. They do not: the primary tool in use is **War Organ** (`com.zenchovey.warorgan`), an Android/Windows/iPad 40k list builder supporting 10e and 11e, with continuously updated points and rules.

War Organ exports **PDF, plain text, Yellowscribe, TTS, and a proprietary "share code"**. It does **not** export `.rosz`, BattleScribe XML, or New Recruit JSON. So neither v1 parser imports the user's own lists.

This reopens the text decision. Deferring plain text is clean if lists come from BSData-backed builders; it is not if the originating tool only emits text. Text is also what the official Warhammer app produces, which makes it the genuine lowest common denominator regardless of what else ships.

Three candidate paths, in order of expected value:

1. **Plain text — promoted into v1.** Universal, stable, and the one War Organ path certain to keep working. See §6.8: a real export proved far more structured than assumed, and it preserves leader attachment, which `.rosz` may not.
2. **`.rosz`** — the interop standard across New Recruit, legacy BattleScribe and assorted tooling, even though the primary tool does not emit it.
3. ~~**War Organ share code**~~ — **rejected.** A sample resolves to `https://warorgan.com/share/app/01WPXL61`: an eight-character key (≈41 bits) into a server, not an encoded list. The page is a 749-byte React shell loading data from an undocumented API; the app also registers a `warorgan://share/<CODE>` deep link. There is no offline path here at any effort level, and an online one would depend on a third-party API and fail exactly where it matters — at a table with no signal.
>
> This validates §6.4 by contrast: our QR payload is self-contained at ~450 bytes and needs no network. That is a genuine capability difference, not a stylistic one.

Prior art note: War Organ also has a viewer mode with stratagem display, and a user request on record for phase-based stratagem organisation. Relevant to §7 — the list-building half of this space is well served already; the in-game half is where this app has room.

Prior art note: War Organ also has a viewer mode with stratagem display, and a user request on record for phase-based stratagem organisation. Relevant to §7 — the list-building half of this space is well served already; the in-game half is where this app has room.

> Correction to an earlier draft: **Army Forge is OnePageRules' builder, not a 40k one.** The 40k builder landscape is New Recruit, BattleScribe (legacy), and the official Warhammer app (text export only). New Recruit already shares lists by link and QR code, and imports/exports `.ros`/`.rosz`, JSON and text.

### 6.1 One intermediate representation, one resolver

```
.rosz / .ros ──┐
New Recruit ───┼──> ParsedList (loose) ──> Resolver ──> Roster (strict)
QR ────────────┘         │                     │
                    raw ids, names        ResolutionReport
                    counts, costs         (per-item confidence)
```

Parsers know only their wire format. All catalogue knowledge lives in the single resolver. Adding plain text later means writing a third parser, not touching the pipeline.

**Why this is cheap:** BattleScribe rosters and New Recruit exports both reference **BSData catalogue GUIDs** in their `entryId` fields, and the ETL already builds a GUID → semantic-ID alias table (§2.2). These imports are deterministic lookups, not fuzzy matches. Plain text is the sole exception — which is what makes deferring it a clean scope cut rather than a compromise.

### 6.2 BattleScribe `.rosz` / `.ros`

`.rosz` is a ZIP wrapping one `.ros` XML: nested `<selection>` elements carrying `entryId`, `number`, `<costs>`, `<categories>` and embedded `<profiles>`.

The embedded profiles are a useful safety net — a `.ros` is partially self-describing, so the importer can populate a snapshot even for GUIDs that fail to resolve. Degraded, not broken.

### 6.3 New Recruit

NR is BattleScribe-compatible and BSData-backed, so its JSON is *probably* a serialisation of the same object model — but that is inference, not knowledge. **Get a real export before committing to a parser.**

Scoping lever: NR exports `.rosz`, so §6.2 already covers NR users. v1 can ship two parsers instead of three and add the NR-native path once a sample export has been inspected.

### 6.4 QR format

Two decisions define it.

**Reference, not snapshot.** A full snapshot with rules text is tens of kilobytes — impossible for QR. The payload names things; the receiver rebuilds the snapshot from their own dataset copy, downloading it if the referenced version is missing.

**Hash the IDs, don't index them.** Indices into dataset tables are cheaper by a byte but break whenever the two devices are on different dataset revisions — which at a tournament is the common case, not the edge case. Use a **3-byte truncated hash of the semantic ID**, scoped per faction, with collisions checked at ETL build time (widen to 4 bytes for a colliding faction). Version-independent end to end.

```
header   magic(2) fmtver(1) flags(1) part/total(1) datasetId(2) datasetRev(2)
body     faction(3) battleSize(1)
         detachments: n × hash(3)
         units:  hash(3) + modelGroups + weapons[hash(3) + count(1)]
         slots:  enhancements / upgrades hash(3) + targets
         links:  LEADS / EMBARKED_IN, unit-index pairs
         name(utf8, optional)
```

**Size budget.** A 2,000 pt list of ~20 units comes to **≈ 450 bytes** raw, slightly less after deflate — a **v20 QR at error-correction M**, comfortably scannable phone-to-phone. A 3,000 pt Onslaught list lands near 700 bytes and still fits. Encode in byte mode with raw deflate; base45 + alphanumeric mode is the fallback only if field testing reveals scanner trouble.

Full version-independence therefore costs about 150 bytes over an index-based encoding. Take the trade.

`part/total` is in the header despite nothing needing it yet — one byte now avoids a format version bump later.

### 6.5 What is actually lossy

Not the identifiers. The **relationships**:

- **`LEADS` attachments** — whether `.ros` and NR exports record which Character joined which unit is **unverified**; in 10e BSData this was a game-time decision rather than list data. If absent, imports arrive with unattached leaders and the review screen must ask.
- **Unit Upgrades** — BattleScribe represents three instances as three child selections on three different units. The importer must **collapse them into one `UpgradeSel` with three targets**. Failing to do so reads the list as consuming three slots instead of one — the same miscount as the §3.2 BSData bug, arriving by a different route.
- **Detachment sets** — an export must carry all detachments, not one.

Consequently: **never silently import.** Every path terminates on a review screen — *N matched, M ambiguous, K unresolved, these leaders need attaching* — before anything is written to the roster store. QR simply tends to have nothing to review.

### 6.6 Export

v1 exports QR plus the app's own JSON. Writing BattleScribe XML that third-party tools reliably accept is its own project and is not v1 scope; share links wait for §8.

### 6.7 Plain text — the War Organ format

Analysed from a real 2,000 pt T'au export, 2026-08-11. Far more structured than "plain text" suggests.

**It preserves leader attachment.** `ATTACHED UNITS` → `Attached Unit 1..4` groups each Commander with its bodyguard squad; `CHARACTER` and `OTHER DATASHEETS` complete the partition. This is the `LEADS` edge — the biggest lossy relationship in §6.5, and the one `.rosz` may well drop. A format that costs a matcher but keeps attachment beats a structured format that resolves cleanly and loses it.

```
roster      := name "(" N "points)" faction detachLine disposition battleSize section+
detachLine  := name ("," name)* "(" N "Detachment Points)"
section     := ("ATTACHED UNITS" group+) | ("CHARACTER" unit+) | ("OTHER DATASHEETS" unit+)
group       := "Attached Unit" N unit+          → emits LEADS edges
unit        := name "(" N "points)" node*
node        := indent "•" count "x" name node*  → untyped; resolver classifies
```

**Four hard parts:**

1. **Depth-1 bullets are ambiguous.** Uniform units list *wargear* at depth 1 (`Commander` → `1x Battlesuit fists`); mixed units list *models* at depth 1 with wargear at depth 2 (`Crisis Fireknife` → `1x Crisis Shas'vre` → `2x Missile Pod`). Nothing syntactic separates them — only the catalogue knows that `Crisis Shas'vre` is a model and `Battlesuit fists` is a weapon.
   > **Architecture consequence:** `ParsedList` must be an **untyped tree of counted named nodes**, with model-vs-wargear classification deferred to the resolver. This keeps the §6.1 parser/resolver split intact instead of leaking catalogue knowledge into the parser.
2. **Compound wargear.** The same pair appears both split (`1x Gun drone with twin pulse carbine` + `1x Shield drone`) and joined (`1x Gun Drone With Twin Pulse Carbine and Shield Drone`). Match the full string first, then fall back to splitting on ` and ` — never split blindly, since real weapon names contain "and".
3. **Normalisation.** Inconsistent case (`Missile pod` / `Missile Pod`), U+2019 curly apostrophes (`Shas'vre`, `T'au`), varying plurals (`Missile drone` / `Missile drones`), stray trailing whitespace, and `(2000 Point)` singular against `(2000 points)` plural in the header.
4. **Depth-2 counts are group totals, not per-model.** `2x Crisis Shas'ui` with `4x Missile Pod` means two pods each. The parser divides — and a non-integer result means a corrupt list, which is a useful error to surface rather than swallow.

**Still unknown:** the sample contains **no Enhancements and no Unit Upgrades**, so their representation is unverified — including whether a three-target Upgrade prints as one entry or three. That is the case most likely to break the importer, and it lands on the same slot-miscount hazard already guarded in §3.2 and §6.5.

Also unresolved: the export prints a single disposition line (`Reconnaissance`) despite two detachments, where the primary mission derives from *pairing* two dispositions (§4.4). Either both detachments share a disposition, or the field means something else.

### 6.8 Open questions

- [ ] Obtain a War Organ export **containing Enhancements and Unit Upgrades** (§6.7). Highest-value remaining artifact.
- [ ] Resolve the single-disposition-line question (§6.7).
- [ ] Obtain a real **11e `.rosz`** and confirm whether leader attachment and Unit Upgrade targets are represented (§6.5).
- [ ] Obtain a real **New Recruit JSON export** and confirm its schema (§6.3) — or drop the NR-native path, since NR exports `.rosz`.
- [ ] Decide whether to interoperate with **New Recruit's existing QR format** rather than only our own — worth a look before finalising §6.4.

---

## 7. Play mode

### 7.0 The content gap

Verified against the data on 2026-08-11: the game system's `profileTypes`, the catalogue's `profileTypes`, every `typeName`, all 10 `sharedRules`, and the detachment entries themselves. `Awakened Dynasty` carries exactly one thing — an `infoLink` to its detachment rule. The 67 `Detachment Rules` info groups are empty placeholders. **Stratagems appear in BSData only as prose references inside other abilities' text.**

Unsurprising in hindsight: BattleScribe data exists for list building, and stratagems are not list-building data. But it means the feature identified as this app's differentiator has no upstream source.

| Content | Source |
| --- | --- |
| Datasheets, weapons, unit stats, abilities | **BSData** |
| Army rules, detachment rules | **BSData** |
| Enhancements, Unit Upgrades | **BSData** |
| **Stratagems** | **none** |
| **Missions** | **none** — and a GW product (§0) |

> **Superseded in part by §3.0.** `40kdc-data` supplies stratagems (with `phases`, `player_turn`, `cp_cost`, `timing`) and the full mission set (`missions`, `mission-matchups`, `secondary-cards`, `deployment-patterns`, `terrain-layouts`). Both gaps above are filled by a CC BY 4.0 source. What it does **not** supply is GW's rules text, and its faction stratagems are still at the `pre-launch-provisional` dataslate.

### 7.1 Content packs

Content packs remain the right architecture — but their role changes. They are no longer the *only* answer to an empty dataset; §3.0 supplies the baseline. They are now the **user-extension layer**: house rules, new missions as they release, local rules text the user transcribes from their own codex, and community fixes ahead of upstream.

This is what the original brief asked for when it required the setup screen be "customisable to support additional rules".

A **content pack** is a user-editable, importable, shareable JSON layer beside the BSData-derived dataset. Stratagem packs and mission packs are one mechanism with two schemas. **The app ships empty** — a container, with the community supplying content, the same posture already taken on rules data. GW text stays out of the binary, and "the October mission pack" becomes a file rather than a release.

```
StratagemEntry { id, name, source: core|<detachmentId>, cp,
                 turn: your|opponent|either,
                 phases: [command|movement|shooting|charge|fight|end],
                 category: battle_tactic|epic_deed|strategic_ploy|wargear,
                 when, target, effect }

MissionPack    { id, name, edition,
                 primaryTable: { "reconnaissance+take_and_hold": primaryId, … },
                 primaries[], deployments[], twists[],
                 secondaries: { fixed[], tactical[] },
                 rules: { tacticalDrawPerTurn: 2, maxSecondaryVpPerRound: 15 } }
```

`phases[]` and `turn` are what make §7.4 work. They cannot be derived from anything and are cheap to author — a good argument for the pack format being ours rather than scraped from a site whose terms forbid it.

### 7.2 Design principle

The value is not in displaying data — War Organ already displays data. It is in **collapsing the distance between "I am about to do a thing" and "I know the number."** The enemy is navigation.

> **Phase is a scroll axis, not tracked state.** An earlier draft had the player advance a phase state machine so the app could filter. That is six taps per turn, sixty per game, to maintain something the player already knows — the app charging rent for information it should infer. Instead the turn is **one long scrollable page of phase sections**; where you are scrolled *is* the phase, and the section you are reading supplies the context for stratagem filtering and scoring prompts. Nothing to advance, and you can read ahead into the Fight phase without disturbing anything.

Only two temporal values are tracked, both low-frequency and both worth their taps: **battle round** (5 changes per game) and **active player** (10). Everything else is derived or scrolled to.

> **Guard rail: all tracking is optional, and degradation is graceful.** Enter nothing and the app is still a good datasheet browser. Set the phase and stratagems self-filter. Track unit status and one-per-phase enforcement comes free. An app that only pays off after a dozen taps gets abandoned in game two — this is how in-game companions die, and the architecture must make the zero-input path genuinely good.

### 7.3 Pages

A horizontal pager (the brief's "2 or more swappable screens").

**1 · Setup.** See §7.3.1 — it is a decision aid, not a form.

**2 · Turn.** One vertically scrolling page, sectioned by phase. Sticky header carries only round, active player and CP.

```
┌ Round 3 · Your turn · CP 4 ────────────┐   sticky; the only controls
├─────────────────────────────────────────┤
│ COMMAND    battle-shock · stratagems     │
│ MOVEMENT   M values · reserves arriving  │
│ SHOOTING   ranged profiles per unit      │  ← the most-used view in the game
│ CHARGE                                   │
│ FIGHT      melee profiles per unit       │
│ END        scorable secondaries · VP     │
└─────────────────────────────────────────┘
```

Each section carries only what that phase needs — Shooting shows ranged weapon rows, Fight shows melee, Movement shows M and status flags. Sections collapse. Tapping a unit opens its full card. Stratagems and scorable secondaries appear **inline in their phase section**, which is what makes phase-as-scroll-position work: relevance comes from where you are reading, not from state you maintained.

**3 · Army.** Full unit cards — statline, all weapons, abilities, keywords, wounds and models remaining. The reference you jump to when the inline row is not enough. **Roster-resolved** profiles with keyword chips (§7.6). An optional per-weapon "vs T/Sv" strip sits one tap from a weapon row, off by default, and is the single easiest thing here to overbuild.

Stratagems appear inline per phase section with CP affordability greying. Tapping one and choosing a target **commits** it: CP deducted, unit marked as having used a stratagem this phase, event logged. Already-used units appear disabled *with the reason shown*. Each is attributed to its source detachment, which matters at two or three (§4.4).

**4 · Reference.** Army and detachment rules, enhancements and upgrades in play, core-rules quick answers — 11e cover is −1 to hit rather than a save bonus (§4.4), which players will get wrong all year — and search.

### 7.3.1 Pre-game sequence

Force disposition is **a choice, not a derivation**, whenever the roster has more than one detachment. Each detachment carries one disposition (`force_dispositions` in the detachment record), the matchup table is *yours × opponent's* (5×5 = 25 rows, one distinct mission per cell), and the army declares one. Two detachments therefore buy a **choice of primary mission**, made after seeing what the opponent declares.

Worked example — the T'au list of §6.7 (Advanced Acquisition Cadre → `reconnaissance`, Experimental Prototype Cadre → `priority-assets`):

| Opponent declares | You declare Reconnaissance | You declare Priority Assets |
| --- | --- | --- |
| Take and Hold | Reconnaissance Sweep | Secure Asset |
| Disruption | Surveil the Foe | Extract Relic |
| Purge the Foe | Triangulation | Vital Link |
| Priority Assets | Search and Scour | Sabotage |
| Reconnaissance | Gather Intel | Vanguard Operation |

This is the setup screen's reason to exist. No other tool can show it, because the matchup table only exists as data in `40kdc-data`.

> **Show the matrix; never recommend a cell.** The app knows neither the matchup, the terrain, nor how the player plays. Rendering consequences is honest; choosing is overreach.

**Setup is a mandatory pre-game wizard.** Every question is answered before the battle screen opens — no progressive disclosure, no "3 items pending" affordance. The battle screen may therefore assume a fully-specified game, which removes a large class of partial-state handling from §7.3–7.4.

```
1  Start game           roster from builder · opponent: scan QR / name only
2  Battle size          derived from roster
3  Opponent disposition required — it determines BOTH missions (see below)
4  YOUR disposition     ← the decision; grid collapses to their column
5  Missions resolved    yours = (you × them), theirs = (them × you) — different cells
6  Deployment           pick from the 6 patterns
7  Twist                OPTIONAL — skippable, and never re-prompted once skipped
8  Attacker / Defender  roll-off result
9  First turn           roll-off result — separate from step 8, see below
10 Secondaries          Fixed or Tactical (§7.3.2)
11 Deploy               mark units on-board / in reserve
```

Steps 3–5 carry the value; 6–10 are recording and must be fast — a row of chips, not a page each.

**First turn is its own question.** It is decided by a roll-off and is not implied by attacker/defender, so it cannot be derived from step 8. It earns its place in the wizard rather than being defaulted because the battle round is *both players having taken a turn* — knowing who opens is what lets the round advance on its own instead of being stepped by hand (§7.4).

**Step 6 draws the terrain too.** `terrain-layouts.json` publishes 46 competitive tables — every piece placed by position and rotation against a shared template library — and a deployment pattern without terrain is only half a table: in 11e the same pattern with different ruins is a different game. Choosing a published table also **sets the deployment pattern**, because the layout is built on one; offering them as independent questions would let the two disagree on screen.

Three things the layout data settles:

- **The lookup commutes; the mission table does not.** `(A vs B)` and `(B vs A)` are different missions, but they are the *same physical table*, and upstream publishes each pairing once — 15 unordered pairs, 3 variants each. Looking up only the declared order finds nothing for ten of the twenty-five matchups, and the failure reads as missing data rather than a lookup that forgot to commute.
- **Placement is rotate-about-the-template's-origin, then translate.** Verified against all 745 pieces: that convention lands 633 wholly on the board with the rest overhanging an edge by at most 3.73″, while rotating about the footprint's centroid shifts every layout off the long edge — and still looks like a plausible table, which is why it is asserted rather than eyeballed.
- **Templates come as polygons *or* rectangles**, 50 and 19 of them. Reading only `points` leaves nineteen templates' pieces with no outline, and a piece with no outline is not an error anywhere — it simply does not appear.

> ⚠ **These are not Chapter Approved layouts.** Upstream publishes 45 from `battlemaster-11e` and one from `kotc`, and no Games Workshop set at all — `missions.json` carries the Chapter Approved source, the terrain does not. The screen names the source under every table and says plainly that it is not a Games Workshop publication (§7.6). If GW's own layouts are ever published as data, they slot into the same structure.

**Step 6 also draws the zones.** `deployment-patterns.json` publishes them as real geometry — polygons or `width`/`height` rectangles, each with a `position` offset, plus each player's territory and the objective coordinates — so the pattern can be shown rather than described. "Short edge deployment with L-shaped zones" is a sentence about a shape; the shape itself is in the data. Your half is **named** on the picture, not just coloured: the patterns are symmetric under attacker/defender, so the only thing making one side yours is the declaration made several steps earlier, which is exactly what nobody remembers while unpacking models. Opponent's disposition precedes the player's so the grid can collapse to two options at the moment of choosing; if the real sequence is simultaneous, step 4 shows the full 2×5 instead.

**The matchup table is asymmetric.** `(A vs B)` and `(B vs A)` are different cells yielding different missions — 25 ordered pairs, 25 distinct missions, mirrors on the diagonal. Declaring Reconnaissance against Take and Hold means **you** play Reconnaissance Sweep while **they** play Purge and Secure, simultaneously, on the same table. Setup therefore resolves two missions, not one.

**Deployment collapses `LEADS` pairs.** An attached Commander + Crisis squad is one drop, not two. The §2.2 edge model must render as a single deployable entity here — the T'au list is 12 drops, not 16.

### 7.3.2 Secondary missions and the tactical deck

`secondary-cards.json` carries 18 secondaries with **structured scoring**, not just names:

```json
{ "id": "forward-position", "name": "Forward Position",
  "when_drawn": { "operation": "redraw", "battle_round": { "max": 1 } },
  "awards": [ { "trigger": { "timing": "end-of-turn", "player_turn": "your-turn" },
                "when": { "operator": "or", "operands": [ … ] }, "vp": 5 } ] }
```

Two consequences.

**Tactical mode draws for real** — by random pick, not a pre-shuffled pile. Each draw selects uniformly from the cards not yet picked; picked cards are excluded from subsequent draws. State is therefore just a used-set, and because the event log records the *outcome* of each draw rather than a shuffle seed, undo is a plain pop with no replay machinery.

`when_drawn` rules are enforced automatically — *Forward Position* drawn in battle round 1 triggers its redraw-and-reshuffle, and the app says that it did.

**The hand is discardable.** Held cards persist across rounds until scored, but the player may discard any of them at will. This is a player decision, not a rules engine one; the app does not judge it.

**Scoring becomes a prompt, not a memory test.** `awards[].trigger` names timing, phase, player turn and battle-round window. Round and active player are tracked (§7.2); phase comes from the scroll position — so scorable cards surface **inline in the relevant phase section** rather than as an interruption. The app must not auto-score, since it cannot see the board, but it removes the most common way players lose points: forgetting. Round and game caps (`vp_per_round_cap: 15`, `vp_per_game_cap: 45`) come from the mission record.

```
SecondaryState { mode: fixed | tactical,
                 source: app-pick | physical,   ← input mode, not a separate feature
                 used: Set<cardId>, hand[], scored[{cardId, round, vp}], discarded[] }
```

**The deck is a state machine; where picks come from is an input mode.** Players using the physical Chapter Approved deck choose "I drew X and Y" from a list instead of tapping draw; hand tracking, discarding, scoring prompts and caps behave identically. One implementation, two input paths — the §7.2 guard rail applied.

**Deck composition settled:** the Attacker and Defender decks are identical, so there are exactly **18 distinct secondaries** and one pool. The dataset is correct as published; no attacker/defender split is needed.

### 7.3.3 Scoring both players

The app is scorekeeper for both sides. Because missions are asymmetric (§7.3.1), this is not a second counter — the opponent has their own primary mission with its own structured `awards[]`.

That produces a feature worth more than the bookkeeping it was asked for: **the app can show you how your opponent scores.** All 25 primaries carry structured triggers, so once their disposition is known the app can state, for example, that from battle round 2 they score per objective controlled at the end of their Command phase. Knowing the opponent's win condition is how a player decides what to contest — and no existing tool surfaces it, because it needs the matchup table and the primary `awards[]` as data.

```
Score { me:  { primaryMissionId, primaryVp[round], secondaryVp[round] },
        opp: { primaryMissionId, primaryVp[round], secondaryVp[round] } }
```

**Asymmetry of knowledge is deliberate.** The opponent's *primary* is fully modelled — it is derivable from their declared disposition. Their *secondaries* are not: the app cannot know their draws, so it takes a per-round number and does not attempt to mirror the deck of §7.3.2. Modelling hidden information would be inventing it.

Caps apply per side: the mission's own primary cap, plus `vp_per_round_cap: 15` and `vp_per_game_cap: 45` on secondaries.

**Placement.** A compact `You 24 – 19 Them` sits in the sticky header, tappable to expand into the full per-round breakdown. Detailed entry lives in the END section of the turn page, where the scoring prompts already are.

### 7.3.4 Scoring descriptions and mission Actions

**Every card carries a usable description.** Coverage is 43/43 on both `text` and structured `awards` — averaging 412 characters, ranging 115–808. These are explanations, not labels:

> *Reconnaissance Sweep* — "Reconnaissance against Take-and-Hold. Spread out: three or more friendly units wholly within three different table quarters (none within 6 inches of the battlefield centre) pays at end of turn, with a higher tier for four units across four quarters — only the better tier scores. Each enemy unit destroyed pays a small amount. From the second battle round, non-home control pays at the end of your Command phase."

That is enough to play the mission without the physical card, which is the requirement. The description shows on the card in the END section and on the mission detail from setup.

> ⚠ **These are paraphrases, not GW's card text** — original summaries written by the 40kdc project, which is exactly why they are redistributable (§3.0). They are sufficient to *play* from. They are not authoritative for a rules dispute: exact wording still lives on the card. The UI should not imply otherwise, and community-authored text can contain errors, so `game_version.dataslate` stays visible.

**Mission Actions are structured too** — 15 of 43 cards carry an `actions[]` block with start phase, player turn, use limit and effect:

```json
{ "action_id": "plunder", "starts": "shooting", "player_turn": "your-turn",
  "use_limit": 1, "effect": { "type": "terrain-area-tag", … } }
```

**Actions surface in their phase section**, not inside the card. *Plunder* starts in the Shooting phase, so it appears in SHOOTING on the turn page. Failing to perform an Action is a routine way to drop 5 VP, and the scroll-axis layout (§7.2) puts the reminder exactly where the player will pass it.

Seven cards also carry `when_drawn` interaction rules — *Plunder* redraws if *Cleanse* is already active — which the draw logic of §7.3.2 enforces automatically.

### 7.3.5 Phase sections and weapon aggregation

Designed against the T'au list of §6.7 — twelve combat units, four of them attached pairs.

**Weapons are per-carrier records, and identical names carry different stats.** Verified in `tau-empire/weapons.json`:

```
Missile pod   [missile-pod-commander-in-enforcer-battlesuit]  R30 A2 BS3+ S7 AP-1 D2
Missile pod   [missile-pod]                                    R30 A2 BS4+ S7 AP-1 D2
Fusion blaster[fusion-blaster-commander-in-coldstar-battlesuit] R12 A1 BS3+ S9 AP-4 DD6
Fusion blaster[fusion-blaster]                                  R12 A1 BS4+ S9 AP-4 DD6
```

> **Aggregation keys on the resolved profile, never on the weapon name.** Rows with differing BS/S/AP/D or keywords must stay separate even when they display the same name. Disambiguate from the carrier — *Missile pod (Commander)* — never invent a label.

**Worked example — Attached Unit 1** (Commander in Enforcer + Crisis Fireknife, 4 models):

| Profile | Weapons | Attacks | BS | S | AP | D | Range |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Missile pod *(Commander)* | 4 | **8** | 3+ | 7 | −1 | 2 | 30" |
| Missile pod *(Crisis)* | 6 | **12** | 4+ | 7 | −1 | 2 | 30" |

Ten missile pods that are not one pool. No printed datasheet yields this; the player recomputes it every turn across four differently-composed attached units. **Pre-computed total attacks per resolved profile is the shooting section's reason to exist.**

**Weapon kind is a property of the profile, not the weapon.** Found in implementation: several weapons are typed `ranged` yet carry *both* a Ranged and a Melee profile — the T'au Fusion eliminator is BS2+ at 18" and WS4+ in combat. Filtering the shooting table on `weapon.type` puts melee profiles in front of the player mid-game. The reliable discriminator is the skill characteristic — **`WS` means melee, `BS` means ranged** — with the range string and then the weapon's declared type as fallbacks for auto-hitting profiles that carry neither.

**The rule cuts both ways, which is the point.** Ten missile pods across an attached Commander and Crisis squad split into 4 at BS3+ and 6 at BS4+, because their skills differ. Ten T'au flamers across the equivalent Coldstar pair **merge** into a single `10D6, auto-hit` row, because Torrent has no skill characteristic and the profiles are genuinely identical. Aggregating on the resolved profile produces both outcomes without special-casing either.

**Two levels.**

*Level 1 — unit rows.* One compact row per unit: name, models remaining, a one-line weapon summary, and a "has shot" checkbox. Roughly twelve rows. The checkbox is one tap per unit per turn and earns it — failing to shoot with a unit is a common and expensive mistake. Destroyed and reserved units are filtered out; already-shot units dim rather than vanish, so undo stays visible.

*Level 2 — expanded profile table*, as above. Melee-only weapons (Battlesuit fists) do not appear here; they belong to FIGHT.

**Dice expressions stay symbolic.** T'au flamer is `A D6`, `Torrent`, `Ignores Cover`, no BS. Eight flamers render as **8D6, auto-hit** — not as a computed average, and with the BS column replaced by "auto" rather than left blank. Both Coldstar/Starscythe units in the example list are entirely this case.

**Casualties make the table live.** Losing one Shas'ui drops the BS4+ row from 6 weapons to 4 and from 12 attacks to 8. So the aggregate reads from `modelsRemaining` — and because model types within a unit carry different weapon counts, **casualty tracking must be per model group, not a single wound pool**. Decrement controls sit on the model groups in the unit card. Per §7.2 this stays optional: with nothing tracked, the table shows full strength.

**Target-aware columns are optional and off by default.** Entering a target's T and Sv adds wound-on and save-needed columns to the same table — missile pod S7 wounds T5 on 3+, T9 on 5+. This is the "vs T/Sv" strip, and it is the easiest thing in the app to overbuild.

**Duplicate units need stable instance labels.** The example list holds two identical Fireknife pairs and two identical Starscythe pairs. Carry the source labels through import where they exist — War Organ's `Attached Unit 1..4` (§6.7) — and auto-suffix otherwise, with rename available.

### 7.3.6 Unit cards, per-model stats, and the rules renderer

**Per-model statlines are required, not optional.** Within one attached unit the profiles genuinely diverge:

| Model | M | T | Sv | Inv | W | Ld | OC |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commander in Enforcer Battlesuit | 8 | 5 | 2+ | — | 6 | 7 | 2 |
| Crisis Fireknife Shas'ui | 10 | 5 | 3+ | — | 4 | 7 | 2 |

Different movement, wounds and save in a single unit. The card shows one row per distinct `profiles[]` entry across both component units, with models-remaining per group (which is also what §7.3.5's live aggregation reads).

**Derived stats are marked as derived.** Shield Drone is `{stat-modifier, W, add, 1}`, so the displayed value carries a modifier badge tracing back to its source. Never silently show a modified number — a player checking the app against their codex must be able to see why the two differ.

**Attached units merge their ability sets, attributed by source.** Attached Unit 1 is the union of the Commander's `enforcer-commander, leader, deep-strike` and the squad's `deep-strike, fireknife, gun-drone, marker-drone, shield-drone, weapon-support-systems` — deduplicated, each tagged with which component contributes it.

#### The rules renderer

Abilities in the dataset carry **structured effects and no prose** — 0 of 129 T'au abilities have a text or description field. A renderer from the effect DSL to short English is therefore required infrastructure, not a nicety:

```
{stat-modifier, W, add, 1}                        → "+1 Wound"
{conditional, phase-is:shooting,
  {re-roll, hit, ones}}                           → "Shooting: re-roll Hit rolls of 1"
{roll-modifier, all, ignore-modifiers}            → "Ignore all modifiers to rolls"
{keyword-grant, [markerlight]}                    → "Unit gains MARKERLIGHT"
```

Rendered for Attached Unit 1:

> **Fireknife** *(Shooting)* — Re-roll Hit rolls of 1; if the target is at full strength, re-roll all failed Hit rolls instead.
> **Weapon Support Systems** *(Shooting)* — Ignore all modifiers to rolls.
> **Shield Drone** — +1 Wound.
> **Marker Drone** — Unit gains MARKERLIGHT; may act as Observer even after Advancing.
> **Gun Drone** — Grants an additional ranged weapon.
> **Deep Strike** · **Leader** · **Enforcer Commander**

Two benefits beyond legibility: the output is **ours**, sidestepping §0 entirely; and it is terse and consistent in a way transcribed rules text never is.

> **Scope, measured across three factions rather than one.** T'au alone suggested 23 effect types; adding Necrons and Adeptus Astartes raised that to roughly 40 effect types and 23 condition types. The single-faction estimate was flattering, and any future coverage claim should be made across several factions before it is believed.
>
> Implemented coverage: **T'au 100%, Adeptus Astartes 99%, Necrons 96%.** What remains is a genuine long tail — eight shapes appearing once or twice each (`resurrection`, `stratagem-cost-modifier`, `for-each-unit` and similar). Because unrecognised shapes render a visible placeholder and mark the rule incomplete, partial coverage degrades honestly rather than silently.

**Phase-tagged rules surface inline.** Because `effect.condition.phase-is` is machine-readable, *Fireknife* and *Weapon Support Systems* appear in the SHOOTING section automatically, alongside that phase's stratagems and scorable secondaries. The abilities list is a reference you *can* open — but the ones that matter right now come to you. This is §7.2's scroll axis applied to rules.

Where the renderer meets an effect shape it does not know, it falls back to §7.6: show the raw structure and say so, rather than inventing a sentence.

#### Per-weapon-instance modifiers

Some wargear modifies **one weapon on a model**, not all of them. §7.3.5 aggregates by resolved profile, so such a modifier **splits a row**:

```
6 × Missile pod   BS4+  →   5 × Missile pod          BS4+
                            1 × Missile pod (system)  BS4+  +modifier
```

The aggregation key must therefore be *(resolved profile + applied instance modifiers)*, and weapon instances must be individually addressable in the roster model — not merely counted. Cheap to build in now, expensive to retrofit.

> **Data quality note:** the T'au ability set contains near-duplicate IDs with identical effects — `weapon-support-system` / `weapon-support-systems`, and `battlesuit-support-system` / `battlesuit-support-systems`. The ETL should dedupe on effect equality and report upstream.

### 7.3.7 The remaining phase sections

**Phase assignment is shipped data.** `enrichment/<faction>/phase-mappings.json` maps any `source_id` — ability, stratagem or otherwise — to its `phases[]`; 169 entries for T'au alone. §7.3.6's inline phase-tagging reads this index rather than inferring from `effect.condition`.

**COMMAND** — CP gain; command-phase stratagems and abilities; primaries that score here (*Battlefield Dominance*, *Reconnaissance Sweep* from round 2). Its distinctive content is the **derived Battle-shock list**: the app knows `modelsRemaining` per group, so it knows which units are below half strength and must test. That list is computed, not entered.

Battle-shock status then feeds the stratagem tracker — Battle-shocked units cannot normally be targeted by Stratagems, an interaction visible in ability text across the data ("…can target that unit with Stratagems even when it is Battle-shocked" exists as an explicit exception, implying the default). ⚠ Confirm the exact 11e wording before enforcing.

**MOVEMENT** — M per model group, reserves, and status flags.

Divergent movement is visible in the example list: Commander M8 attached to Crisis M10. The card shows both, with the practical constraint noted rather than silently picking one.

Reserves carry arrival rules (Deep Strike is on most of the example army). Status flags set here — **Advanced**, **Fell Back**, **Remained Stationary** — are the inputs to the next section.

#### The eligibility engine

The most useful thing the app computes, and it falls out of data already present:

```
Fell Back  +  no exception          →  cannot shoot
Fell Back  +  {fallback-and-act}    →  CAN shoot        ← Ghostkeel
Advanced   +  weapon lacks Assault  →  that weapon cannot fire
Advanced   +  Assault               →  fires
```

*Battlesuit Support System* is `{type: "fallback-and-act"}` in the enrichment layer, so the app can state plainly: **"Ghostkeel fell back — Battlesuit Support System lets it shoot anyway."** Combining a movement flag, a weapon keyword and a structured ability into a single yes/no is precisely the "everything you need for play" the brief asked for, and precisely the thing players forget.

Eligibility renders as a badge on the unit row in SHOOTING, always with its reason. Never a bare grey-out.

**CHARGE** — thin. Eligible units (not Advanced, not Fell Back), charge-phase stratagems. Minimal by design; the example army rarely charges.

**FIGHT** — reuses §7.3.5's aggregation with melee profiles (Battlesuit fists), plus Fights First / Fights Last ordering.

**END** — scoring prompts (§7.3.2), VP entry for both players (§7.3.3), end-of-turn abilities, and the round advance.

> **Core rules are not in the dataset.** `enrichment/_core/abilities.json` is 503 bytes — Battle-shock, Deep Strike arrival, Advance and Fall Back restrictions are absent. These belong in the **edition plugin** alongside the validation engine (§2.3): they are the edition's own rules, few in number, stable across its life, and shared by every army. Not a content pack, and not per-faction data.

### 7.3.8 Remaining surfaces

**Army page** — full unit cards per §7.3.6: per-model statlines, merged and attributed abilities, rendered rules, wounds and models-remaining controls. The place casualties get recorded, since that is what makes §7.3.5's aggregation live.

**Opponent page** — see §7.5. Their datasheets if scanned; their primary mission and scoring triggers regardless (§7.3.3).

**Reference page** — army and detachment rules, enhancements and Unit Upgrades in play, core-rules quick answers (11e cover is −1 to hit, not a save bonus), and search across everything.

**Ergonomics.** Keep the screen awake during a battle. Touch targets sized for a hand holding dice. The turn page must remain readable one-handed; the Army page is where landscape earns its place, for the wide weapon tables.

### 7.3.9 Filing rules by reach

The reference page of §7.3.8 files every rule the same way: one entry per ability, naming the datasheets that have it. Measured against real lists, that is the wrong shape twice over.

| | datasheets | distinct rules | matrix cells | filled |
|---|---|---|---|---|
| T'au, 2000pts, Advanced Acquisition + Experimental Prototype | 9 | 30 | 270 | 47 (17%) |
| Adeptus Astartes, Gladius Task Force, ~1900pts | 15 | 26 | 390 | 32 (8%) |

Two facts follow. First, **the unit × rule matrix is 83–92% empty**, so drawing it as a grid is mostly whitespace. Second, and more useful: **21 of 30 T'au rules and 23 of 26 Marine rules belong to exactly one datasheet.** For that majority "who has this rule" has one answer, and it is the heading directly above — the entry pays for an index nobody needs. Meanwhile the handful that genuinely are shared carry an owner list long enough to bury the sentence it belongs to: *Deep Strike.* under five datasheet names.

A third fact settles the layout: rendered rules text has a **median of 38 characters** and a maximum of 104. It is generated from structured effects, not transcribed prose. Descriptions are not the bulky part; the owner lists are.

So rules are filed by how far they reach:

* **Whole army** — the faction rule and the detachment rules. Stated once, never repeated. Universal keywords join them as a sentence (*Every unit: Battlesuit*) rather than becoming a column solid down its whole length.
* **Shared** — rules more than one datasheet in the faction can take. These become columns over unit rows, which is the only tier where both questions are live at once: read a row for one unit's rules, read a column for one rule's units. Keyword columns sit beside them, answering *which of these can Fly* — a question no arrangement of the old page could answer, since it carried no keywords at all.
* **Only this unit** — everything else, printed under the one datasheet that has it, where naming an owner would repeat the heading.

**Sharedness is a property of the faction, not of the roster.** A Space Marine list with one Deep Strike unit still files Deep Strike as shared, because 37 datasheets in the catalogue carry it and the player asking "who can Deep Strike" knows it is a common rule. Deciding it per roster moved the same rule between tiers depending on what was taken, which reads as a bug. The consequence is that a roster snapshot must **carry the shared set**: a snapshot holds only the datasheets its roster uses, so a receiver counting owners locally would answer a narrower question and file a shared list differently from its sender (§6.4).

**Column count belongs to the army, not to the phone.** T'au battlesuits share twelve rules where the Marine list shares six. Rather than cap the count and hide the overflow, the grid keeps every column and scrolls sideways inside its own box; unit names stay pinned, and the page still scrolls vertically as one piece.

**A dot needs a way back to its headings.** In a wide grid a lone dot is hard to trace to either axis, so touching a row or a column lights both and names the rule underneath, with its text and its owners. That is also what keeps the grid from needing a legend.

**Search is unchanged and takes precedence.** Typing a query restores the flat list of §7.3.8 across all four kinds, because recall — *I remember a word, not which kind it was* — wants the opposite shape from orientation.

Two data consequences fell out of building this, both now fixed. `factions.json` has always carried `faction_rule_id`, but nothing read the file, so For the Greater Good and Oath of Moment were the one rule true of the whole army and the one rule the app never showed. And upstream transcribes an ability once per datasheet without agreeing on the plural — `battlesuit-support-system` and `battlesuit-support-systems` are the same effect — which splits one shared rule into two nobody shares. §3.6 gains an `aliases` correction that folds a duplicate into the id it repeats, and a test fails if a new one appears.

### 7.4 Battle state

Event-sourced. Mid-game mistakes are constant, so undo is not optional.

```
BattleState { round, activePlayer, cp,              ← no `phase`; see §7.2
              score: Score,                         ← both players; see §7.3.3
              unitStates: { instanceId → { modelsRemaining, wounds, status,
                                           flags, stratagemsUsed[{phase, round}],
                                           oncePerBattleUsed[] } },
              secondaries: SecondaryState, missionSetup, log: Event[] }
```

State derives from the log, so undo is a pop and a post-game summary is free. It must survive app kill — games get interrupted.

`stratagemsUsed[]` enforces 11e's one-stratagem-per-unit-per-phase rule (§4.4). Note it stores `{phase, round}` per use rather than a "this phase" list: with no tracked phase there is nothing to clear on transition, so the rule is evaluated as a query — *has this unit used a stratagem in this round and this phase?* — against the phase the player is currently reading. Same rule, no lifecycle to get wrong.

**`round` is derived from the turns, not stepped.** A battle round is both players having taken a turn, so it advances when the turn returns to whoever opened. That needs the opener, which is why `MissionSetup` records `iGoFirst` (§7.3.1) — it is decided at the table by a roll-off and is *not* implied by attacker/defender. Deriving it rather than storing it means undo takes the round back with the turn in one pop, with no inverse operation to get wrong. `SetRound` survives as the override for when the app and the table disagree, and counting resumes from whatever it was corrected to.

### 7.5 Opponent mode

**Scan the opponent's QR at deployment and their army is on your phone** — their datasheets, weapon profiles and rules, available for lookup without asking to borrow their book.

This is §6.4's format design cashing out. It works with no network, which a share-link approach (§6.0) cannot, and it is plausibly the single feature most likely to drive installs.

### 7.6 Honesty requirement

§3.3 step 8 routes unmodellable modifiers into a `raw` escape hatch. Where a unit carries an effect that could not be resolved into its profile, the card must **say so** rather than render a confidently wrong number. Mark it, surface the raw text, let the player adjudicate. A play aid that is silently wrong is worse than no play aid at all.

### 7.7 Open questions

- [ ] Who authors the initial stratagem pack, and how is it distributed given §0's copyright posture? Community-contributed is the intended answer; it needs a real plan.
- [ ] Is there an existing community stratagem dataset with usable licensing? (Wahapedia has the data but its terms forbid scraping.)
- [ ] Does the terrain-based objective change (§4.4) justify a deployment/terrain layout view?

---

## 8. Sharing server

*Step 4 — deliberately deferred. Nothing in steps 1–3 requires it.*

---

## 9. Implementation status

Started 2026-08-11. Toolchain: Dart SDK 3.12.2 (Homebrew). Flutter not yet installed — not needed until the app package.

**Done — `packages/wh40k_core`** (pure Dart, no Flutter dependency per §2):

- `tools/fetch-40kdc.sh` — pinned snapshot fetch, per faction, into `data/40kdc/`
- `src/source/` — tolerant source DTOs for the 40kdc format, plus `DatasetLoader`
- `src/report/` — coverage and referential-integrity analyzer, `bin/coverage.dart` exits non-zero on error findings so it can gate CI
- 26 tests; analyzer clean

**First run against T'au** — 47 units, 143 weapons / 160 profiles, 8 detachments, 43 stratagems, 28 enhancements, 129 abilities, 169 phase mappings. **No error findings.** Every forward reference the app will follow resolves: unit→weapon, unit→ability, detachment→stratagem, detachment→enhancement, stratagem→detachment, detachment→disposition, matchup→mission. All weapon keywords are registered; every unit has a profile and points; every stratagem has a phase.

Standing warnings, all expected:

- 322 of 370 records still on `pre-launch-provisional` (§3.0) — only 48 at `launch`
- 29 abilities share an effect fingerprint; some are genuine ID duplicates (`weapon-support-system` / `-systems` / `support-system`), others reveal the effect DSL is **lossy for `ability-grant`** — `gun-drone` and `missile-drone` are structurally identical because neither names the weapon it grants
- 11 orphaned abilities pointing at Legends units absent from the snapshot

**The rules renderer's scope is now measured, not guessed:** 23 distinct effect types, dominated by `conditional` (58) and `sequence` (9) as recursive combinators, then `ability-grant` (12), `movement-modifier` (7), `stat-modifier` (6), `keyword-grant` (6). A long tail of 17 types appears 1–4 times each.

**Done — roster model, pricing and battle sizes:**

- `src/roster/roster.dart` — `Roster`, `RosterUnit`, wargear selections, `LEADS`/`EMBARKED_IN` edges, enhancement and upgrade selections as distinct types (§2.1), JSON round trip. `combatUnits()` collapses leader+bodyguard pairs.
- `src/roster/points.dart` — roster-level calculator. Pricing failures surface as `PricingProblem` rather than costing zero, so a missing price can never read as a cheap unit.
- `src/rules/battle_size.dart` — the hand-maintained rules table §3.3 step 5 requires, including the Incursion 3 DP exception.
- 37 tests; analyzer clean.

**The reference list reconciles exactly.** `test/fixtures/tau_strike_force_2000.json` is the real 2,000 pt T'au list of §6.7, and it prices to **2000** against the live snapshot — 16 roster units, 12 combat units, Crisis Fireknife resolving as 100 base + 6 missile pods at 5 = 130. Every unit priced; nothing unresolved.

The synthetic counter-case is worth keeping in view: three copies of a copy-scaled squad with paid wargear cost 400, where a naive first-bracket-ignore-wargear implementation reports 300. A hundred points adrift, reading as comfortably legal.

Snapshot-dependent tests skip cleanly when `data/40kdc/` is absent, since it is gitignored.

**Done — validation engine (§2.3):**

- `src/rules/catalogue.dart` — the narrow read-only lookup both pricing and validation depend on, so the normalised domain model can replace source DTOs later without touching either.
- `src/rules/validator.dart` — findings with severity, **never a hard block**. Points, Detachment Points (including the Incursion 3 DP exception), one-3DP-per-force, duplicate detachments, unique-tag conflicts, battle-size-scaled duplicate caps with the Battleline/Dedicated Transport doubling, Epic Hero uniqueness, Warlord presence and Character-ness, the shared slot budget, enhancement and upgrade target legality, and leader attachments.
- 61 tests; analyzer clean.

**The reference list validates with zero errors** and surfaces exactly the two observations the design analysis predicted by hand: 2 of 3 Detachment Points spent, 3 of 3 slots unused.

Three behaviours worth keeping:

- **Slots count distinct upgrades, not instances.** A three-target Unit Upgrade consumes one slot. Counting instances is the miscount §2.1 exists to prevent, and it is now pinned by test.
- **Caps come from `BattleSize`, never inline.** Three of a datasheet is legal at Strike Force and illegal at Incursion; a hardcoded rule of three would be wrong at two of three battle sizes.
- **Absent data is not a restriction.** A leader with no published attachment rule validates rather than being refused — the engine never invents a rule from missing data.

**Done — weapon aggregation (§7.3.5):**

- `src/play/attacks.dart` — scales an Attacks characteristic by a weapon count, keeping dice symbolic (`8D6`, `2D6+2`) and flagging expressions it cannot parse rather than guessing.
- `src/play/weapon_aggregator.dart` — profile-keyed aggregation over a combat unit, carrier disambiguation, per-profile ranged/melee filtering, casualty scaling, and unresolved-wargear reporting.
- `bin/roster.dart` — prices, validates and prints a roster's shooting or fight table. A development lens on everything the core does.
- 80 tests; analyzer clean.

Against the reference list, Attached Unit 1 renders as designed:

```
Attached Unit 1  (210 pts)
    4× Missile pod (Commander in Enforcer Battlesuit)   8 atk   3+  S7 AP-1 D2
    6× Missile pod (Crisis Fireknife Battlesuits)      12 atk   4+  S7 AP-1 D2
```

Every one of the 16 units resolves; no unresolved wargear anywhere in the list.

Two bugs the CLI caught that the tests alone would not have:

1. **Melee profiles appearing in the shooting table** — see the per-profile filtering note in §7.3.5.
2. **Four units rendering no weapons at all** — see the complete-loadout note in §2.2.

Both are recorded above as design constraints rather than fixed silently, because both are mistakes any reimplementation would repeat.

**Done — rules renderer (§7.3.6):**

- `src/play/rules_renderer.dart` — recursive descent over the effect DSL producing short English, with phase extraction for the turn page and a visible placeholder for any shape it does not know.
- `bin/rules.dart` — renders a faction's abilities and reports coverage, the renderer's analogue of the ingest coverage report.
- 101 tests; analyzer clean.

Real output, from the reference army:

```
▸ Fireknife  {shooting}
    Shooting phase: re-roll Hit rolls of 1; target at full strength: re-roll failed Hit rolls.
▸ Shield Drone
    +1 Wound.
▸ Marker Drone
    Gains MARKERLIGHT; grants observer unit.
▸ Deadly Demise 3D6
    Before bearer removed: on a D6 of 6+, 3D6 mortal wounds to units within 6".
▸ Lone Operative
    May only be targeted by ranged attacks within 12".
```

**Coverage: T'au 100%, Adeptus Astartes 99%, Necrons 96%** — see §7.3.6 for why the single-faction figure was misleading, and what remains.

**Done — content layer (§2.1, §2.2, §6.4):**

> **Scope corrected during implementation.** §2.1 originally called for a wholesale renormalisation of the source into a separate domain model. That was written when BSData — recursive links, modifier evaluation, prose characteristics — was the input. `40kdc-data` arrives already normalised, so re-shaping every DTO would have been motion without value. What the layer genuinely still owed was everything the raw snapshot *cannot* do, and that is what was built instead.

- `src/content/content_hash.dart` — 24-bit FNV-1a over semantic ids, the compact stable identifier the QR payload needs (§6.4). Dependency-free and byte-identical across platforms. **Not** a security primitive: an identity shortener with a build-time collision check, so the namespace can be widened before shipping rather than after.
- `src/content/dataset.dart` — `Dataset` pins a version, implements `Catalogue`, resolves per-battle-size duplicate caps once, and flags provisional content.
- `src/content/roster_snapshot.dart` — the denormalised copy §2.2 promises, built as the transitive closure of what a roster actually names. Records are kept in **source form on purpose**: a snapshot's value is that a later build, whose model has moved on, can still read a list saved today.
- 116 tests; analyzer clean.

**Verified properties:**

- The addressable namespace is **collision-free at three bytes** across T'au, Necrons and Adeptus Astartes, so §6.4's identifier size holds.
- A snapshot of the reference army is **67 entries / 62 KB pretty-printed against 247 KB for the faction** — roughly a quarter, before minifying or compressing.
- **A catalogue rebuilt from nothing but the snapshot still prices the list at 2000 and renders the shooting table.** That is the offline-play and list-from-a-stranger case of §6.4, demonstrated rather than asserted.

**Done — first app increment (`packages/wh40k_app`):**

Flutter 3.44.9, targets iOS and Android. Two screens, running on an iPhone 17 Pro simulator and verified by screenshot.

- **Army** — points against limit, combat-unit count against roster entries, detachment chips, validation findings by severity, and an expandable card per unit with per-model statlines, ranged and melee tables, and rendered abilities.
- **Turn** — the scroll-axis page of §7.2. Sticky header carrying only round, active player and CP; phase sections below it. Shooting and Fight render the aggregated weapon table; rules tagged with a phase surface inline beside the weapons they modify.

**The app reads its content from a roster snapshot, not a faction dataset.** That makes the offline case the default case rather than something bolted on later, and it is the same path an imported or QR-scanned list will take (§6.4). It also keeps the app independent of the gitignored upstream data.

Verified on device, from the reference army: `4× Missile pod (Commander in Enforcer Battlesuit) — 8 atk, 3+` above `6× Missile pod (Crisis Fireknife Battlesuits) — 12 atk, 4+`, with *Enforcer Commander*, *Fireknife* and *Weapon Support Systems* rendered underneath; and `10× T'au flamer — 10D6 atk, auto` carrying IGNORES COVER and TORRENT chips. Every figure computed from structured data.

121 tests across both packages; both analyzers clean.

> **Environment note.** ~~The native iOS simulator integration reports Xcode as unselected~~ — **resolved 2026-08-16** by `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. The simulator integration now attaches, and **tap injection works**, so interactive flows can be exercised: build with `flutter build ios --simulator --debug`, launch `build/ios/iphonesimulator/Runner.app`, then tap and screenshot. Coordinates are **device points** (402×874 on an iPhone 17 Pro), not screenshot pixels — the screenshot comes back at roughly 2.25× that, and passing pixel coordinates silently misses.
>
> Android is not yet set up: `flutter doctor` wants Android Studio for the SDK. Not a blocker for development, but it does mean one of the two shipping targets is currently unbuilt.

**Done — text import (§6.7):**

- `src/import/` — untyped parse tree, War Organ text parser, name matcher, and the resolver that holds all catalogue knowledge.
- The reference export imports with **zero errors and prices to exactly 2000**, matching its own printed total. Sixteen roster units, four attachment pairs, twelve combat units, Warlord found.
- 133 core tests.

Two things only real input revealed. `Strike Force (2000 Point)` also matches the unit-header pattern and was importing as a datasheet, so the preamble must claim it first. And apostrophes have to be **deleted** rather than turned into separators, or `T'au` folds to `t au` and never matches `tau-flamer`.

Nineteen entries report as *info*, not warnings: drones and support systems the printed list carries but the datasheet does not list. Fireknife lists its drones as abilities; Starscythe, Stealth, Broadside and Ghostkeel do not. An upstream attachment gap worth surfacing, not an import failure — it costs no points and does not touch the weapon table.

**Done — storage (§4.3):**

- Drift over SQLite. Roster and snapshot are stored as **JSON documents**, not shredded into columns: both are versioned artifacts whose value is being read back verbatim by a later build, and normalising them would tie saved lists to today's schema. The columns beside them exist so the roster list renders without parsing anything.
- Roster list screen with swipe-to-delete, seeded with the reference army on first launch.
- Import screen: paste, review, save. **Nothing imports silently** (§6.5) — every run lands on a review step showing matches, assumptions and misses, with the computed total checked against the printed one.
- 12 app tests, including a roster rehydrating and rendering its weapon table with no faction dataset present.

> ⚠ **One faction is bundled as an app asset.** Import needs a full catalogue to resolve names against, and a snapshot is not enough — a snapshot only holds what some other list already referenced. Dataset distribution (§3.4) does not exist yet, so T'au rides along in the binary (296 KB) until it does. This is the first place the missing distribution layer has actually bitten.

**Verified on device:** roster list reads *2k ret · tau empire · 2000 pts · 12 units*, seeded and persisted. The import *screen* is not interactively verified — the simulator integration gives no tap injection (see the environment note above) — though the import logic underneath it is covered by the core suite.

**Done — battle state (§7.4):**

- `src/battle/` — a sealed event hierarchy and a pure reducer. State is **derived from the log**, never mutated, so undo is a pop rather than an inverse operation per event type, and a finished game replays for free.
- Persisted per roster as a JSON document, schema v2. Verified by installing over a v1 build on device: the existing roster survived the upgrade with no crash and no re-seed.
- Turn page now reads round, active player and CP from the log and writes events back; casualties recorded in the log shrink the weapon table live.
- 154 core tests, 16 app tests.

The design decision that pays off here is the one from §7.2. **`stratagemsUsed` stores `{round, phase}` per use** rather than a "this phase" list cleared on transition — and because there is no tracked phase, there is no transition, so nothing needs clearing. The one-per-phase rule is a query against whichever phase the player is reading. Lists that reset on transition are exactly where "why is this unit still greyed out" bugs live, and there is a test pinning that advancing the round frees a unit without touching its history.

Secondary VP caps apply per round and then per game, trimming later rounds so early ones keep their points. Primary is left uncapped here; its cap belongs to the mission record and arrives with the setup screen.

**Done — setup screen (§7.3.1):**

- `src/missions/` — mission pack, the 25-cell matchup table, deployment patterns, the 18 secondary cards, and `MissionSetup`. Completing the wizard emits a single `ConfigureBattle` event, so setup persists, replays and undoes with everything else.
- The screen collapses the grid to the opponent's column once they declare, shows the resulting mission and its description under each of your options, and — because the table is asymmetric — shows **what the opponent is playing** underneath. Full 5×N grid available on demand.
- Setup is mandatory: the Turn tab routes through the wizard until it completes, and Start stays disabled until every question is answered.
- 167 core tests, 21 app tests.

Verified by test on the reference army: declaring **Reconnaissance** against Take and Hold plays *Reconnaissance Sweep* while the opponent plays *Purge and Secure*; declaring **Priority Assets** instead plays *Secure Asset*. Same opponent, different mission — which is the whole reason the screen exists.

> **Data gap: there is no twist data upstream.** No file publishes them, so the twist is free text the player records rather than a picker over a list that does not exist. It is optional anyway.

**Done — dataset distribution (§3.4):**

- `src/content/bundle.dart` — bundle and manifest format. One gzipped JSON document per faction plus a shared core bundle, listed in a manifest with sizes and SHA-256 hashes.
- `bin/bundle.dart` — builds a complete static site from a snapshot. Copy the output to Pages, a Release or a bucket.
- App `DatasetRepository` — resolves **cache → shipped assets → network**, verifying every download against its hash before caching. One code path regardless of where the data came from.
- 167 core tests, 31 app tests.

**Gzip changes the arithmetic.** T'au was 296 KB of loose JSON assets; as a bundle it is 26 KB. All three factions plus core come to 143 KB, and the app's asset payload dropped from 408 KB to 228 KB *while gaining two factions*. Adding a faction now costs tens of kilobytes, not hundreds.

The remote source is written but **inert** — nothing is hosted, so `baseUrl` is unset and the repository falls through to the shipped bundles. Publishing is now a configuration change rather than an architectural one, and the shipped bundles keep the app working offline on first launch regardless.

> ⚠ **The manifest is not signed.** §3.4 asks for one; this is integrity only. A SHA-256 proves the bytes arrived intact, not that they came from you. Worth adding before the manifest is served from anywhere outside the project's control.

**Done — release readiness:**

- About screen carrying the **"Powered by 40kdc-data"** attribution and link, which 40kdc's licence obliges any public deployment to display. A TestFlight build counts, so this was a genuine blocker rather than a nicety. **A test asserts the phrase verbatim** — if it fails the app is out of compliance, and the screen is what should change.
- The same screen surfaces the dataset revision, bundle sizes, the Games Workshop disclaimer, a plain statement that nothing is collected, and the **provisional dataslate warning** §3.0 requires be visible rather than presented as current.
- Build number scheme: `version: <semver>+<build>`, currently `0.2.0+3`. App Store Connect refuses a build number it has already accepted, so the build number increments on every upload regardless of the version. `0.2.0` marks the release that added stratagems, secondaries and VP, the reference page and the army builder — everything since the first TestFlight upload at `0.1.0+2`.
- iOS deployment target raised 13.0 → 15.0, ahead of Apple's Spring 2027 cutoff.
- `ITSAppUsesNonExemptEncryption = false` in `Info.plist`. Without it App Store Connect holds every build for a manual answer to the same question. The declaration is accurate: downloads use the OS's own TLS, the database is plain SQLite with no SQLCipher, and the only cryptographic primitive in the code is a SHA-256 bundle digest, which is a hash rather than encryption.
- Bundle identifier settled as `dev.structor.app` on both platforms — permanent once App Store Connect has used it, and no longer carrying a Warhammer reference.
- 35 app tests.

**First TestFlight upload succeeded**, which validates enrolment, the app record, signing, archive and export end to end.

**Done — corrections and naming, from first play-test feedback:**

- `data-corrections.yaml` and `src/source/corrections.dart` (§3.6). One entry so far: Broadside Battlesuits' Advanced Armour, which upstream encodes as an unrestricted `Feel No Pain 4+` and which the rulebook restricts to mortal wounds. The renderer gained one condition, `damage-is-mortal`, and now reads `Against mortal wounds: Feel No Pain 4+.`
- **Units are named after their datasheets.** The text importer had been stashing the export format's `Attached Unit N` grouping label in `customName`, so the play screen listed four units by a bookkeeping artefact instead of what they were. The grouping was always carried by the `LEADS` edges; the name was pure noise. An attached unit now reads `Commander in Enforcer Battlesuit with Crisis Fireknife Battlesuits` — the character leads, so it is named first — and two identical pairings are shown as two identical names rather than disambiguated — the models on the table are what tells them apart.
- Text left-aligned throughout: empty states, error messages, the setup prompt, the round stepper and the turn toggle. Centred text reads as decoration; a rules aid should read as a document.

**Done — the seven play-test findings (§3.7, §3.8):** operation-aware stat rendering, sign preservation, attacker/defender attribution, weapon keyword parameters end to end, ability-granted invulnerable saves in the INV column, per-datasheet attribution of an attached unit's abilities, and corrections for Stealth, Coldstar Commander and Starscythe.

**And drones, which were the interesting one.** They are wargear, not models, and the importer had been recognising them and discarding them — nine of sixteen units in the real export lost theirs. `bin/import.dart` now exists so the reference fixture is *derived* from `war_organ_export.txt` rather than hand-maintained; a fixture out of step with the importer stops testing it. 299 core tests, 81 app tests; both analyzers clean.

**Done — stratagems (§7.3):** the last major play-mode surface, and it is *not* a page.

Calling it "the stratagem screen" was the wrong frame. §7.2 says relevance comes from where you are scrolled, so stratagems live **inline at the head of each phase section** — the Shooting section shows shooting stratagems because that is where you are reading. A page of its own would have needed a phase selector, which is the state machine §7.2 exists to avoid.

- `src/play/stratagem_book.dart` — availability as a set of queries against the log. Phase from the section, turn from the header, CP from the state, and each stratagem's own `once-per-phase` / `-turn` / `-battle` limit from `stratagemsUsed`. No lifecycle, nothing to reset.
- **Unplayable stratagems are shown, greyed, with the reason** — "not enough CP", "opponent's turn only", "already used this phase". Hiding them answers *why can't I use that* by omission, which reads as a missing stratagem rather than as a rule. Same for target units: a unit that has already had a stratagem this phase is listed and disabled, not dropped.
- Scoped to the roster's detachments, and each row names its source. At two detachments (§4.4) half the list is not the half you are reading — the reference army carries 19 stratagems, 10 core and 9 across its two Cadres.
- Keyword restrictions are enforced against the combat unit: Epic Challenge offers the Commanders and The Twin Lance, and tells the Broadsides they are `not Character`.
- **Stratagems are part of the roster snapshot**, since which ones apply is a property of *this roster's* detachments rather than of the faction. A scanned list brings its own, and an older snapshot without them opens with an empty section instead of failing.
- Effects render from `ability_id` where the data has one — 7 of 53. The rest show name, cost, source and type and stop, because §7.6 forbids inventing the text.

**Done — secondaries and victory points (§7.3.2, §7.3.3):** the END section, and the last of the play mode.

- `src/missions/secondary_deck.dart` — the deck as a query over the log. There is no shuffled deck object because *the cards in each deck are identical, so there are only 18 choices*: a draw is a pick from what this player has not yet seen. Randomness lives at the call site and the chosen id is the event, so a replay deals the same hand and undo puts the card back.
- **Both players are tracked**, primary and secondary, per round, with the round and game caps applied. Knowing you are on 42 is useless without knowing they are on 47, and the side that is ahead is marked so nobody does the subtraction by hand.
- Scoring is entered, never derived. A card offers the payouts **it actually names** — Outflank pays 3 or 5 — and anything paying *per objective* falls to a stepper, because that number is only visible from the table (§7.6).
- Tactical draws at random; fixed opens a picker. One event either way.
- **Seven of the eighteen cards carry a `when_drawn` rule**, in three shapes I had not noticed until a test forced the count: three go back if drawn in the first battle round, Plunder and Cleanse cannot be held together, and two are replaced when the opponent fields no valid target. Each renders a note and **leaves the card alone** — the deck is physical, the last case depends on an army the app cannot see, and a silent swap would be the app playing the game.

**Done — the Reference page (§7.3, §7.3.8):** one searchable index over everything the army carries, on a third tab.

- `src/play/reference_index.dart` — detachment rules, unit abilities, enhancements and stratagems flattened into one list. **Search runs across all four at once**, matching each word anywhere in title, source, body or detail, because mid-game you remember a word and not which of the four it lives in.
- An ability shared by several datasheets is **one entry naming them all**: five identical Gun Drone rows, one per battlesuit that bought one, is five times the scrolling for the same sentence.
- Enhancements are listed **whether or not they were taken**, flagged `IN PLAY` when they were — "what could I have taken" is asked as often as "what did I take" — and Enhancements are labelled apart from Unit Upgrades, which the data distinguishes by `upgrade_tag` and §2.1 treats as separate mechanics.
- `SourceEnhancement` now exists as a model. The validator only ever needed the id set, so nothing had parsed the records before; the snapshot captures the taken detachments' enhancements and their abilities, so a shared list brings them.

**What the page deliberately does not carry is a core-rules crib.** §7.3 wanted "core-rules quick answers — 11e cover is −1 to hit rather than a save bonus". The dataset cannot supply it: `weapon-keywords.json` and `unit-keywords.json` give names and `required_parameters` and **no text at all**. Writing those summaries from memory would be reproducing Games Workshop's rules into a shipped binary, which is the line §0 draws. The page says so at its foot rather than leaving the absence to be discovered.

**Done — the army builder (§4, the brief's first item):**

- `src/roster/roster_editor.dart` — every operation returns a **new** roster. Nothing mutates, so undo is a list of prior states and "what would this cost" is the same mechanism as "commit it". `Roster` and `RosterUnit` gained `copyWith`.
- Create, name, faction, battle size, detachments, add/remove/duplicate units, model counts, wargear counts, leader attachment, enhancements, Warlord. Points and validation findings update on every tap.
- **A new unit arrives at its smallest legal size with its default loadout**, which needed `UnitComposition` — "every weapon on the datasheet" is the wrong starting point, since a Crisis suit lists nine and carries three.
- Removing a unit takes its baggage with it: attachment links, its enhancement, the Warlord nomination. Dropping a detachment drops the enhancements that came with it. An enhancement outliving its bearer is a points total that quietly stops adding up.
- Editing works against the **faction dataset**, unlike every play surface, which reads a snapshot. Saving re-snapshots, so a saved list stops moving when the dataset next updates.

> **The builder is permissive and the validator is honest.** It will let you build an illegal list and say exactly how it is illegal, rather than refusing the tap. §2.3 settled that for validation, and the wargear-option data settles it again: `wargear-options` comes in three shapes across 87 records, and §3.8 found six datasheets that did not list the drones their units demonstrably carry. An editor that enforced that data would refuse legal lists, and a builder that will not let you enter the army standing on your table is worthless.

**What is deliberately not built is a wargear-option engine.** Wargear is a counter per item over the datasheet's own vocabulary — its weapons plus its budgeted drones and support systems — rather than a gated `replace X with Y` flow. That is the honest ceiling of the current data. When the option records are complete and uniform, the counters can become constrained choices without changing the roster model.

**Done — Enhancements were never priced.** A second real export, a 1,000 pt Incursion list, came in 30 points light. Three faults behind one symptom:

- **`PointsCalculator` did not price Enhancements or Unit Upgrades at all.** §2.1 defines the unit cost as bracket plus wargear and nothing had ever added the third term, because the reference 2,000 pt list takes none. Any list with an Enhancement was under-priced, and the validator's points check would pass an illegal army. They are charged **per bearer** now — a Unit Upgrade on two units costs twice even though the two share one slot, which is the validator's arithmetic and not the calculator's.
- **The importer dropped `• Enhancement: Negation Emitters`.** It fuzzy-matched the *ability* of the same name and reported an attachment gap. The prefix is now recognised before wargear tallying, matched against the faction's enhancements — trying the name both with and without the `(Upgrade)` suffix the data adds — and Unit Upgrades are grouped by id so one selection carries several targets.
- **The import screen hand-assembled its own snapshot**, omitting stratagems and enhancements. An imported list therefore came back from storage with an empty stratagem section and priced lower than it had at import. It uses the shared `DatasetRepository.snapshotBuilder` now, and 77 lines of duplicated serialiser went with it.

The list imports clean and prices to exactly 995, and `war_organ_incursion_1000.txt` joins the fixtures. Only lines carrying the `Enhancement:` prefix are matched against the enhancement list; matching every wargear line would let a weapon named like one quietly add points.

**Done — a guard on the shipped bundles.** The assets in `packages/wh40k_app/assets/bundles/` are built by hand, and nothing noticed when that step was skipped: the core tests read `data/40kdc` through a loader that applies corrections **live**, so they stay green while the app ships uncorrected data. The symptom is a drone import warning that the CLI cannot reproduce.

`test/shipped_bundle_test.dart` reads what the app reads. It asserts the six corrected datasheets list their drones, that a drone's gun is BS5+, that Advanced Armour is mortal-wounds-only, and that **both real exports import with no issues at all** — not merely no errors, since an info line about an unlisted drone is exactly the symptom. Verified by rebuilding the bundles with corrections disabled: all five tests fail, with the drone message the user reported.

`tools/rebuild-assets.sh` regenerates the fixture, the reference roster, the snapshot and the bundles in one command, so the step is harder to skip than to do.

**Done — three findings from using the app:**

- **A fresh install starts empty.** The reference army was seeded on first launch so there was something to look at; it read as somebody else's list the user had to delete before their own would look like theirs. `seedIfEmpty` is gone and the empty state names both routes in — build from the datasheets, or import the text export of the list you already have. `Army.loadReference()` and the two bundled assets stay as the **test fixture** five test files read; nothing pre-installs them.
- **A full-height sheet had no exit.** `isScrollControlled` sizes a modal sheet to its content, so a long one fills the screen: no scrim is left to tap, and the scrollable body swallows the downward drag that would dismiss it. The drag handle is a few pixels at the very top and nobody finds it. `SheetHeader` carries a close button and every sheet that can reach full height now uses it — add unit, unit editor, secondary picker. The two short sheets keep their scrim and are left alone. A test taps the close button and asserts the sheet is gone, because this is invisible in code review: the sheet looks fine, and only the height it reaches makes it a trap.
- **The auto-hit pill read `auto`.** Now `auto hit`, since the column beside it is a skill and `auto` alone does not say what is automatic. The CLI's fixed-width table (`bin/roster.dart`) keeps `auto`, which fits its four-character column.

All three verified on the simulator, interactively — the first time that has been possible (see the environment note above). The add-unit sheet confirms the diagnosis on screen: at full height it covers the display edge to edge, and the drag handle `showDragHandle` is supposed to draw **does not render at all**, so before this change the sheet had no exit of any kind.

> The already-seeded roster **survives on devices that ran an earlier build** — dropping the seed stops new installs from getting it, and does not reach back. It is worth knowing that it is now un-recreatable in-app: with `seedIfEmpty` gone, deleting it means re-importing `war_organ_export.txt`. It also still shows its units as `Attached Unit 1…4`, from before units were named after their datasheets, which is a fair picture of why a pre-installed list ages badly.

**Done — four findings from the second play-test:**

- **Who takes the first turn is now asked, not assumed.** `MissionSetup.iGoFirst`, set in the wizard beside attacker/defender because it is a separate decision — a roll-off, not a consequence. The battle opens in the opener's turn rather than always in mine. Games saved before the field existed read as *I went first*, which is what they all were.
- **The round advances by itself** once both players have taken a turn (§7.4). Derived in the reducer from the opener, so undo takes the round back with the turn in one pop. The header shows `→ R2` on the toggle *before* the tap, because a number that moves on its own is alarming unless it was announced. The stepper stays as the correction path.
- **The table is drawn** (§7.3.1). `deployment-patterns.json` publishes real polygons, positions and objective coordinates, and `DeploymentPattern` had been parsing the name and description and dropping all of it. Zones, territories and objectives now render as a picture that updates as you pick, with **your** half named rather than merely coloured — the patterns are symmetric, so colour alone does not say which side is yours.
- **The primary's scoring rule sits beside its stepper** (§7.3.3). The number is entered by hand (§7.6) and entering it right means remembering a rule that changes at battle round 2. Both sides are shown, because the matchup table is asymmetric and knowing how they score is how you decide what to contest. Collapsed by default so the totals still come first.

Three things the geometry work turned up, each pinned by a test:

- **Zone shapes come in two forms** — a polygon, or a `width`/`height` rectangle — and both carry a separate `position` offset. Flattening both to absolute points at parse time is what keeps the painter honest; dropping the offset stacks both players in the same corner, and the picture looks plausible while being wrong.
- **The board is measured, not assumed.** `kotc-colosseum` is 36×36, not 60×44, so a hardcoded standard table would draw it at half scale in the corner.
- **Labels use the polygon's area centroid**, not its bounding box. Every zone is an L or a bar, and a bounding box puts the label on the notch. The first render also carried a horizontal centre line, which was removed: the split is left/right on most patterns, so a fixed horizontal rule asserts a halving that is not there.

317 core tests, 89 app tests; both analyzers clean. All four verified on the simulator interactively.

**Done — all 35 factions (§3.9).** Three shipped before; the snapshot now covers everything upstream publishes.

- **725 KB of bundles, 36 of them**, against 143 KB for four. Adeptus Astartes is the largest at 78 KB; the twelve chapters are 5–8 KB each, because they inherit datasheets rather than carrying copies (§3.9).
- **The import screen no longer assumes T'au.** It reads the faction line the export already carries — `matchFactionId` in the core package, exact on the normalised form so `Tau Empire`, `T’au Empire` and `tau-empire` all land on the same faction, with `Space Marines` reaching Adeptus Astartes by its published alias. A picker sits above the paste box for the cases the export cannot answer, and the summary names the faction the numbers were resolved against.
- **Matching is exact, never fuzzy.** Importing against the wrong faction resolves almost nothing, and the wall of misses it produces never says the faction was the problem — so a near-miss asks instead of guessing.

Two things ingesting thirty-two new factions turned up, both by tests rather than by reading:

- **Three more plural/singular duplicate abilities** — Sororitas *Cherubs*/*Cherub*, Guard *Mobile Hunter-killers*/*-killer*, Ork *Bomb Squigs*/*Bomb Squig* — each one rule filed twice. The duplicate-fingerprint test of §3.6 found all three; three aliases in `data-corrections.yaml` close them. The T'au correction for *Stealth* turned out to apply to 13 factions, since it is a shared ability id.
- **The unbundled faction record**, above. That one had been shipping broken for three factions and nothing had noticed.

Verified on the simulator: Blood Angels lists *Angelic Inheritors*, *Encarmine Speartip* and *Liberator Assault Group* beside the shared Astartes detachments, offers Sanguinary Guard, Sanguinary Priest and The Sanguinor from the inherited catalogue, and prices the Guard at 125.

328 core tests, 96 app tests; both analyzers clean.

**Done — terrain layouts (§7.3.1).** `terrain-layouts.json` was never fetched: 278 KB of published competitive tables, every piece placed by position and rotation, sitting upstream unread. With `terrain-templates.json` beside it the setup screen now draws the actual table rather than two coloured zones, and picking one sets the deployment pattern it is built on.

- **+18 KB.** The core bundle goes 10.2 → 28.7 KB, the total 725 → 743 KB. Cheap for the single most-looked-at picture in the app.
- **The matchup lookup commutes.** Fifteen unordered pairs, three variants each — the terrain is one physical table however the two players declared. Ten of the twenty-five matchups find nothing without it.
- **The transform is pinned by measurement, not by eye.** Rotate about the template origin then translate: 633 of 745 pieces wholly on board, worst overhang 3.73″. The centroid alternative also produces a plausible-looking table, which is exactly why it is asserted.
- **Nineteen of sixty-nine templates are rectangles**, not polygons — the same split the deployment zones have. A test caught the missing branch; without it those pieces are invisible and nothing reports an error.

> ⚠ **Not Chapter Approved.** These are Battlemaster (45) and KOTC (1); upstream publishes no Games Workshop layout set. The UI names the source on every table and says it is not a GW publication.

340 core tests, 96 app tests; both analyzers clean. Verified on the simulator: *Take vs Take 01* draws ten ruins and five objectives on Tipping Point, and switching to variant 2 moves the whole table to Dawn of War with the pieces rotated.

**Next:** QR (§6.4), which also unlocks the opponent page, and reporting upstream: the stale Adeptus Astartes points, the local corrections, and the four factions' dangling `detachment_id` references (§3.9).

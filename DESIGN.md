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

### Licence: MIT for the code, their own terms for the data

Added 2026-08-23, at the user's decision. `LICENSE` is MIT, matching the other
manus systematum repositories; the copyright line names *manus systematum*,
a distribution name rather than a legal person.

**MIT covers this repository's code and nothing else.** Every rules fact the
app shows arrives from a community project that keeps its own terms — 40kdc
under CC BY 4.0, Wahapedia's export, BSData under no licence at all — and none
of them are ours to relicense. README's licence table states each one; the
About screen names them in the app.

**The notice says how far their rights reach, not what the app carries.**
Added 2026-08-23, in the same words on the site, the About screen, the store
description and the review notes: everything was collected from openly
published sources, and Games Workshop's rights cover the names, marks and
imagery *and any wording that matches their printed rules*. Naming the marks
while staying quiet about the text is the narrower claim, and the narrower
claim is the one that reads as avoidance.

Two stale compliance statements were removed at the same time, one in README
and one on the About screen. Both asserted something that had stopped being
true, and a compliance statement that has quietly gone false is worse than
none. Neither was replaced with a corrected version: what the app ships is
described where it belongs, in §3.12 and in the source credits, not as a claim
on the front page.

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

### 0.1 How the app talks

Structor sounds like **a competent opponent reading the rulebook back to
you**: it states what is true, names what is next, and does not manage how you
feel about it. The registers it refuses are **performed cheerfulness** ("Great
job! 🎉", "Oops!") and **performed reassurance** ("don't worry", "that's
completely fine") — both lay managed feeling over information, and a player
mid-turn with a timer running has no use for either. Sentence case, no
exclamation marks, no emoji as tone-softeners, no first-person plural: there is
no "we" a player could reach.

The app has one advantage it should not spend: it is the thing on the table
that is believed about points, ranges and what a stratagem costs. A sentence
that is obviously pretending to feel something is the first thing a reader
catches it lying about, and everything else gets discounted afterwards.

**And prefer the fact to a sentence about the fact.** Added to the shared
`product-voice` skill on 2026-08-27 so it applies by default: prose that
narrates a number the reader can be shown is the second layer to remove, after
the managed feeling. `11/15 scored this round` is the state; *"Only 4 left this
round, so 6 VP scores 4"* is a paragraph doing arithmetic out loud at someone
who can see both numbers.

The same rule struck the screens' explanations of themselves — how to read the
map, what an empty list will eventually hold, why a control looks as it does —
and left the rules they carried stated once and stopped. **Where the app is
quoting somebody else it changes nothing**: card text, ability descriptions and
the packs' FAQs are reproduced as published, and only a data correction alters
them.

Pairs from this app's own strings:

| Not | But |
|---|---|
| "Oops! Couldn't save that 🙈" | "Not saved. Try again." |
| "All done! Your battle has been saved! 🎉" | "Finish battle" → the record appears |
| "Don't worry, deleting this won't affect anything else." | "The list is removed. Finished battles keep their own record." |
| "No armies yet — let's build your first one!" | "No armies yet." + what the two buttons do |
| "Great, that's a legal list!" | *(nothing — the findings panel is empty)* |
| "Only 4 left this round, so 6 VP scores 4." | "11/15 scored this round" |
| "Pinch to zoom — the numbers stay their own size, so crowded ones come apart." | *(nothing — the control works)* |
| "Battles you finish are kept here — the missions, the armies, the score by round…" | "No finished battles." |
| "The card leaves your hand and you gain 1 command point. One card a battle round can be traded this way." | "Gains 1CP. Once per turn, however many cards go with it." |
| "Nothing in this army may be led by it. The dataset publishes the attachment rule, so an absent one is a gap upstream." | "Nothing in this army may be led by it." |

This is decided here rather than at review because the register arrives as a
package: cheerful copy has already half-decided the app will congratulate you
for winning, badge your streak of legal lists, and celebrate a finished battle.
Plain copy next to a celebration screen means one of the two is wrong.

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

**A partial merge must not damage what it was not asked about.** `merge.dart`
filled the tree from raw 40kdc for every path the *current run* had not
rewritten, so `merge.dart tau-empire` copied the un-enriched Space Marine
abilities over output a previous run had merged: **2,723 rules silently lost
their printed text**, and whichever factions were merged last were the only
ones that had any. The tree is derived and gitignored, so no diff and no test
saw it, and the shipped bundles only stayed correct because
`tools/rebuild-assets.sh` always merges everything. Existing merged output is
now never overwritten by the raw source, a manifest records what the tree
holds, and a test fails if any faction's ability text falls away.

The same hazard applies to `data-conflicts.json` and `data-enhancement-text.json`,
which are written wholesale from the current run and are **committed**: a
partial merge leaves them describing only the factions it touched. Regenerate
both with a full merge before committing.

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

### 4.5 Loadouts — permissive is not the same as shapeless

§9 recorded that no wargear-option engine was built, and that "when the option records are complete and uniform, the counters can become constrained choices". They are still neither, and waiting for them was the wrong test. Measured across three factions:

| | T'au | Adeptus Astartes | Necrons |
| --- | --- | --- | --- |
| datasheets publishing `wargear-options` | 30 / 47 | 103 / 194 | 19 / 57 |
| datasheets publishing `default_weapon_ids` | 42 / 47 | 174 / 194 | 51 / 57 |

Roughly **half of datasheets publish no options at all**, so an editor that treated the file as permission would let you build nothing on a Ballistus Dreadnought. That is the §2.3 failure and it still stands. But treating the file as absent produced its own wrongness: the editor offered to remove a Crisis suit's Battlesuit Fists, asked for three separate drone counters where the datasheet asks one question, and let "replace the plasma rifle with a missile pod" leave the unit holding both.

The fix is not to enforce or to ignore, but to **sort the published data by how much of it is a closed statement**:

- **Fixed** — a default weapon that appears in no option record's `replaces`. There is no legal list without it, so it is stated rather than offered. Derived, never hand-listed.
  - ~~On a datasheet with no options published, nothing is fixed, because absence of data is not evidence of a restriction.~~ **Superseded 2026-08-19: with no options published, the whole default kit is fixed.** The old rule was right about the evidence and wrong about the consequence. Morvenn Vahl publishes no options and carries three weapons she always has, and the editor put a `+` beside each — offering a second Lance of Illumination, which no rule in the game allows. Staying open is not neutral there; it asserts a choice just as confidently as locking would, and asserts one that does not exist. **The cost is real and stated:** 1,310 of 1,863 datasheets (70%) publish no options and 1,048 of those carry more than one weapon, so this fixes the loadout on 56% of the roster. What is lost is hand-working-around a *gap* in the option data; what is gained is that the editor stops inventing choices. The screen still says `no options published`, so a locked number explains itself.
- **Enumerated choices** — `replacement_choice` bundles that spell out whole selections. Stealth Battlesuits publish `[gun] | [marker, gun] | [marker]`, which is the rulebook's *up to two drones, of different types* written out. A closed list can be trusted as one, and becomes a single mutually-exclusive control. A bundle that repeats an item (`[heavy-flamer, heavy-flamer]`) means two of them, which is why selection counts rather than sets a flag.
- **Bare caps** — a `max_count` over single items. Shown, coloured when exceeded, and **never used to refuse the tap**, because the reference list disproves them: a validated 2,000 point export carries four T'au flamers on a Commander whose record says `max_count: 3`.
  - **Where both sources state a cap, the tighter one is the real one.** A Novitiate Squad's option reads `max_count: 4` over a choice of `[flamer] | [banner] | [simulacrum]` — 40kdc collapsing three separate limits into the number of *models* that may swap, and losing which item each belongs to. Read per item that becomes 0-4 of each, and the editor offered four Sacred Banners on a squad allowed one. The `wargear_budgets` lines carry what was lost — one banner, one simulacrum, two flamers, which is exactly BSData's `max 1`/`max 1`/`max 2` — and were being read as nothing at all. **62 item caps across the corpus were over-permissive this way**, on Skitarii Vanguard, Servitor Battleclades and others. Neither source is wrong: 4 is the aggregate and 1/1/2 are the parts.
  - **Where the cap really lives: the hardpoint, not the aggregate.** The user asked where a limit of 3 on a battlesuit came from, guessing it counted replacements of a default weapon. It counts *selections*: 40kdc gives a Commander one `max_count: 3` spread across ten different guns and support systems. BSData carries the real thing — a `Support Systems (1-4)` group whose entries each state their own cap: four T'au flamers, four missile pods, one shield generator, one cyclic ion blaster. The aggregate is wrong in both directions, forbidding the fourth flamer the reference export actually fields and permitting three shield generators. `wargear_caps` now carries the per-item number, for weapons as well as the ability-shaped kit that budget lines cover.
    - **Only on a single-model datasheet.** A Commander is one suit with four hardpoints, so an entry's cap is the unit's. On a squad the same entry means one *per model* — a Stealth team's `max 1` fusion blaster is one each and the unit takes two — so there the per-unit statements are used instead.
  - **Over-limit is now an error, on single-model datasheets only.** It was written once against the aggregate cap and withdrawn, because it called the reference export illegal in six places. With the per-item cap in hand the same list is clean, and the check ships — reported, never refused, so the `+` still works and §4.5's posture on the control is unchanged.
    - The scope is the whole of what makes it safe. On a single-model datasheet there is nothing to interpret: BSData states each hardpoint's limit and a Commander takes four T'au flamers and one shield generator. On a squad the sources do not say which caps are per model and which per unit — a Stealth team takes two fusion blasters across five suits and a Broadside team two missile drones across two, and **both read `1` somewhere**. `UnitLoadout.capsAreExact` carries the distinction rather than the validator guessing it.
    - **A missing composition is not a single-model unit.** The snapshot carries no compositions — only the builder needs them — so defaulting to one model made every cap in play mode look exact, and a Crisis team of three was reported for having three sets of battlesuit fists. Absence of data does not license an error (§2.3), and that default is asserted.

Replacement is one decision rather than two counters. Taking N of an item removes N of what it replaces and putting it back restores them, clamped at zero — a Fireknife suit has two hardpoints, so its default is three plasma rifles *and* three missile pods, and swapping moves guns between the two rather than adding to both.

Two things this surfaced. `wargear-options.json` was fetched, bundled and **never parsed** — neither `DatasetLoader` nor the app's bundle reader mapped it, so every datasheet looked unpublished for the right answer by accident. And `weapon_ids` carries scoped ids while `wargear_budgets` sometimes does and sometimes does not, so a Commander's Cyclic Ion Blaster appeared twice under one name; `SourceUnit.wargearVocabulary` is now the single place a datasheet's item ids are derived.

**Rules are not equipment, and two shapes of rule were arriving as equipment.** `Precise` appeared as a buyable wargear line with a `+` beside it on **1,113 datasheets across 29 factions**, and `Lethal Hits` on 304 more. Neither is a thing you can buy. Both reached the builder because BSData models a weapon, a wargear choice and a Crusade upgrade with the *same* `upgrade` entry shape, so nothing about the shape distinguishes them:

- **A rule hanging off a weapon.** Weapons are `upgrade` entries, so every rule linked from one was filed as wargear. The walk now tracks whether it is inside an entry that carries a `Ranged Weapons`/`Melee Weapons` profile, and a rule found there belongs to the gun.
- **A rule linked by a piece of wargear.** `Ratling Battlemutt` is an upgrade whose own profile makes it the wargear; it links the rule `Lethal Hits`, which is what the mutt *does*. Filing both as budget lines put the rule in the builder beside the mutt. A rule reached through an `infoLink` inside a wargear choice is now the wargear's rule, not a second thing to buy.
- **The Crusade group.** `Precise` is one of seven entries in the game system's `Weapon Modifications` group — `Armour Piercing (AP+1)`, `Brutal (S+1)` and the rest. Six carry no ability profile and were dropped by luck; `Precise` carries one, so it alone got through. The group is denylisted rather than the entry, because the other six are the same kind of thing and would arrive the moment upstream gave them a profile.

Filtering the weapon **keywords** had already been tried and could not have worked here: the keyword is `[PRECISION]` and the rule that grants it is named `Precise`, so the ids never meet. Measured over the corpus, wargear-budget entries fell from 3,255 to 1,786 and datasheets carrying an unrecognised one from 1,185 to 303. What remains is mostly real — Marks of Chaos, a storm shield — that `wargear.json` simply does not list, which is why "absent from `wargear.json`" was rejected as the filter: it would have taken genuine kit with it.

**Both markers fold before either is matched as a pair.** Small caps and bold mean the same thing here, and the first version matched them as *pairs* — which meant enumerating the orders the data writes them in, and the enumeration was wrong. `**^^X^^**` and `^^**X**^^` were handled; Custodes' `Revered Companions` writes `^^**Adeptus Custodes^^**`, opened nested and closed interleaved, and `**^^Adeptus Custodes**^^` in the next sentence. Neither matched, the bare small-caps rule then ran on half a pair, and the output lost the space in front of it — `All other**Adeptus Custodes`, which reads as a source typo and is not one: the source has the space.

Replacing `^^` with `**` *first* collapses all four orders to one shape — a run of four asterisks around the words — so no ordering has to be anticipated. A run of three or more is then one emphasis written twice, and becomes two. A test asserts every order folds to the same output, which the enumeration approach could not have (it passed on the two it knew).

**Combat Patrol content is scoped, and the scope was only half applied.** The 40kdc snapshot was first ingested with Combat Patrol records in it, and each carries `game_modes: [combat-patrol]` — 98 datasheets, 24 detachments, 47 enhancements. `Dataset.buildableUnits` had filtered the datasheets since §3.0; `allDetachments` never filtered, so **every faction offered its Combat Patrol formation in the picker at 1 DP** beside the real ones: `Sudden Dawn Cadre` for T'au, `’Ardmob` for Orks, `Maggot Lords` for Death Guard. `buildableDetachments` now mirrors `buildableUnits`, and for the same reason it is a second accessor rather than a filter on the first: a roster that already names one still has to resolve it (§2.2).

**An accented name was two datasheets.** `Brôkhyr Iron-master` slugs to `brokhyr-iron-master` in 40kdc, which transliterates; here `ô` is not `[a-z0-9]` and became a separator, giving `br-khyr-iron-master`. The two ids never met, so the merge *added* a second copy rather than filling in the first — five Leagues of Votann datasheets and Khârn the Betrayer were each offered twice, one copy unpriced. `bsSlug` folds the Latin-1 accents before separating, and a test asserts no faction lists the same datasheet name twice.

**A rule whose name carries a number keeps the number.** BSData writes `Scouts X"` as one shared rule, and a datasheet that has `Scouts 6"` links it with a name modifier — `{type: append, field: name, value: 6"}`. Reading the target's own name filed every such datasheet under `scouts`, the rulebook explanation of the ability, which carries no distance: a Dominion Squad showed "Scouts" with no number and never appeared in the Scout moves list, because the distance it was supposed to move lived in the id nobody had built. Link modifiers to `name` are now applied before slugging, with a separator inserted where neither side has one — `Scouts` + `6"` has to give `scouts-6`, not `scouts6`. It is not one datasheet: **58 units gain `Scouts 6"`, 33 `Scouts 9"`, 30 `Scouts 7"**, plus every `Deadly Demise X`, `Feel No Pain X` and `Firing Deck X` in the game, where the number is the whole content of the rule.

**Movement always carries its inch mark.** Upstream writes it both ways — `'7"'` on most datasheets, a bare `10` on a handful — so one screen showed `5"` on a statline and `10` in the move list, which reads as two different kinds of number. Normalised at the model rather than at either widget, since both were right about their own data. A trailing `+` is a minimum rather than a distance, so a Heldrake reads `12+"` and the mark goes after it.

**The weapon summary names the skill it is showing.** The column read `BS` and printed whatever the profile carried, so every melee weapon showed its Weapon Skill under a Ballistic Skill heading — a wrong label on a right number, which is worse than either alone. It reads `SKILL` now and takes `BS` or `WS` per profile, decided per *profile* rather than per weapon because a Fusion eliminator is typed ranged and carries a melee profile too. A heading that can no longer say which skill it means hands that job to the row: melee profiles sit on their own ground, and **pistols on their own again**. A pistol is the one ranged weapon you can fire while the enemy is already in engagement range, which is exactly the moment nobody wants to read a table — and its `RNG` cell is a number like any other gun's, so nothing else on the row says so. Only the pistol tint is given a key: a melee row already writes `Melee` in its own `RNG` cell, and a legend repeating the word beside a swatch is furniture. The key is drawn only when a pistol is on screen.

**The detachment brings its rules and stratagems into the builder.** Choosing a detachment is the second-largest decision in a list after the faction, and it was made from a name and a points cost — the two things it actually buys were in a tab that only opens once a battle is set up. Both are now previewed in the editor, folded by default: reference, not controls, nothing editable and nothing validated. Folded because the decision is the picker immediately above, and a builder that opens on two walls of rules text has buried the units. Core stratagems are excluded — they are always available and say nothing about this choice.

Attachment is also one decision seen from two sides. The character's sheet asks which unit it joins; the unit's sheet asks which character leads it, listing every eligible character **including ones already leading something else**, because that is usually the one you meant to move. Choosing a busy character moves it rather than refusing.

---

**A Unit Upgrade is limited to its datasheets, and upstream does not say so.** Both of T'au's publish `keyword_restrictions: ["T’au Empire"]` and nothing else, so the builder offered `Negation Emitters (Upgrade)` and `Unmasking Suite (Upgrade)` on every Character in the list. The rest of the eligibility filter was already right — Epic Heroes take none, an Enhancement wants a Character, a detachment scopes what it brings — and this was the hole in it: an upgrade skips the Character test by design, and then nothing else applied.

A keyword restriction could not express it either. The Unmasking Suite goes on Pathfinders **or** Stealth Battlesuits, and `keyword_restrictions` are all required at once. So `SourceEnhancement.unitIds` names the datasheets, empty meaning unrestricted, and `data-corrections.yaml` gained an `enhancements:` section to supply it — the restriction is real and the source has not got it, which is exactly what §3.6 is for. Reported by the app's user, who fields the army.

**Legends are hidden, not dropped, and it is a preference.** 485 of the 1,857 datasheets are shelved out of the tournament pool — Crusaders, Death Cult Assassins, Celestian Sacresant Aveline — and offering them beside the rest makes the unit picker a third longer with entries most events will not take. The switch is on the About screen, off by default, and its subtitle says what it costs rather than what it is for: *"Adds 485 shelved datasheets to the unit picker."* Hidden rather than filtered out of the data, because a Legends game is a real game and the datasheets are real; `is_legend` was already carried and had no reader.

Stored in a `Settings` table in the app database — a table rather than a new file, since the database is already here and already migrated, and there is one setting with no reason to add a second mechanism for it.

**A detachment says which force dispositions it brings**, in the picker and on the army page. The disposition decides which mission is played (§7.3.1), so it is half of what choosing a detachment buys, and it lived only in the pre-game wizard — two screens and a decision too late.

**Leaving waits for the write, and the caller always re-reads.** Two faults in one path, reported from the app as "edit an army, go back, the change is gone". `dispose` fired the pending autosave but did not *wait* for it, so the army page rebuilt from the database while the write was still in flight; and the page only reloaded when the builder popped `true`, which used to come from the Save button and stopped coming when that button was removed. The builder now holds the pop until `_persist` completes and always returns `true`.

**A failed save says so.** `_persist` swallowed every error on the reasoning that the explicit Save would surface it properly — and then Save went, leaving the only write in the screen able to fail in complete silence. It sets the error banner now. That silence is what made the bug above hard to see from the outside, and it would have hidden the next one too.

**Back saves; the button beside it undoes everything.** Edits are written as they are made, so leaving already kept them — which made `Save` a button that did what had happened anyway, and the undo arrow beside it read as a second back button. What was missing was the opposite: putting the army back as it was, which is what a person wants after an experiment. `Revert changes` does that, disabled until something has changed, and it asks first — it throws away every edit since the screen opened, including ones already written, and nothing else brings them back.

The same question is now asked before **removing a unit**. A unit is a loadout, an attachment and an enhancement chosen one at a time, and the button sits beside `Duplicate` where a mis-tap costs all of it. Deleting an army already asked; this was the other end of the same action and did not.

### 4.5.1 The one place the builder does refuse

§2.3 settled that the builder is permissive and the validator honest, and that
still holds for wargear: the option data is demonstrably incomplete, so a
`max_count` is guidance and never a stop.

**Unit size is different, and it is refused.** It is stated twice over — the
composition names each model and how many the unit may field, and the points
table prices whole brackets — and the failure it prevents is silent. A unit
grown past every bracket has none to price it, so it costs **zero** and the
army reads as cheaper than it is. That is worse than a refused tap.

The cap is **the looser of the two sources**, never one alone. They disagree on
35 of 1,961 datasheets — Cadian Shock Troops compose to twenty and are priced
to twenty-seven — and taking the tighter would be the builder calling a legal
list illegal. Where neither says anything, nothing is capped: a cap invented
from silence is the same mistake.

Two smaller findings came out of measuring it first, and neither was visible
from the report:

- `model_count.max` is **derived and wrong on eight datasheets** — a Loota mob
  comes to five and its max says one. Nothing reads it; the composition is the
  curated record and is what the cap uses.
- A list can still arrive over-size — imported, shared, or saved before the
  data said otherwise — so the validator names it. The builder stops you
  creating the state; the validator explains one that already exists.

### 4.5.2 A replacement names a quantity, and several models may make it

Two faults in one control, both reported from a Seraphim Squad.

**A repeated entry in `replaces` is a quantity, not a second swap.** The squad
reads `replaces: [bolt-pistol, bolt-pistol]` against a choice of two hand
flamers — two for two, once. The code iterated the list and applied the whole
change per entry, so two flamers arrived and **four** pistols left. **44 of the
1,296 published options are worded that way** — 27 plain counters and 17
either/or choices — so this was never one datasheet's problem.

**A bundle is what one model takes, and more than one model may take it.** The
group was yes-or-no, so a squad could make exactly one swap however many models
it had. `selectLoadoutBundle` now takes `copies`, and the editor offers a
`Models taking it` counter beside the choice.

**The ceiling is the unit's size, because nothing tighter is published.** The
real rule is two models per five; the data records `model_constraint:
{any_number: true}` and nothing else. Inventing the limit would assert a rule
the data does not have (§2.3) — so the count is capped by the models present
and the over-limit reporting has nothing tighter to check.

One test changed meaning rather than being loosened: two gun drones on a
Stealth team used to read as an off-menu combination and now reads as two
models each taking one. A combination that is *not* a whole number of any
bundle still reads as off-menu, which is what that test was protecting.

### 4.6 Managing a saved army

**Updating a saved army to current data.** §2.2 freezes a list on purpose, and that is what lets one written in March still open in September. The price is that it never *gains* either: an army saved before stratagem text existed shows none in play mode however often the app updates, and nothing on screen says why. The menu beside each army now carries `Update to current data`, which rebuilds the stored copy from today's dataset and leaves the `Roster` — units, loadouts, detachments — untouched. Only what the *data* says about those choices changes: points, rules, wording.

Asked for, never automatic, and the reason is the whole of §2.2: doing it on launch would re-cost somebody's army the night before a game. The dialog says what does not change before it says what might, and the result is reported either way — `Updated. 2000 → 1985 pts.` or `Updated. Still 2000 pts.` — because silence after an action the reader asked for reads as nothing having happened.



Three things happen to a list that exists: it gets opened, it gets copied to
try a variant, and it gets thrown away.

**Copying is how a variant gets made.** A list is rarely built twice from
nothing — the second one is the first with a squad swapped or an enhancement
moved. The copy takes the **snapshot verbatim** rather than rebuilding it from
today's dataset, because a copy that quietly costs differently from the list it
was copied from is worse than no copy at all (§2.2). It asks for the name up
front, defaulting to `<name> Copy`, numbering only once it has to distinguish
something. The battle in progress does not come along: it belongs to the game
being played, not to the list.

**Deleting asks first.** The swipe was the only route and it had no
confirmation behind it — an accidental drag while scrolling destroyed hours of
work with no undo. Both routes now ask, and the question says what is and is
not removed: finished battles keep their own record, because they copied what
they needed (§7.3.12).

The swipe stays, but it is no longer the only way in. It is undiscoverable, and
duplicating had nowhere to live at all; a per-row menu holds both.

**Duplicating a unit is inline.** It was reachable only from inside the unit
sheet, so putting three of the same squad in a list — an ordinary thing to
want — cost four taps each time.

### 4.7 A Unit Upgrade is not an Enhancement, and the screen forgot

Symphonic Payload goes on an Exorcist, which is a tank. The core already said
so — `SourceEnhancement.canBeTakenBy` answered true — but the editor drew the
whole section behind `if (datasheet.isCharacter)`, so the answer was never
asked for. **428 non-character datasheets across eight factions** had an
upgrade they may legally take and no way to take it.

Enhancements and Unit Upgrades share an encoding and a slot mechanism, which is
why they share a screen; they do not share the restriction that made the gate
look right. The filtering moved out of the widget into
`EnhancementOffers.of(dataset, roster, datasheet)`, so the question the screen
asks is the one the rules ask — *does anything in the taken detachments name
this unit?* — and the section appears when the answer is yes. The heading reads
`ENHANCEMENT` on a Character and `UNIT UPGRADE` otherwise, because on a tank
the first word is wrong.

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
- **There are two levels, and the buildings are the lower one.** A template's `footprint` is the *area terrain* boundary — the ground you are within. The ruins standing in it are its `features`, 72 of them across 38 templates, each a part template with its own position and rotation inside the parent's frame. Drawing only the footprint gives you the zone with nothing standing in it.
- **The two levels are authored in different frames, and the area has to be recentred to join the building's.** Features are placed about the origin — their cluster centre averages (0.5, 0.7) across the 38 composites — while the area footprint is exported anchored at a bounding-box *corner*, averaging (5.0, 3.3). Taken as authored, every base sits offset from the walls standing on it. Recentring the footprint on its bounding box is what puts them in one frame.
- **An objective is usually a building.** 275 of the 745 pieces carry an objective and 270 of those are ruins: the objective sits *in* the terrain, it is not a bare marker on open ground. Treating `is_objective` as "not terrain" drops a third of every table.
- **The pieces are lettered, and the letters are drawn.** Battlemaster's parts are marked `AB`, `CO`, `EF`, `GH`, plus `Tower`, `Corner`, `Generator`, `Pipes` and the barriers. Setting real terrain out to match the diagram is the point of having one, and the letter is what makes that possible — so each building carries its marking, centred, and is left unlabelled rather than shrunk where it will not fit (a 0.5″ barrier has no room, and a label spilling past its piece labels its neighbour). The label lives in the template `name` and nowhere else; there is no label field upstream. `Small L` and `Small L flip` are the same physical piece laid either way round and read the same.

- **A corner tick shows which way each piece is turned.** A bounding box is symmetric, so drawn alone it cannot say — but `part-ef`, `part-gh`, `part-co` and `part-small-l` each appear at 0°, 90°, 180° *and* 270°, and 0 and 180 are the same picture for a rectangle. Upstream would have no reason to distinguish them unless the real shape is asymmetric, which is the independent confirmation that these are L-shaped ruins and that `rotation_degrees` is carrying where the L points. The tick marks one consistent corner of the piece's own frame and turns with it, putting back information the box was discarding. It says **how the piece is turned**, not where its walls run — the caption says so, because upstream publishes no wall position to be right or wrong about.

> ⚠ **The outlines are bounding boxes, not the real shapes.** The physical Battlemaster pieces are L-shaped; upstream models every part the layouts use as a `width`/`height` rectangle — including the one *named* `Small L`, published as a plain 1.5×2.5 box. Properly L-shaped polygons do exist in the library (`corner-short`, `corner-ruin-left` and four more, all 6-point) but **no layout references any of them**. Drawing the real outline would mean inventing geometry the data does not have (§7.6), so the diagram shows the published footprint and the caption says so. A test asserts both halves: every part in use is a 4-point box, and `corner-short` is still unused — so this note fails loudly if upstream starts placing the real shapes. Worth reporting alongside the other upstream gaps (§3.9).
>
> **All four lettered ruins now have their real wall corner, read off a published diagram rather than guessed.** Battlemaster's own picture of `take-and-hold-vs-purge-the-foe-1` draws the walls, and one picture pins a part for good because the physical piece never changes. Tying the picture to the data was the careful part: a single affine map was fitted against **all six objective positions and both halves of the staggered deployment zones**, which is what rules out matching the wrong piece — the objectives alone are point-symmetric and fit two different mappings equally well. `AB`, `CD`, `EF` and `GH` are recorded in `TerrainTemplate._wallCorner` — the obstacles are not, having no L to point at.
>
> **Reading them by eye failed; re-rendering them succeeded.** Squinting at a 1152-pixel infographic to decide which side of a 45-pixel box a wall sits on is not a measurement, and the first attempt — one corner assumed to serve all four parts — was half wrong. What settled it was drawing the layout back into the picture's own frame and comparing the two pictures: `EF` and `GH` agreed, `AB` and `CD` visibly did not, and the corrected pair agrees on all eight placements. Turning "which pixel is that wall on" into "do these two drawings match" is the whole technique, and it is worth reaching for again the next time a fact only exists as an image.
>
> Two checks back it up. Each part appears twice at 180°, so a corner recorded on the wrong vertex satisfies one placement and breaks the other; and the layout is point-symmetric, so every pair must reflect through (30, 22) exactly. Both are asserted.
>
> ⚠ **The map was mirrored, and is not any more** (2026-08-19). Battlemaster's published picture of `take-and-hold-vs-purge-the-foe-1` put the attacker's deployment zone down the left; we drew it on the right, at identical board `x` — a reflection, not a rotation. **Board `y` runs down the screen**, and `projectOnto` used to flip it.
>
> What settled it was the *scope* of the fault, reported by the user against a build on their device: terrain, deployment zones and territories were all mirrored together. Those come from three different upstreams — `battlemaster-11e`, `gw-11e` and `leviathan` — so a fault in any one of them cannot explain it, and the single thing they share is this projection.
>
> **An earlier argument here was wrong and is retracted.** It ran: the library names three L polygons after the letter (`Short Corner L`, `Tiny Corner L`, `Corner Ruin (Left)`), and all three draw an `L` under `y`-up and a `Γ` under `y`-down, so `y` must point up. Those templates are `source: gw-11e`. The layouts are `source: battlemaster-11e`. One source's authoring convention says nothing about another's, and the argument never bore on the question. Winding order was checked too and carries nothing — CCW and CW appear within the same six templates.
>
> The lesson worth keeping: **every test in `deployment_projection_test.dart` except one is about internal consistency, and a mirrored map satisfies all of them.** The Jacobian-sign test proves the turned view matches the upright view; it cannot prove either is the table. Only `the attacker sets up on the left of the turned table` — an absolute claim tied to a published picture — could ever have caught this, and it did not exist until the mirror was found. A self-consistent projection is not a correct one.
>
> The recorded wall corners are unaffected: they were derived by inverting the picture's own fitted transform into board coordinates, which the rendering convention does not touch.
>
> **The lettered parts are the ruins; everything else is an obstacle.** Confirmed against the picture by the user: `AB`, `CD`, `EF` and `GH` are the green L-shaped ruin walls, while `Small L`, `Corner` and the barriers are the orange obstacles. So a wall corner is only a meaningful thing to record for the four lettered parts — the others have no L to point at, and `Corner` is a 1.5×1.5 square whose rotation is invisible in principle.
>
> **The set knows about handedness even though the geometry does not.** `part-small-l` and `part-small-l-flip` are used 14 and 4 times, are the same physical piece laid either way round, and ship as *identical* 1.5×2.5 rectangles — the flip survives only in the id. The library also carries properly L-shaped polygons in named left- and right-handed pairs (`Corner Ruin (Left)`/`(Right)`, `Corner Ruin (Balanced, Left)`/`(Right)`, plus `Short Corner L` and `Tiny Corner L`), each modelling a ruin as two 0.5″-thick arms meeting at one corner of its box. That is the shape model the recorded corners assume, and it is evidence that chirality is real in this data and was flattened, not absent.

> **`gdmissions.app` was checked for this and does not have it** (2026-08-19). It carries no terrain geometry at any depth — the layouts index and every per-disposition page contain zero occurrences of `footprint`, `rotation`, `polygon`, `points` or `pieces` — because it does not own the data and says so on the page: *"The terrain layouts now come from Battlemaster."* That is `battlemaster.online`, which is the same upstream already merged here, so it cannot supply anything the pipeline is missing. Its own footprint editor is behind a login and no public data endpoint answers. **Note also what was and was not missing:** `rotation_degrees` is in the data and the tick already turns with it, so the tick's *orientation* is right. The gap is the L's **wall position**, which is a different fact, and nothing reachable publishes it.
- **A rectangle's origin depends on its `kind`.** An `area` rectangle is a region authored from its corner; a `feature` rectangle is a physical object whose placement names where it *sits*, so it is centred on the origin. Measured, not assumed: centring features leaves 14 intersecting building pairs of 17,010, corner-anchoring them leaves 152. Twelve of the 14 are parts of one composite ruin interlocking — which is how an L is built from rectangles — and the last two are flush neighbours at zero depth.

> ⚠ **These are not Chapter Approved layouts.** Upstream publishes 45 from `battlemaster-11e` and one from `kotc`, and no Games Workshop set at all — `missions.json` carries the Chapter Approved source, the terrain does not. The screen names the source under every table and says plainly that it is not a Games Workshop publication (§7.6). If GW's own layouts are ever published as data, they slot into the same structure.

**Step 6 also draws the zones.** `deployment-patterns.json` publishes them as real geometry — polygons or `width`/`height` rectangles, each with a `position` offset, plus each player's territory and the objective coordinates — so the pattern can be shown rather than described. "Short edge deployment with L-shaped zones" is a sentence about a shape; the shape itself is in the data. Your half is **named** on the picture, not just coloured: the patterns are symmetric under attacker/defender, so the only thing making one side yours is the declaration made several steps earlier, which is exactly what nobody remembers while unpacking models. Opponent's disposition precedes the player's so the grid can collapse to two options at the moment of choosing; if the real sequence is simultaneous, step 4 shows the full 2×5 instead.

#### The full-screen table is turned, and it is pinchable

A phone is tall and a table is wide, and the mismatch costs more than it looks
like it should. Measured on the real content box (378×625pt in the full-screen
dialog on a 402×874 phone), across the two shipped board shapes:

| | Battlemaster (45 of 46 layouts) | KOTC Colosseum (1 of 46) |
| --- | --- | --- |
| board | 60×44″, aspect 1.36 | 36×36″, aspect 1.00 |
| pieces | 16, 6 objectives | 25, 5 objectives |
| upright | 6.30 px/inch, fills **44%** of the height | 10.50 px/inch, 60% |
| turned | 8.59 px/inch, fills **82%** | 10.50 px/inch — **no change** |
| phone physically turned | **5.11 px/inch** | 6.25 px/inch |

Three things the numbers settled:

- **Turning buys 1.36×, which is exactly the board's own aspect ratio**, and it
  buys it on every layout except the square one, where a quarter turn is the
  identity. The widget therefore turns a board only when it is wider than it is
  tall, rather than unconditionally.
- **Turning the phone is the worst of the three options**, not the best. iOS
  allows landscape and nothing here locks it, so this was worth checking: the
  app bar, the key row and the caption all live on the short dimension, and in
  landscape there is not enough of it. 5.11 px/inch against 8.59 for staying
  in portrait and turning the picture.
- **The writing does not turn.** The numbers are the entire point of the
  measured view, and a number you tilt your head to read is worse than a
  smaller upright one. Only the geometry is rotated.

**Zoom is a different fix from turning, and it is the one that unpicks the
labels.** Across all 46 layouts, 33 pairs of measurement numbers overlap at
the size they are first drawn; turning cuts that to 21, and **1.5× clears
every one of them**. That is a property of *this* zoom and not of zoom in
general: a plain `InteractiveViewer` transform magnifies the numbers along
with the board, so two overlapping labels stay overlapping however far in you
go — larger, and still on top of each other. So the board is **repainted at
the live scale** rather than merely transformed, and every paper length —
text, hairlines, the dashes in a leader, the offset a number sits at from its
anchor — is divided by the zoom to hold its size. The board grows; the
annotation does not.

One thing this made visible that was always true: a piece whose name is too
long to fit at 1× is left unlabelled, and zooming in is now the way to read
it. `Generator` and `Pipes` only appear once there is room.

It also exposed a defect that predates the zoom. 275 of the 745 pieces carry
an objective and 270 of those are ruins, so the marker and the piece's marking
were both drawn at the middle of the same shape — `Gen⊙tor`, with neither
readable. **The marker wins the middle**, because an objective inside a ruin
is the one thing on the table you must still be able to find; the writing
moves. It tries the centre, then below the marker, then above it, and is
dropped if none of the three fits — dropping being the same rule that has
always applied to a 0.5″ barrier with no room for a word.

**Turning is a rotation, not a transpose.** `(x, y) → (y, x)` puts the board
neatly in the turned box and mirrors it; a player copying a mirrored map sets
out a mirrored table, and nothing on screen would say so. The upright
projection already flips y once — board coordinates count up from the bottom,
screens count down — so the turned one must flip exactly once too. The test is
the sign of the Jacobian determinant rather than where the corners land,
because both versions put the corners somewhere plausible.

**The inline diagram is left alone** — not turned, not pinchable. It sits in a
form that scrolls, where a tall picture pushes the questions below it off the
screen and a pinch gesture competes with the scroll.

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

#### A rule the effect does not place, `phase-mappings.json` does

The turn page files a rule by `phases.contains(phase)`, and those phases came
from **walking the structured effect** — `_phase()` adds one while rendering
`Shooting phase: …`. That works only when the effect is about a phase.
`Righteous Repugnance` is a bare `stat-modifier`, add 3 Attacks, so walking it
yields nothing and the rule appeared in no phase section of any list with
Morvenn Vahl in it.

`phase-mappings.json` had said `command, movement, shooting, charge, fight`
for it the whole time. The file was loaded into `FactionData.phaseMappings`
and then read by nothing: **5,222 of the 8,533 published mappings** were for
abilities whose effect names no phase, which is to say the mapping existed
precisely where it was needed and was ignored precisely there.

`Catalogue.phasesFor` now exposes it and `RulesRenderer.render` takes it as
`published`, **unioned** with the derived phases rather than replacing them —
where the effect does name a phase that is the more specific statement.

**And the mapping is sometimes wrong in the other direction.** Honouring it
put `Righteous Repugnance` in the Charge section, because the file lists it
under all five phases while its printed rule says "selected to shoot or
fight". 183 of the 3,745 mappings name all five, and the shape of the
distribution says why: 174 mappings name three phases, 27 name four, and then
183 name five. That spike after the trough is a placeholder, not a claim.

It cannot be ignored wholesale, though — **37 of the 183 are right**.
`Unholy Vigour` really is "at the start of any phase" and `Grotesque
Regeneration` "at the end of each phase". So `data-corrections.yaml` gained a
`phase_mappings:` section and 22 entries, each quoting the printed text that
settles it. Two more were left alone: `legacy-of-the-angel` and
`murderous-agenda` both read "at the start of the first battle round", which
is not a phase claim their text can answer.

**The snapshot carries them too**, and has to: play mode reads only the
snapshot (§2.2), so a mapping that lived on the faction dataset would have
fixed the reference screen and left the turn page exactly as broken. An older
snapshot without the field opens with its rules unfiled rather than failing,
the same way one written before stratagems does, and `Update to current data`
refills it (§4.6).

### 7.3.10 The Scouting step

Scout moves happen after deployment and before the first turn, and a Scout move not taken then cannot be taken later. Nothing in the app asked the question, so the turn page gains a **SCOUTING** section ahead of COMMAND — a pre-game list, not a phase of the turn, carrying none of the per-phase machinery.

**The distance comes from the effect, not the name.** Upstream writes it into both — `Scouts 7"` and `{move_type: scout, distance: 7}` — and the name is the half that varies. Reading the effect immediately found a case name-matching would have dropped: the Necrons' **Enlivened Sentinels** grants a 5" Scout move and never says "Scouts".

**A led unit is listed only if every part of it has the move.** Scouts is worded *if every model in this unit has this ability*, so a character without it takes the move away from the squad it joined, and where both have it the shorter distance governs. Listing a move a unit cannot make is worse than listing none: it is the kind of thing a player acts on and cannot undo. This is read from the rulebook's wording, not from the data — the dataset does not encode attachment interaction — and is the one place on this screen the app is interpreting rather than reporting.

### 7.3.11 Where scoring happens, and where the game is read

Two questions, and the turn page can only answer one of them.

**Scoring stays on the turn page**, next to the tap that records it. But it was all in END, and that is not where half of it happens: across all 43 cards **every** `end-of-phase` award is `phase: command` and **every** one is gated at `battle_round >= 2`. That is the primary mission's round-2-onward tier — the largest single source of victory points in a game — and the player was meeting it a phase and a scroll away from where the rulebook says to score it. The COMMAND section now carries the same `ScorePanel` widget, shown when the mission data says something pays out this round rather than when the round number looks right, so a new tier upstream is picked up rather than missed.

**One panel, not two.** `ScorePanel` reads [BattleState] and emits events; wherever it appears it is showing the same numbers, because there is nowhere for a second copy of them to live. A second place to *enter* points would have been a second source of truth and the first thing to drift.

**The objectives page answers the other question** — *where does the game stand* — which the turn page structurally cannot, because the answer spans five rounds and two missions and the turn page only ever shows the round you are in. It carries the margin (two bare totals make the player do the subtraction), a per-round breakdown split primary from secondary, each side's mission in full with which tiers are live this round, and the secondaries in hand. It is entirely derived: nothing on it can be edited, so it cannot disagree with the turn page.

A round that scored nothing reads as `–` rather than `0`. Zero is a result; blank is *not yet*.

**Phase content folds.** Phase-as-scroll-position (§7.2) breaks once a phase carries several kinds of content, because a phase you are not using pushes the one you are off the screen. Stratagems, profiles and scoring are each a `CollapsibleGroup`, open where the decision is made and folded where they are reference. A folded group still shows its count, so folding never hides that something exists.

### 7.3.12 When a battle is over

A game that has been played out has nowhere to go. The log stays on the
roster as its *current* battle, so the Turn tab opens on a game that finished
last Tuesday, and the only way to start another is to play over the top of it.

**Finishing is one action, not two.** The log is copied into a record and the
roster's is cleared together — a finished battle left in `battleLogJson` would
still be the current game. It is the one action on this screen that cannot be
undone, so it asks first, quoting the score it is about to file.

**The record keeps the whole log.** A finished battle is the same append-only
history it was while being played (§7.4), so it can be replayed — every
round's scoring, the table it was fought on, the stratagems spent. Storing
only the final numbers would make the history page cheap to build and
impossible to extend. The columns beside it exist so the list draws a row
without decoding a document per battle, which is the same split the roster
list uses (§4.3).

The army's name and faction are **copied into the record**, not referenced. A
roster can be renamed or deleted afterwards, and what happened in a finished
battle must not change with it.

**The Play tab rests on the history.** With no game in progress it used to
show a prompt with a button on it, which is a screen that exists to hold a
control. What a player wants between games is the record — who they played,
what each side declared, how it ended, and the table it was on — with the
button to start the next one on top of it rather than instead of it.

**And it is that army's history, not every army's.** The page opens on the
Play tab of one list; a roll-up of every roster's games answers a question
nobody asked there, and two armies of the same faction produce rows that look
interchangeable. The record already keeps the roster id it was played with, so
the filter costs nothing.

The army's name then stops earning its place on the row — repeating it on
every line of its own history says nothing, and the opponent is what tells the
rows apart. It is kept for the one case where it is the most interesting thing
there: a record holds the name it was **played under**, so a list renamed since
shows what it used to be called on the games played before the rename. A copy,
having a new roster id, starts with no history — correctly, since the games
belong to the list it was copied from.

### 7.3.13 The turn page, sorted by unit

The page this replaces was six phase sections, each carrying every unit's
weapons and every rule's text again. Rendered and measured rather than
estimated — `TurnScreen` at 390x844, scrolled to the end so every child laid
out:

| | T'au 2k | Marines 2k | Incursion 1k |
| --- | --- | --- | --- |
| scroll per turn | **32,732px — 41.7 screens** | 5,020px — 6.4 | 10,712px — 13.6 |
| SHOOTING | 61% | 45% | 44% |
| strings drawn | 890 | 311 | 531 |
| distinct strings | 169 | 109 | 147 |
| **repeats** | **838 of 890 (94%)** | 82% | 88% |

Two facts settle the shape. **94% of what is drawn is a repeat**, and **phase
is a property of rules while what you scroll past is units and weapons**, which
are phase-invariant. Sorting by phase is what forced the duplication; sorting
by unit removes it arithmetically rather than by trimming.

A first pass counted "rows" from the data model and put T'au at 1.94x the
Marines. Rendering says **6.5x**: rows are not equal height, and a weapon row
draws a full stat block. The formula was measuring the wrong thing and every
ratio derived from it was wrong — which is why load-bearing numbers are now
checked a second way before they decide anything.

**What is on the page and what is behind a tap** follows one measurement. A
rule *name* is 12-15 characters; its printed text is 174-198 on average and up
to 993. Names cost 15-30 lines for a whole army, printed text 330-686 —
uniformly, in every faction. So names and weapon statlines stay on the page and
**rules text is the only thing behind a tap**. Opening a card per unit to read
a gun would reintroduce the travel this design exists to remove.

**Stratagems are collected, not de-duplicated.** Only **3 of 19** appear in
more than one phase, so scattering them across six sections never repeated
them — it meant hunting six places for sixteen cards that each live in one.

**Density is per roster, not per player** (§7.3.14), because how much you need
in front of you depends on how well you know *that army*.

**One control moves the game on.** `EndTurn` passes the turn, advances the
round when it returns to whoever opened, and grants the Command phase's
command point — all derived, so an older log replays the same and none of it
can be forgotten by a player who was looking at the table. CP was previously a
stepper nobody remembered to press.

**Scoring is one tap wherever the card names a figure.** The primary — the
largest source of victory points in a game — was a `+1` stepper: across the
shipped cards there are **96 flat awards at a mean of 4.4 taps each**. 81% of
cards name at least one flat figure and become buttons; the 19% that pay *per
objective* keep a stepper, because the app cannot see the table. Both sides
score the same way, since knowing you are on 42 is useless without knowing they
are on 47.

### 7.3.14 Guided and compact are one page at two densities

An army you have never played wants what an army you know does not. The first
design for this was a stage-by-stage walkthrough; that was wrong, because
phase-per-page breaks the rule that everything is present at once — and it
turned out to be unnecessary. Counting a prompt as one *distinct* thing to
remember, a whole turn is **53 / 48 / 41** prompts, against the 169 rows the
old page spent on the same content. Deduplication is what makes the guided
reading affordable, so it is a prerequisite for both readings rather than a
trade between them.

Three positions on one axis, defaulting from the roster's own size:

- **Names** — unit rows and rule names; weapons fold away.
- **Full** — adds the weapon statlines. The default under 40 weapon rows.
- **Guided** — adds the per-phase prompts, each rule listed once with a count
  of the units that carry it.

### 7.3.15 The record

The log has always been the state (§7.4); what was missing was a way to read
it. Mid-game the question is *what did I already score this round*, which was
answerable only by unpicking the scoreboard. Afterwards, the finished battle
showed a verdict and a per-round score table but nothing about what happened
in it.

One widget, both places. It is **derived from the log rather than summarised at
the end**, because a summary written once cannot answer a question nobody
thought to ask while writing it — and the whole log is already stored, so
there is nothing to gain by condensing it.

**Placing an event in its round is a replay.** Most events carry no round of
their own: drawing a card or losing a model is recorded as it happens and takes
its place from the events before it. `BattleLog.timeline` walks the log by the
same round and turn rules `state` does, and a test asserts the two agree —
which is what catches one being changed without the other. Stamping a round
onto each event at creation was the alternative, and it would put a derived
value in the log where an undo could leave it wrong.

**Bookkeeping is left out.** A command point corrected by hand, a round set
straight because the app and the table disagreed: those are how the log stays
honest, not what happened in the game. Six of the fourteen event types are
narrative; printing the rest turns a record into an audit.

**Ids that no longer resolve are shown as the log holds them.** A finished
battle outlives the roster it was played with, so a unit deleted since reads as
its id rather than as a blank — losing the line would lose the only record that
the casualty happened at all.

### 7.3.16 Both players hold cards, from copies of the same deck

Asked for on 2026-08-24. Three separate things were wrong.

**Nothing could draw a card.** `SecondaryPanel` — draw, choose, discard, score
— lived in `end_phase.dart`, and nothing had imported it since the turn page
was rebuilt (§7.3.13). The running app had the anonymous `+1` secondary chip
and no way to say which card it was for. The panel moved to
`secondary_cards.dart`; `end_phase.dart` and the `ScorePanel` that `ScoreBoard`
replaced are deleted.

**The opponent had no cards at all.** `SecondaryState` had no player dimension,
`ScoreSecondaryCard` had no side, and the reducer credited `Player.me`
unconditionally. All three now carry a side, and the state keeps one hand per
player.

**The decks are copies, not one deck.** Superseded, 2026-08-24:
`secondary_deck.dart` said there was no per-player copy because the decks are
identical. Identical is not shared — treating my draw as spending their card is
a different game. Each side draws from the cards *that side* has not seen, so
the same objective can sit in both hands, which is the user's own framing:
"the deck is a copy, so our objectives can intersect".

`side` defaults to `me` on every event, so a battle saved before this replays
to the state it always had: the absent field reads as mine, which is what it
meant.

**The cards open in place, not in a sheet.** The first build put each side's
panel in a modal sheet, and drawing into it did nothing visible — a sheet is a
route built once from the state it captured, so the row behind updated and the
sheet did not. Inline, the board rebuilds on every event. Two panels can be
open at once, which is also how you compare what each side is chasing.

### 7.3.17 What the card asks for, next to what it pays

The scoring row's buttons are the figures a card names. Which figure to tap
depends on what the card *asks for*, and that was on another tab.

**The mission is named on the row that scores it, and opens in full on a tap** —
both missions. Theirs is a different card, the matchup is asymmetric, and how
they score is what decides where you contest.

**A unit's rules are one tap, and the whole set is one more.** Chips were
already tappable, but a chip per rule is a good index and a bad reading order:
checking an interaction meant opening four sheets and holding them in your
head. `All N` opens every rule the unit has, in full, in one scroll —
attributed where the group is more than one datasheet, since a Commander
leading a squad brings rules the squad does not have (§3.8). `attributedRules`
had carried that attribution since the leader work and nothing had used it.

Also fixed here: the single-rule sheet used `Text` rather than `RuleText`, so
`**KEYWORD**` printed its asterisks — the exact failure `rule_text.dart`
exists to prevent, on the one surface that had it.

**Weapon keywords are still not tappable, and that is a data gap rather than a
decision.** `TORRENT`, `DEVASTATING WOUNDS` and the other 32 ship with
`effect: null` — 40kdc publishes the keyword's name and parameters but no
rules text for any of them. A tappable chip would open an empty sheet, which is
worse than a chip that does not invite the tap. It needs a source, not a
widget.

### 7.3.18 Command points: two buttons, and a card that buys one

**The plus is a button now.** Command points were a tap on the figure to add
and a long press to subtract — two invisible gestures on the number a player
adjusts more than any other. The plus is always there; the minus appears beside
it once there is something to spend.

**A card can be traded for a command point, once per battle round.** The
allowance is keyed to the battle round rather than the turn, so passing the
turn back does not refresh it, and `cpTradedRounds` records which rounds are
spent. `DiscardSecondary` carries a `forCp` flag rather than a second event
type: the discard is the same discard, and the record reads "discarded for CP"
where it applies, because a command point that appeared with no reason attached
is the kind of thing an opponent asks about.

Superseded, 2026-08-24: this said only this player's points were tracked, so
only this player's trade could pay — the opponent's panel offered a plain
discard. §7.3.21 gave them a pool, and both sides' trades pay now.

### 7.3.19 The objectives page is one fold per side

It was five groups and two sheets: the standings, the history, your primary,
their primary, the hand — each folding separately, with card text behind a tap.
A page read while working out what you scored should not be a set of doors.

**One collapsible per side now, holding everything that side has**: the mission
name, what it pays this round, its full text, the buttons that score it, and
that side's cards. Nothing folds inside a fold and nothing opens a sheet.

**Scoring is on this page too.** It reads the same `BattleState` and emits the
same events as the turn page's board, so the two cannot disagree — and the page
where a player works out what they scored is the page where they should be able
to enter it.

### 7.3.20 Reading a turn that has already been played

**Previous turn and Next turn at the foot of the page**, where a turn actually
ends, with End turn under them — you have just read down the page, and the
control that moves the game on was back at the top.

Stepping back shows the state **as it stood at the end of that turn**: the
score, the command points, what the cards were. The boundaries come from
`timeline`, which already places every event in its round and turn, so the
review is the same replay the live state is rather than a second reading of the
log.

**Reviewing is reading.** Every control is inert while a past turn is shown,
Next turn only exists once there is a turn to come back to, and a banner says
which turn it is and that nothing there can change. A tap that scored into
round two from a page that looked like round two would be a different feature,
and a surprising one.

### 7.3.21 The opponent's command points, beside their score

Asked for the same day the trade landed, and it reverses §7.3.18's "only this
player's points are tracked".

**Not in the bar.** The bar is this player's — the round, their own points, the
control that ends their turn. Theirs go on the row that scores for them, next
to the total they are compared against, which is the other thing about the
opponent worth knowing mid-game.

**Both rows carry one**, so the two read the same way and a glance answers
"who can afford what". Mine is in both places; the bar and the row are the same
state, in the way End turn is in two places for the same reason.

**Derived where it follows from the turn, entered everywhere else.** A turn
beginning grants a command point to **both** players — corrected 2026-08-24,
having first been written as a grant to whoever was taking the turn. Whoever
opens is therefore not a point ahead, and a full battle round is worth two to
each side. Everything else is entered, because the app cannot see their table
any more than it can see their hand. The minus appears only when there is
something to spend.

Superseded, 2026-08-24: the grant went to the active player only, which is
where §7.4's earlier derivation started and where this player's own points came
from. Both sides gain one now, on the same event.

`AdjustCp` takes a side, defaulting to `me`, so a battle saved before today
replays unchanged.

### 7.3.22 The button belongs to the sentence

A row of `+2 +4 +1` above a block of card text asks the player to read the
conditions, work out which one they met, remember which figure went with it,
and then find that figure in a row of chips. Four steps for one decision, and
the third is done from memory.

**Each payout's button is on the line that earns it.**

```
4 VP: You control one or more objectives (excluding your home objective).  [Score 4]
4 VP: You control three or more objectives.                                [Score 4]
```

Reading the line and tapping it are one motion. Nothing scores from a figure
floating free of its condition — which was the state of both the turn page and
the objectives page before this.

**Parsed from the card's own text, not re-derived.** `ScoringText` reads the
composed lines (§3.11) and treats one opening `4 VP:`, `+2 VP each:` or
`5 VP, max 15 VP:` as a payout. Measured across all 43 shipped cards: **130
payout lines, and every card has at least one.** Where the structure disagrees
it is because the card pays *per objective* and names a figure the structure
records as `vp_per` — the line is what the player reads, so the line is what
carries the button.

**Secondaries the same way.** A card's `Score 3` and `Score 5` were chips in a
row beneath its text; they are on the lines that earn them now. A card whose
figures are all *per something* — 2 VP per objective — still gets the `Score…`
stepper, because the total is the player's to count, and `ScoringText.hasPayout`
is what decides which case a card is in.

**The mission opens in place.** It was a modal sheet on the turn page while
the cards beside it expanded inline — two interaction models on one row. What
is left of the old scoring row is the `+1` for cards that pay per something the
app cannot see, and the `−1` for a mis-tap.

**A defect the parser found before the feature shipped.** Two cards composed as
`++1 VP each` — the source already wrote the `+` that `_vpLabel` then added, so
`assassination` and `defend-stronghold` had a line the parser did not recognise
and would have silently lost a button on. Fixed in the merge; the regex accepts
a repeated `+` regardless, on the principle that a doubled sign should cost a
button's appearance rather than its existence.

### 7.3.23 The map is drawn in the printed layout's inks

Chapter Approved colours its layouts, and the colour is a rules distinction
rather than decoration: the lettered ruins are what blocks line of sight and
what models climb. Our map drew all 745 pieces in one grey, so it said none of
that.

**The colour belongs to the object, not to the ground it stands on.** One area
footprint routinely carries a lettered ruin *and* a barricade — 
`take-and-hold-mirror-1` alone has 28 objects on 16 areas — and the printed map
colours those separately while leaving the area grey. Colouring the area was
the first attempt and it was wrong for exactly that reason.

So the group lives on `TerrainTemplate`, keyed by part:

| Part | Group | Ink |
| --- | --- | --- |
| `part-ab`, `part-co`, `part-ef`, `part-gh` | ruin | brown |
| `part-generator`, `part-tower`, `part-pipes` | structure | dark green |
| `part-small-l`, `part-small-l-flip`, `part-corner`, `part-short-barrier`, `part-long-barrier` | barricade | dark yellow |

**Twelve parts in the whole published set**, so this is a list rather than a
rule inferred from geometry — and a part missing from it draws neutral rather
than joining a group by default.

**The list is read off the printed picture, so it is pinned name by name.**
`Pipes` was first filed as a barricade on its shape and is a structure: the
printed layout draws it green. A shape heuristic cannot know that, which is
why the table is enumerated and every entry asserted rather than derived.

Four tests hold it: each of the twelve parts is in its stated group, every
placed part has a group at all, the lettered parts are the ruins *and only
those*, and at least one area carries two inks — the last being the fact that
makes an area-level colour wrong.

### 7.3.24 One fold per side, named for whose it is

The score board asked the same question twice per side: a mission name that
expanded the primary, and a `Cards` button that expanded the hand. Both answer
*what can I score* — and the player deciding that wants both at once, since the
primary and the secondaries compete for the same units in the same turn.

**`MY OBJECTIVES` and `<their name> OBJECTIVES`**, one fold each, holding the
primary card and that side's hand together. Folded, the header still says what
is inside — `Secure Asset · 1 card` — so folding hides the detail and never the
existence (the rule `CollapsibleGroup` already follows).

The objectives page names its two blocks the same way, so the two surfaces
agree.

### 7.3.25 The card picker edits the hand, and both discards ask

Two faults with one cause: the app treated a hand as a thing that only grows
forward. `Choose` offered the cards **nobody had drawn yet**, so a card entered
as the wrong one, a discard that did not happen at the table, or three turns
played on paper and typed in afterwards were all unfixable — the correction the
player needed was the one option not on the list. And a discard, the single
action on a card that cannot be read back off the table, fired on one tap from
a chip sitting a finger's width from `Score 5`.

- **The picker is the whole deck as a checklist.** Cards in hand open selected
  and carry an `in hand` pill; discarded ones are tinted and carry a
  `discarded` pill, and can be selected again. Tapping toggles. Whatever is
  selected when the sheet closes *is* the hand: additions become
  `DrawSecondary`, removals become a plain `DiscardSecondary`. A correction is
  never a trade, so it never pays a command point.
- **Both pills are shown, not one.** In hand and discarded are different facts.
  A player scanning eighteen cards for the one they misfiled needs to see which
  ones they have already turned down.
- **Closing by the button and swiping the sheet away both save.** The selection
  is a set the sheet writes into, and the panel reads it after the await.
  Losing edits on a swipe would be the app discarding something the player
  entered (§7.7).
- **`DrawSecondary` now removes the card from `discarded`.** A card back in
  hand is not still discarded; leaving it in both lists showed it twice.
- **Both discards confirm first**, naming the card, and the CP one also names
  what it spends: one card a battle round trades this way, and the tap that
  spends it should not be the tap that was aimed at `Score 5`.

### 7.3.26 The published secondary sequence, with two corrections

The Warhammer Event Companion prints the whole Secondary Mission sequence, and
the app had been following a version assembled from what was known at the
time. It now follows the published one, **except two things it keeps its own
way, at the user's decision on 2026-08-27**:

- **One card is drawn at a time.** The rules say draw two at the start of your
  Command phase. Two taps is more manageable on a phone than one that deals a
  pair, and the resulting hand is identical.
- **`Choose` stays a free correction.** §7.3.25 made it the whole deck as a
  checklist so a mis-recorded hand can be fixed. It is not made to obey the
  drawing rules — it carries labels and no limits, because what it is for is
  the moment the app and the table disagree.

Everything else now matches:

| | Fixed | Tactical |
|---|---|---|
| Chosen | two, at setup | drawn from the deck |
| Achieving it | keeps the card | discards it |
| Discarding | **not possible** | end of your turn |
| Command point | — | one for the act, once per **your turn** |
| The paid swap | — | 1CP, once per battle |
| Cap | 20VP per card | — |

**The discard point moved from the round to the turn.** Superseding §7.3.18:
the allowance was one per battle round and shared; the sequence puts it at the
end of *your* turn, one or more cards discarded together for a **single**
point. So it is tracked per side and per turn, and passing the turn is what
refreshes it.

**The paid swap is its own event.** `RedrawSecondary` rather than a flag on
`DiscardSecondary`, because it is the opposite transaction — a plain discard
*gains* a point, this one *spends* one — and a log that cannot tell them apart
cannot answer where the points went. It discards and charges; the draw that
follows is the player's own, since the app records what happened rather than
dealing cards. Its confirmation says what it costs, because the two chips sit
a finger apart and move CP in opposite directions.

**A Fixed mission is a different card.** It is active all battle, so achieving
it does not spend it, it cannot be discarded at all — the chips are absent
rather than disabled — and it caps at 20VP, which is the only per-card ceiling
in the game and exists because a Fixed card would otherwise have none.

**The primary is capped now too.** It never was, because nothing the app read
published its limits. The Companion does: 15 in a round and 45 over the
battle, the same as the secondary. Both tables are capped as they are built,
so a round's figure and the total always agree — capping only the total left
the breakdown saying something the sum did not.

**The caps are shown, not enforced.** The board says `3 left` or `round full`
beside a source, and only once five or fewer remain: a cap nowhere near biting
is noise on a screen read mid-turn, and a cap about to stop the number moving
is the reason it stopped.

Battle Ready's 10VP is deliberately not modelled — it is a property of the
army's paint, which the app has no business asserting.

### 7.3.27 A capped rate has only a few answers

`2 VP: For each enemy unit destroyed this turn`, capped at 5, can only ever
be worth **2, 4 or 5**. The third kill is worth one point, not two. The card
prints the rate and the ceiling and leaves the arithmetic to a player with a
clock running, and the app was doing the same: one `Score 2` button, or a
stepper to type a figure into.

Each reachable total is now its own button on the line that earns it. Six of
the shipped cards have such an award — Burden of Trust and No Prisoners are
2/4/5, Overwhelming Force and Behind Enemy Lines are 3/5, Bring It Down and A
Grievous Blow reach their cap in one.

**The ceiling is in the structured award, not in the wording.** `vp_per` with
`vp_max`, which is why `ScoringText` now takes the card as well as its text:
the line says *2 VP: For each…* and nothing in it says where it stops.

**An uncapped rate counts the things instead.** `3 VP each: For each objective
you control` has no ceiling of its own, so there is no short list to offer.
`Score…` opens a counter over the **objectives**, not the points: how many a
player holds is what they know at the table, and the arithmetic follows from
it. The sheet shows the rate, what the count comes to, and how much the round
has left.

**The round's cap is enforced there**, because it is the one place the app can
see the rate and the headroom together. Fifteen a round means the fifth
objective at 3VP each is worth nothing; the sheet says `Only 4 left this
round, so 6 VP scores 4` and the button offers the figure that will actually
land. Counting higher is still allowed — the player may genuinely hold six —
it just stops adding points, which is what the rules say happens.

Eighteen cards have such an award, fourteen of them primaries: Battlefield
Dominance, Determined Acquisition, Outmanoeuvre and the rest of the
objective-holding missions, plus Assassination, Beacon, Bring It Down and A
Grievous Blow among the secondaries.

**A capped rate keeps its ladder** — three buttons at most, which is quicker
than a counter for something that can only be 2, 4 or 5.

### 7.3.28 The map's numbers hold their size, then grow

A plain transform scales the lettering with the geometry, so two overlapping
numbers stay overlapping however far you zoom — bigger, and still on top of
each other. That is why they were paper lengths: constant on screen, so
zooming spreads them apart and a crowded corner comes undone.

That is right up to a point and wrong past it. Once the labels have separated
the reader is no longer picking one out of a heap, they are reading it, and a
number held at 8pt on a board magnified six times is small for no reason.

**So lettering holds its size to 4× — three fifths of the way from the
viewer's minimum to its maximum — and grows with the board after that.** At 6×
a label is half again the size it was. `letteringDivisor` is the whole rule,
named rather than inlined so it can be tested without a golden.

**Hairlines and dashes stay paper lengths at every magnification.** A leader
line that thickened with the zoom would read as a wall, which is a thing on
this diagram already.

**The offsets that place a label grow with it.** The stand-off that holds a
number clear of its piece, the shadow it sits in, the letter-spacing: all
lettering lengths. Growing the font alone would walk the text onto its own
leader line.

### 7.3.29 A turn's scoring is reviewable, and a card's is takeable back

Two halves of one problem: points went onto the board one tap at a time, with
no moment where the turn as a whole could be read back, and no way to correct
a card scored by mistake except undo — which pops the last event, not the
wrong one.

**`End turn` opens the turn's scoring first.** Every `ScoreVp`,
`ScoreSecondaryCard` and `UnscoreSecondary` since the last `EndTurn`, one row
each, with who scored it and what for. It is the last moment a turn can be
corrected while the player still remembers what happened; once the turn is
handed on, what was in it is a question about the past. Both `End turn`
controls go through it — the bar's and the one at the foot of the page — or
the bar's would be a way past the check.

`LogEntry` gained a `turn`, and `BattleLog.scoringIn(turn)` is the query. The
timeline increments its turn on `EndTurn`, in step with the state, so the
sheet and the board agree about which turn is being reviewed.

**Corrections are appended, never cut out.** Taking back a primary emits a
`ScoreVp` of the same size with the sign flipped; taking back a card emits
`UnscoreSecondary`, which subtracts the points, drops it from the scored set
and puts it back in the hand. The events are deltas, so a take-back is another
delta and undo still works one pop at a time. A row that *is* a correction
offers no take-back of its own — undoing an undo is undo's job.

**The fold says the running total.** `12 VP this turn` beside `MY OBJECTIVES`,
so the number that the review will account for is visible without opening
anything.

**A secondary is scored in its own popup.** The tile carries `Score…`; the
popup shows the card's text with each payout's button on the line that earns
it (§7.3.22), the ladders where the line caps (§7.3.27), and — this is the
part that differs from the board — the counter **inline** where the rate has
no ceiling of its own. A second modal on top of a modal to count objectives
would be a window over a window, so `ScoreCounter` was split out of
`ScoreCounterSheet`: the board opens the sheet, the popup embeds the counter.

**Scoring it removes it from the hand, and choosing it again warns.** A card
already scored shows a `scored 5` pill in `Choose`; re-selecting it asks *Take
back Outflank? · Subtracts the 5 VP it scored.* and, confirmed, emits the same
`UnscoreSecondary`. So there is exactly one way back from a mistake, reachable
from either end.

### 3.18 The dataset is served, and the app is pointed at it

`HttpBundleSource` existed from §3.4 and was never constructed: the app read
its own assets and nothing else. So the layout button said *Not downloaded*,
and a correction patch could not reach an installed app at all — the whole
point of §3.15's channel.

**`https://structor.systematum.net/data/`** now serves the manifest, the 36
faction bundles, the correction patch and the 45 layout pictures — 18 MB, off
the same container as the page, so DNS, TLS and the tunnel are already there.
The paths match the manifest's own `file` values, which is why the images keep
their own directory. `main.dart` reads the base URL from
`String.fromEnvironment('STRUCTOR_DATA')`, so a build can be pointed elsewhere
and an empty value turns the network off.

**The app still installs complete.** Everything but the pictures is in the
binary: 38 files, 6.5 MB, patch included. A test asserts exactly that — every
bundle and patch the manifest names is fetchable from assets, and every layout
image is not.

**The data path revalidates rather than caching.** The app refuses bytes whose
sha256 does not match the manifest, so a stale bundle is not *wrong*, it is
**absent** — the app falls back to its built-in copy and quietly stops
updating. Cloudflare honours that for the manifest (`cf-cache-status:
DYNAMIC`) and overrides it for `.json.gz` and `.png`, which it holds at the
edge for four hours. Safe, since the hash check rejects them, but it delays an
update by up to that long. **Done in §3.19**: the published names now carry
the hash, so the edge holding a file for four hours is no longer a delay but
the intended behaviour.

**Two things the deploy check exists to catch.** The bundles are already
gzipped and must never be sent with `Content-Encoding: gzip` — the app gunzips
the body itself and would hand plain JSON to the inflater. And the sha256 of a
bundle, the patch and an image are verified over the wire, because "the file
is served" and "the app can read it" are different claims.

**A false alarm worth recording.** The first probe of the live host through
the app's own code returned null on every attempt, which read as a broken
deploy. It was `TestWidgetsFlutterBinding.ensureInitialized()`: Flutter's test
binding stubs HTTP out. The same code without it fetched the manifest, a
bundle, the patch and an image. A network probe that runs inside `flutter
test` is measuring the harness.

### 3.19 Published names carry the hash

Every file the manifest names is published as `core.345fbbd057f6.json.gz` —
the stem, twelve hex characters of its sha256, then the extension it always
had. The content decides the name, so a file that changed is a URL nothing has
ever cached, and a file that did not keeps the URL every cache already holds.

**This is what §3.18 was working around.** The app verifies the sha256 of
everything it loads, so a stale bundle was never *wrong* — it was rejected,
and the app fell back to the copy in its binary and quietly stopped updating.
Correct, and invisible: a correction could take Cloudflare's four hours to
reach a phone that already had the old bytes, with nothing on either end
saying so. A name that cannot be stale removes the situation rather than
handling it.

**So the cache policy inverts.** `/data/` now serves
`max-age=31536000, immutable`, and only `manifest.json` revalidates — it is
the entry point, its name is fixed, and it is the file that has to be re-read
to learn the others. The deploy check fails if the manifest comes back
cacheable or a bundle comes back without `immutable`, because both failures
look like a working deploy.

**Names are swept, not accumulated.** A content-named file is never
overwritten, so the previous build's copies are still in the output directory
— and that directory is the app's own asset folder. `bin/bundle.dart` deletes
what the new manifest does not name, scoped by extension and directory, since
a sweep that took anything it did not recognise would be one wrong `--out`
away from deleting the wrong tree. The same applies on the phone:
`BundleCache.prune` drops cached files the live manifest no longer names, and
only against a manifest that came from the network — falling back to the
shipped one because the network was down is not evidence that a downloaded
update is superseded.

**The layouts now have a source directory.** The renderer writes
`dist/layout-source`; the builder publishes hashed copies into
`dist/layout-images`. Publishing into the directory it read from would hash
the hashed names on the next run.

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

- [x] Who authors the initial stratagem pack, and how is it distributed given §0's copyright posture? **Answered by §3.12** — nobody authors it; two existing sources carry it.
- [x] Is there an existing community stratagem dataset with usable licensing? **Yes, two** (§3.12). The parenthetical here previously said Wahapedia's terms forbid scraping; that was written from memory and is wrong. Its `robots.txt` disallows two admin paths and nothing else, and it publishes a bulk CSV export intended for reuse.
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
- **The icons are in the catalog, and an archive can still ship without them.**
  An upload on 2026-08-23 failed with four "Missing required icon file" errors
  for 120, 152, 167 and the 1024 marketing icon. All four are in
  `AppIcon.appiconset`, all are opaque RGB with no alpha, all three Runner
  build configurations set `ASSETCATALOG_COMPILER_APPICON_NAME`, and a release
  build made from the same tree compiles every one of them into `Assets.car` —
  verified with `assetutil`, not assumed. So the failure was in the archive
  rather than the source, which a stale `DerivedData` will do.
  `store/verify-icons.sh` reads the built bundle before an upload, because the
  catalog being right is not the question Apple asks.
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

> **Superseded by §4.5.** The option records are still neither complete nor uniform, and waiting for them was the wrong test — half of datasheets publish none at all, and that will not change. What the records *do* contain is a mix of closed statements and bare numbers, and sorting them by which is which gives fixed kit, enumerated choices and advisory caps without any of it refusing a tap. The roster model was indeed unchanged, as predicted.

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

**Two corrections, both from looking at the drawn table.** The first version rendered area footprints only, and skipped every piece flagged `is_objective`:

- **The objectives are buildings.** Skipping them dropped 6 of 16 pieces on the first table looked at, leaving bare circles floating where the ruins should be. The test agreed with the bug, because it skipped objective pieces too — mirroring the renderer's own `continue` rather than checking the data.
- **The ruins live a level below the footprint.** `features` on a template holds the actual walls; the footprint alone is the area terrain zone. And a `feature` rectangle is centred on its origin, which is what stopped the buildings intersecting each other — found by measuring intersecting pairs across all 46 layouts under each convention rather than by eye.

**A third correction: the bases were not under the buildings.** With the walls right, the area footprints still sat rotated and offset around the objectives, because the two levels are authored in different frames (above). What settled it was measuring against the walls rather than arguing from the file: only **20%** of wall vertices fell inside their own base, and the bases reached **3.6″ past every board edge** while the walls stayed within 3.5″–56.5″ on a 60″ board. Recentring the footprint gives 84% containment and an area extent of 2.9″–57.1″ — the same table the walls describe. Two tests hold it there, one on containment and one comparing the two extents.

> **A caution this earned.** Board-centredness looked like evidence and was not: both conventions put the layout's midpoint at exactly (30, 22), because these layouts are 180°-symmetric and a per-piece offset preserves that. The corner-anchored bases were simply inflated outward on all sides. Symmetry could not tell the two apart; only the walls could.

352 core tests, 96 app tests; both analyzers clean. Verified on the simulator: *Take vs Take 01* draws 16 pieces and 6 objectives on Tipping Point with the walls forming L-shapes and the whole table 180° rotationally symmetric, which is the shape a competitive layout is supposed to have; switching to variant 2 moves it to Dawn of War with the pieces rotated.

**Next:** QR (§6.4), which also unlocks the opponent page, and reporting upstream: the stale Adeptus Astartes points, the local corrections, and the four factions' dangling `detachment_id` references (§3.9).

### 3.10 Source decision, revisited — BattleScribe primary

**Superseding §3.0.** The user asked for the real BattleScribe files rather
than 40kdc's scrape, with 40kdc retained wherever BSData has nothing, BSData
winning every conflict, and every conflict written down.

Two constraints this collides with, both raised before any code was written
and both **decided by the user, against the recommendation**:

- **§3.0's licensing premise is gone.** `BSData/wh40k-11e` has no licence file
  of any kind — LICENSE, LICENSE.md, .txt and COPYING all 404, and GitHub
  reports none. 40kdc was chosen *because* CC BY 4.0 made vendoring and
  shipping lawful. The user chose to vendor and ship anyway. In practice this
  lands in the same place 40kdc already sits: `tools/fetch-bsdata.sh` pulls a
  pinned revision into a gitignored `data/bsdata/`, and what ships is the
  derived bundle, not the catalogue.
- **§0 and §7.6's ban on GW rules text is lifted.** BSData carries the printed
  wording verbatim — Shadowsun's Agile Combatant reads "This model is eligible
  to shoot in a turn in which it Fell Back." The user chose to keep it.
  `SourceAbility.description` is where it lands, beside rather than instead of
  the structured effect, so the renderer (§7.3.6) still works on abilities that
  have structure and prose is a second source of explanation rather than a
  replacement. The upside is real: it closes the "abilities with no
  description" complaint outright, with 232 T'au ability texts against a
  handful of hand-written corrections.

**Why BSData is worth it.** It is more complete and more current. 66 T'au
datasheets against 47, 9 detachments against 7, 555 datasheets across the
project that 40kdc does not have at all. It also settles §3.5's open finding:
the Repulsor Executioner is 255/275 and the Vanguard Veterans 105/210 in both
BSData and the Munitorum, and 40kdc is stale in exactly the direction the
cross-check predicted.

**What BSData does not have, and 40kdc keeps.** Missions, mission matchups,
secondary cards, deployment patterns, terrain layouts and templates, force
dispositions, stratagems, phase mappings, leader attachments, wargear options,
and the entire enrichment layer of structured ability effects. None of it is
in a list-building catalogue. Every play surface in §7 still runs on 40kdc,
and `tools/merge` copies those files through untouched.

#### The shape of the pipeline

    data/bsdata  ──┐
                   ├─> bin/merge.dart ─> data/merged ─> bin/bundle.dart
    data/40kdc   ──┘         │
                             └────────> data-conflicts.json

`data/merged` is a 40kdc-shaped tree, which is the point: the bundler, the
snapshot writer, the coverage report and the loader all read it unchanged.
That is also why the mapper emits **raw JSON records rather than typed
models** — every one of those consumers works on the records the loader read,
never on the DTOs, so JSON keeps the merge a field-by-field diff of two things
that already speak the same language.

#### Ids, and why saved rosters survive

BattleScribe ids are opaque (`4d0d-af9d-53c2-bc31`) and nothing else in this
project speaks them. Records are keyed by **slugified name** instead, which
puts them in the same id space as 40kdc, corrections, the reference fixture
and every roster a player has already saved. Measured on T'au: 43 of 47 40kdc
datasheets are hit exactly, and the four misses are Combat Patrol formations
BSData does not carry.

#### One weapon name is not one weapon

BSData holds **four separate `Missile pod` entries** — BS 3+, 4+ and two at
5+ — one per datasheet that fields one. 40kdc collapses them into a single
BS4+ record, so the app has been showing one number for three guns, which is
precisely the distinction §7.3.5 says must survive.

They are kept apart, which means their ids must differ. The variant matching
**what 40kdc published under that name** keeps the plain id, so saved rosters
and corrections go on resolving; the rest are suffixed with the skill that
distinguishes them (`missile-pod-bs5`). Ties break on the id, never on walk
order — otherwise a rebuild would silently renumber every weapon in a faction.

#### What the first run found, which was mostly our own bugs

The same lesson §3.5 recorded, at the same ratio. T'au opened at **106
conflicts and closed at 23**, and every one of the 83 that disappeared was a
reading error here rather than a disagreement between the sources:

- Group constraints bound the **group**, not each entry in it — Stealth
  Battlesuits counted as nine models instead of five.
- The datasheet root carries the statline **and** its models are in groups
  below, so counting the root added a phantom model to every squad and Vespid
  Stingwings lost its five-model price bracket entirely.
- Silence and `max 2` are different: a group stating nothing is one model, a
  group stating only a maximum starts at zero. Conflating them cost Broadsides
  their 75-point row.
- `type: model` is how BattleScribe marks a model. Testing for a `Unit`
  profile instead misses most of them, because the statline sits on the root.
- Characteristics are printed, not stored: `24"`, `2+`, `N/A`. Compared raw,
  every weapon in the game reported a conflict about its own punctuation — and
  the genuine ones underneath were invisible.
- Model-count price brackets are `set N when at least M models`, where the
  condition names either the literal `model` or **the id of the composition
  group**. Reading only the first form left every Space Marine squad at its
  five-model price.
- An absence is not a disagreement. Seven units produced no points at all, and
  without "empty never wins" the merge would have shipped them free.

**Points now agree on 1,632 of 1,648 datasheets.** The 16 that do not are
recorded in `data-conflicts.json` with both values, and BSData's ships.

#### Detachments and enhancements — measured, then mostly left alone

The obvious next step after datasheets was to take detachments and
enhancements from BSData too. Measuring first said not to, and the measurement
is the useful part:

| | in both | only BSData | only 40kdc | **disagree** |
| --- | --- | --- | --- | --- |
| Detachments | 174 | 62 | 281 | **0 on DP** |
| Enhancements | 627 | 607 | 933 | **0 on cost** |

**Not one disagreement on points.** Whatever this migration was going to be
worth here, it was never going to be accuracy — the two lineages agree exactly
on every detachment's Detachment Points and every enhancement's cost.

So the question is coverage, and coverage has a catch. BSData expresses an
enhancement's keyword restrictions as **modifier condition groups** — the
general modifier-evaluation problem this migration deliberately does not
solve — so its 607 extra enhancements would arrive with no restrictions at
all. §4's eligibility filter would then offer each of them to every Character
in the army. An enhancement the builder offers illegally is worse than one it
does not offer, so the records stay 40kdc's.

**What BSData does add here is the wording.** A detachment rule and an
enhancement are the two things most often looked up mid-game, and 40kdc
publishes text for neither — the app could show an enhancement's name and its
cost and nothing about what it does. Those rules live in shared groups rather
than on any datasheet, so the datasheet walk never reached them; a separate
harvest reads them, and a pass after the merge gives each enhancement the id
of the ability holding its text. **535 enhancements across 35 factions gained
their printed rule**, and every detachment rule did.

The harvest is deliberately not the datasheet walk. That one skips anything
named "enhancement" — it is not a datasheet's own rule — and reads `profiles`
but not `rules`, which is where a detachment keeps its. Both exclusions are
right for datasheets and wrong here, and loosening them would have quietly
put every faction's enhancement list back onto every Character.

### 3.14 When a source has no data for something — the order to try

**Default behaviour, decided 2026-08-24.** When the primary source ships a
field empty, the app does not invent one and does not leave the gap:

1. **40kdc-data** — the primary. Structured, licensed, and the thing the app
   runs on.
2. **BSData** — the same catalogues the datasheet and ability text already
   come from (§3.10). Its rules carry descriptions in the `**bold**`
   convention `ruleSpans` renders, so what arrives needs no rewriting.
3. **Wahapedia's published export** — where BSData has nothing, on the terms
   §3.12 already established.
4. **Nothing.** If none of the three publishes it, the app says so or shows no
   affordance at all. It never writes the rule itself: text composed from
   memory is a rule reproduced from memory, which is the line §0 draws, and it
   is also the failure mode that put a wrong `Fervent Purgation` in front of a
   player.

**The gap this was decided on.** All 34 weapon keywords ship from 40kdc with
`effect: null` — `[TORRENT]` had a name, its parameters, and nothing that said
what it does, so the chips on the weapon table were unreadable labels. BSData
has the wording for **33 of the 34**, already marked up. The one it misses,
`Impaled`, is carried by **no weapon in any faction**, so nothing visible
depends on it and Wahapedia was not needed.

`_applyKeywordText` in `merge.dart` scans BSData for named rules with a
description and matches on the keyword's name. Longest wins where two files
differ, on §3.12's reasoning: a truncated stub is the failure mode, not a
competing wording.

**The second gap, and step 4 reached for real.** 116 of 2,246 stratagems ship
with a name, a cost, a timing and no wording. All three sources were tried and
none has them: 40kdc publishes them as structure, BSData carries the
detachment but not its cards, and Wahapedia has no row — four names match and
none of the four has a description. **Every one of the 116 is on a
`pre-launch-provisional` detachment**, which is the whole explanation: they are
new 11th-edition detachments nobody has published the cards for yet.

So step 4 applies, and the app **says so on the card** — `No rules text
published for this one yet. Read it off the printed card.` — instead of
drawing a name over a blank, which a reader cannot tell apart from a stratagem
that is genuinely one line long. `shipped_bundle_test` pins that the textless
set is provisional-only, so the note can never appear on a stratagem somebody
has published.

**In the app, a keyword with text is tappable and looks it; one without stays
an outline and takes no tap.** A chip that opens an empty sheet is worse than a
chip that never invited the tap — the affordance is the honest signal of
whether anything is known.

Superseded, 2026-08-24: `reference_index.dart` said the app deliberately
carries no core-rules crib, because `weapon-keywords.json` gives names only and
writing the summaries would mean reproducing rules from memory. The premise
was right and the conclusion no longer follows — the text is published by a
source already shipped from, so nothing is written from memory.

### 3.11 Mission card text — gdmissions.app

40kdc publishes each mission card's **structure** — trigger, VP, condition —
and a hand-written paraphrase beside it. The structure is what the scoring
controls run on and it is right; the paraphrase is a summary, and a summary is
the wrong thing to read when you are checking whether you scored:

> *"Central-objective control pays at the end of every one of your turns."*
> vs **"3 VP: You control one or more central objectives."**

`gdmissions.app` publishes the sentences. The user asked for them; the
decision and its costs are recorded here rather than only in a conversation.

**The data checks out.** Three cards were compared field by field against what
the app already shipped, chosen for different shapes — Immovable Object
(central objectives), Purge and Secure (an `or` pair), Death Trap (per-terrain
scoring plus an objective action). **All three agree exactly**, triggers, VP
values, conditions and the action. That is a useful independent confirmation
that 40kdc's mission data is correct, in the same role the Munitorum plays for
points (§3.5).

**What is taken, and what is not.** Only the sentence. Every award, trigger,
round cap and scoring control still runs on 40kdc's structure — nothing that
*does* anything changed. `tools/fetch-gdm.py` reads the structured card object
out of each page's server payload rather than scraping rendered HTML, and the
merge composes the lines from it, following the source's own rule for the VP
label: a leading `+` when a tier is cumulative, `each` when it pays per
object, and the cap where there is one. Getting that wrong turns "+2 VP each"
into "2 VP", which is a different card.

The two markup conventions are normalised on the way in — primaries mark
keywords `**like this**`, secondaries use `<b>` — so both arrive in the one
form `ruleSpans` renders (§3.10).

#### The costs, stated

The site publishes **no licence, no terms, no copyright notice and no
attribution**; `/about`, `/terms`, `/privacy` and `/legal` are all 404. It
offers no API, no JSON and no repository, so this is a fetch of an
application's own payload rather than a data source consumed as intended —
weaker footing than BSData, which at least publishes files meant for reuse.
The wording is GW's card text, which §3.10 already decided to ship.

43 cards: 25 primary and 18 secondary, complete. The end-phase note no longer
claims the descriptions are community summaries, because they are not any
more.

#### The printed rule is the one on screen

The renderer (§7.3.6) exists because 40kdc publishes structure and no wording:
it says what an effect *means* in English so a screen has something to show.
Where BSData supplies the rule as printed, that sentence is the one in the
player's codex, and no paraphrase of ours improves on it:

| Rendered from structure | As printed |
| --- | --- |
| `+1 Wound.` | Add 1 to the bearer's Wounds characteristic. |
| `Shooting phase: grants a shoot while hidden.` | In your Shooting phase, when a friendly PATHFINDER TEAM unit… |
| `Gain 1 Miracle dice.` | Once per battle, after this unit has performed an Act of Faith, you gain 1 Miracle dice. |

**The structure does not go away, it stops being the display.**
`RenderedRule.derived` still carries the sentence built from the effect, and
everything that reads an effect rather than a sentence is untouched: phase
tags, the invulnerable save on the statline, scout distance, and §3.6's
corrections. A correction fixes what the app **does**; the printed text fixes
what it **says**, and the two are now tested separately — the display through
`text`, the derivation through `derived`.

One consequence worth stating: a rule BSData printed is never a bare keyword
(§7.3.11), whatever its structure says. Deep Strike used to compress to a chip
because 40kdc encodes it as a grant of itself and there was nothing to render.
There is now.

**Markup is rendered, not printed.** Emphasis survives into the shipped data
because which words are keywords is information, and every rule-bearing
surface expands it into spans. The normaliser originally handled small caps
*inside* bold and not the reverse, which left a stray marker mid-sentence —
"If your Army Faction is Adepta Sororitas**, each unit…" — so the test now
guards unbalanced emphasis rather than only the markers themselves. It was the
leftover half that reached the screen.

**Saved rosters keep the wording they were built with.** A snapshot is frozen
by design (§2.2), so an army saved before this shows the old derived sentences
until its units are re-added. That is the same property that let a roster
built against 40kdc survive the source swap at all.


### 3.15 Corrections ship as data, not as builds

**The problem this exists for.** 40kdc publishes 11th-edition records ahead of
the printed rules, marked `pre-launch-provisional`. On 26 August 2026 Games
Workshop published nineteen Faction Packs, and those provisional records
turned out to be wrong in *both* directions: missing the wording, and listing
stratagems the released detachments do not have. Experimental Prototype Cadre
carried six in the app and has one in the pack. Waiting for the upstream
source to catch up leaves the app confidently wrong about somebody's army;
editing `data/40kdc` in place makes the next `tools/fetch-40kdc.sh` silently
undo the fix.

And this will keep happening — the packs are revised often, and each revision
lands before any community source has caught up. So the fix is a channel, not
an edit.

**A patch is a list of operations over the source records**, applied where the
raw JSON is read and before any model class has seen it
(`DatasetRepository.faction`). Three operations cover everything:

| | |
|---|---|
| `set` | merge these fields into the record with this id |
| `remove` | drop the record with this id |
| `add` | append this record, replacing one already carrying that id |

**Removal is an instruction, never an omission.** A stratagem the released
detachment does not have has to be *said* to be gone: a patch is a diff over
data the app already holds, and a record's absence from the patch means the
patch has nothing to say about it.

**Patching raw maps rather than parsed models is what lets a patch outlive the
build reading it.** A field this version knows nothing about survives the
round trip untouched and is picked up the moment a later version's `fromJson`
looks for it. The alternative — patching typed objects — would have made every
new field an app release.

**They travel through the manifest.** `dist/patch-<id>.json.gz` alongside the
bundles, listed in a `patches:` array of its own. Deliberately not another
`BundleKind`: `BundleEntry.fromJson` falls back to `faction` on an unknown
kind, so an older build meeting `kind: patch` inside `bundles` would try to
load a patch as an army. An unknown top-level key it simply ignores — old app,
new manifest, no patches, nothing broken. The schema stays at 1 for the same
reason: bumping it would make `isFuture` refuse the whole manifest.

Fetching, hashing and caching are the bundles' own path, which is why
`BundleSource.fetch` now takes a file name rather than a `BundleEntry`. A
patch that cannot be fetched is skipped rather than fatal: the bundles are the
data, a patch corrects them, and a correction that did not arrive should leave
the app where it was rather than unable to start.

**Every patch names the dataslate it corrects, because it is meant to be
deleted.** When 40kdc republishes against the released rules, `appliesTo` no
longer matches, and the file and its manifest row go in one commit.

**Pipeline.** `tools/fetch-faction-packs.py` downloads each pack and caches
its **raw extraction** — words and coordinates, not columns, because where the
columns are is a judgement the detector makes and it has been corrected twice;
caching the judgement would mean re-downloading a quarter of a gigabyte to fix
it a third time. `tools/parse-rules-updates.py` reads the errata sections;
`tools/check-faction-packs.py` is the gate described below and should be read
before the next step; `tools/make-update.py` diffs both against the built
bundles and writes `data/updates/<date>.json`; `bin/bundle.dart` gzips every
file in `data/updates/` into the dist and lists it.

The August file is **1,731 operations in 78 KB** — 594 wordings and 29
removals from the detachment pages, 78 stratagems a chapter's copy of a shared
detachment was missing, 195 errata from the Rules Updates sections, 169 from
the Munitorum Field Manual (53 units repriced, 110 leader lists, 6 enhancement
costs), 450 from the datasheets (§3.16), 104 FAQs (96 faction, 8 for the mission deck), and 112 base sizes (§3.17).

**The Rules Updates sections, added in the same pass.** Every pack ends with
errata to rules the codex already published, in a regular shape — a shouted
category, a subject, `Change to:`, and the new wording quoted. 358 of them
were read out; **132 became operations.**

The mapping is more uniform than it looks: enhancements and detachments carry
no wording of their own, theirs lives in the `abilities` file reached by
`ability_id` and `detachment_rule_id`, so almost every correction sets one
ability's `description`. That is why a patch operation now names the field its
id is matched against — `abilities` keys on `ability_id`, and a table of
per-file exceptions in the code would not have the next file in it.

**Two further passes took it to 182**, by handling the shapes the first
refused:

- **One named section of a rule.** `Photon Grenades Stratagem, When Section`
  names a stratagem and a part of it. The app holds a stratagem as one string
  with `**WHEN:**`-style headings in it, so the named part is replaced inside
  it and the rest left alone. The packs separate the section with a comma in
  some and an en dash in others, and write `Target and Effect Sections` when
  one correction replaces two.
- **One measurement swapped for another.** `Change 9" to 8".` This is the one
  place the tool rewrites rules text by pattern, and it is bounded: Games
  Workshop name both the old value and the new, and the substitution is
  refused unless the old appears **exactly once** in the record. Twice means
  the correction is ambiguous and the app keeps what it has — 22 were refused
  on that test.
- **Keywords and core abilities.** `Add 'FRAME'.` and `Remove 'Leader', add
  'Support'.` edit lists, not prose, and are applied as lists across every
  datasheet the subject names.

**Two faults were found by checking rather than by it failing.** Ten
replacements flattened a stratagem into one unheaded blob, because the packs
print the sections as running text — `WHEN: ... TARGET: ...` — where the app
holds them as `**WHEN:**` paragraphs; they are normalised now, and a test
pins that a rewritten stratagem keeps its headings. And one replacement had
the *next* entry's heading welded to its end. The segmentation was tightened
twice and the last one is dropped rather than shipped: wording a version out
of date beats wording with somebody else's heading on it.

A fourth shape came out of reading the refusals rather than the packs: a
subject that is **nothing but a section name** — `Taking Cover Section` —
belongs to the rule the heading above it names, and identifies a shouted
block inside that rule's description.

**Three of the refusals were the tool, not the data**, and each was found by
reading the refused list rather than by anything failing:

- **22 measurements were already correct.** `Change 9" to 8".` was refused
  because the distance was not in the record — because the app already read
  8". Its wording comes from Wahapedia, which had made that change. A
  correction with nothing left to correct is satisfied, not refused, and is
  counted that way now.
- **The measurement is counted inside the named section**, not across the
  whole rule. `Tricksters' Retort Stratagem, Target Section` means the Target
  section; counting across the rule found the distance twice or not at all.
- **`Change to:` is the instruction whether or not the quotation starts on
  the same line**, and some packs drop the colon. The verb decides, not the
  punctuation.

**And one guard was added after it truncated a rule.** The body is cut at a
closing quote only where what follows is plainly the next entry — a heading,
or nothing. The closer and the apostrophe are the same character, so cutting
at the last one shortened `The first time this unit’s FABIUS BILE model is
destroyed…` to four words. Any replacement that still comes out under 25
characters is refused rather than shipped.

**A last pass took it to 195**, by handling the things that are not prose at
all and by loosening four lookups that were stricter than the packs:

- **Characteristics.** `Change M and OC to '-'.` and `Change OC
  characteristic to '10'.` edit a datasheet's profile; `Change AP
  characteristic to '-2'.` under `Melee Weapons, Demiklaives` edits a
  weapon's. The word `Weapons` in the subject is what separates the two, and
  the weapon is whatever follows it.
- **A detachment rule is often named outright** — `Masters of Manoeuvre
  Detachment Rule` — rather than left to the heading, and one heading can
  carry several rules.
- **`Through Unity, Devastation Enhancement` is one name with a comma in
  it**, not an owner and a name.
- **A heading that names no detachment is not fatal** when the name is unique
  in the faction anyway.
- **`Add the 'FRAME' keyword.`** is the same instruction as `Add 'FRAME'.`

**The 124 left have nowhere to land, and that was checked rather than
assumed.** 23 are corrections the app already satisfies. The rest name things
the app does not hold as records at all: a **Transport section** is capacity,
not text — the Falcon has five abilities and none of them is its transport
rule — and the same is true of `Leader`, `Damaged`, `Options`, `Orders` and
`Contagion Range`. The remainder are fragments the parser could not read.
Each is named in `data/faction-pack-updates-unapplied.json`, which the
generator writes so the next pass starts from the list rather than a counter.
All 358 stay in `data/faction-pack-updates.json`.

**And then it is checked from the other end.** `patch_applied_test` reads the
shipped patch, loads every faction the way the app does, and asserts each
operation against the result: a `set` is present, a `remove` is gone, an
`add` is there. The generator reports what it *wrote*, which is a different
question — an operation can name a record the bundle does not carry or key on
the wrong field, and both fail silently, because a patch that matches nothing
looks exactly like a patch with nothing to do. The test was confirmed to fail
twice over — once by pointing an operation at a record that does not exist
and giving another a value the record does not have, and again after it grew
to cover weapon and datasheet profiles, by adding a profile the bundle does
not have. It caught every one — and, once the Field Manual's operations arrived, caught
a dozen chapters writing conflicting points onto the same shared datasheet,
which is what the deduplication above exists for. **1,731 of 1,731 land.**

Segmentation is by **looking ahead to the directives**, not by streaming
state. Streaming could not tell where a quotation ended, because an apostrophe
and a closing quote are the same character — `your opponent's` looks exactly
like the end of a quote — and every entry after the first inherited the
subject of the one before it. The directives are unambiguous, so they are
found first and subject, category and body are placed relative to them.

**Bullets are rewritten to the app's convention.** The packs bullet with `▪`;
123 of the T'au abilities already bullet with `-` and none use `▪`, so leaving
it would render one corrected rule unlike every rule beside it.

**The Universal Rules Updates are recorded and not applied.** Five changes,
and three of them — how a 0CP rule interacts with a stratagem's cost, when a
"more than once per phase" allowance may be used, which move type a
disembarking unit makes — are rules about how rules combine. They have no
record to edit. Of the two that touch data, the 12" → 18" change **matches no
stratagem the app carries**, and the "adds a new unit to your army" change
matches six only by paraphrase: the app's wording comes from Wahapedia and
40kdc, not from Games Workshop's sentence, so deciding which six are covered
is a judgement about the rules rather than a transcription of them. Left for a
pass that can check them against the printed stratagems.

**The Event Companions: layouts, and a rule the app already follows.** The
Warhammer Event Companion publishes the **official 45 terrain layouts** — 15
mission matchups × three, labelled A, B and C — and its version 1.2 lists **27
of them as changed on 26 August 2026**. The app's own 45 are Battlemaster's
import, marked `pre-launch-provisional`, over exactly the same 15 matchups ×
three variants. So the structures agree and the geometry may not.

The geometry is **printed as a diagram, not as text**, so it is not extracted
here: reading rectangles out of the vector art and calling them a battlefield
is the kind of parse that produces a plausible wrong map, which is worse for
this app than no map. What is extracted is the index —
`data/event-companion-layouts.json` — so the app can say how current its own
layouts are, and so a later pass starts from the list rather than the PDF.

Until the geometry is read, **the layout picker says so**: the chips already
name the source (`Battlemaster 2`), and a line under them now says 27 of the
official 45 changed on that date and to check the pack before an event. Said
once, where the layout is chosen, rather than under every drawing of it.

The Companion also caps command points: *excluding Core CP, each player can
gain a maximum of 1CP per battle round, including the CP from discarding an
active Secondary Mission card.* Checked against the app rather than assumed —
§7.3.18 already allows one discard-for-CP per battle round and §7.3.21's
per-turn point is Core CP, so nothing needed changing.

**Has Wahapedia caught up? No, and it was checked rather than assumed.**
Re-fetched on 2026-08-27: the live export is **byte-identical** to the
snapshot committed on 19 August, a week before the packs landed. Nothing has
been published since.

It looks current at a glance, because it tracks previews — it already carries
text for **425 of the 430** stratagems the packs publish. Three measurements
say otherwise:

- It has text for **none of the app's 116 textless stratagems**. Those are not
  a gap in the fallback chain; they are mostly records that do not exist.
- **27 of the 29 stratagems this patch removes are absent from Wahapedia
  too** — an independent source agreeing they are not real. The other two,
  `Long, Uncontrolled Bursts` and `Speshul Shells`, are duplicate records: the
  app files each under both More Dakka! and Rollin' Deff, the pack lists them
  under More Dakka! only, and the patch removes the Rollin' Deff copy. Checked
  by id rather than by name, which is what a name-only cross-check missed.
- On wording it agrees with the packs on 412 of 425 — 252 exactly, 160 down
  to whitespace — and **differs substantively on 13**, where its text is the
  older one. `BURST OF SPEED` moved from the end of the Shooting phase to the
  end of the Movement phase and changed its target; `RAPID EMBARKATION` now
  targets an Infantry unit rather than a Transport; `GUIDED RETREAT`,
  `MEKANISED BRUTALITY`, `APOPLECTIC CLARITY`, `SOULSIGHT`, `FIRING HOT`,
  `ADDITIONAL ARMOUR`, `UNNATURAL AGGRESSION`, `FIRE SHOCKED`, `THE FOE
  FORESEEN`, `DRONING HORROR` and `ASPIRE TO INFAMY` differ in a clause each.

So the fallback chain has not closed and the patch is not redundant. When
Wahapedia does republish, those 13 `set` operations become harmless
duplicates of what the source says — the condition for deleting the patch
stays what §3.15 already says it is, the upstream **dataslate**, not this.

**Points, and who can lead whom, from the Munitorum Field Manual.**

⚠ **Superseded, and it was wrong.** An earlier pass here recorded that the MFM
"serves its detachments in the page and does not serve its units", that the
unit names sit behind a Suspense boundary that never resolves server-side,
and that BSData's mirror had gone stale because the page changed under their
scraper. **The units were there the whole time.** The mistake was mine and it
was mechanical: the page is a single line of HTML, so `grep -c` counts *one*
and reads like one match where there are eighty-two. Everything built on that
count was wrong, including the conclusion that the licensed mirror must be
broken. The kept record is the point: a measurement taken with the wrong tool
reads exactly like a finding.

The pages **are** server-rendered, and streamed out of order. React sends the
skeleton with `<template id="P:7a"></template>` where each name and cost goes,
then the content in `<div hidden id="S:7a">…</div>`, with a
`<script>$RS("S:7a","P:7a")</script>` that splices the two in the browser.
`tools/fetch-mfm-points.py` does that splice before parsing anything, and the
whole document is then in reading order.

Three things come out of it that the app holds and no community source
currently has:

- **What a unit costs at each size.** Read as blocks, not as one list. `YOUR
  UNIT COSTS` is flat; `YOUR 1ST TO 2ND UNITS COST` and `YOUR 3RD + UNIT
  COSTS` price the same unit by how many you have already taken, and the app
  stores those as separate entries for one model count; `WARGEAR OPTIONS` on
  the same card is per item and is not a unit price at all. Flattening the
  three put a meltagun's 5 points in with a squad's and reported 485
  differences where there were 146.
- **Enhancement costs**, per detachment.
- **Who can lead whom.** Each character's card carries a `LEADER` block naming
  the datasheets it may attach to — the app's `leader-attachments`, and
  nothing else publishes it in one place. Vespid Stingwings gained one in this
  update and the app had nothing at all for it.

**One operation per record.** A Space Marine chapter's MFM page lists its
parent's datasheets, so a shared record is described by a dozen pages. The
first page to describe it wins and a page that disagrees is counted, not
allowed to overwrite — 13 disagreed, and without that the verification test
caught the last writer clobbering the others.

**Parsing the packs.** Two things about the PDFs decide the parser.**Parsing the packs.** Two things about the PDFs decide the parser. Their grid
changes page to page — a new detachment gets two wide columns, a reprinted
codex one gets a narrower three-column layout on a different page size — so
columns are *detected* rather than assumed: a gutter is a vertical band that
almost no line of text crosses, where a line covers its words and only the
gaps narrow enough to be word spacing. Requiring a *clear* gutter found no
columns at all, because a page title runs the full width above the body; a
fixed split at half the width silently dropped every reprinted detachment.

And a stratagem names itself the same way whatever the grid — its name, then
`<DETACHMENT> STRATAGEM` under it — so the detachment is read off that line
and never inferred from the page header. The cost is set beside the block
rather than on the name's line, a couple of points above it in one layout and
forty to seventy-five below it in the other, so it is matched by column and
then by the nearest name at or above it.

Only the `WHEN`/`TARGET`/`EFFECT`/`RESTRICTIONS` block is taken. The fluff
paragraph above it says nothing about how the stratagem works.

**What was checked before trusting it.** All 430 parsed stratagems have a cost
and an effect block, none is duplicated, and every detachment on every pack's
contents page is accounted for. Two came out with no stratagems at all —
Sanctified Orators and Librarius Conclave — and both were confirmed by
rendering the page and looking at it, because "parsed to nothing" and "has
none" are indistinguishable in the output and the difference decides whether
the app deletes stratagems out of somebody's army. No `add` invents a record:
all 78 exist in another faction's copy of the same detachment, so phase,
timing and whose-turn come from that sibling and only the id, wording and cost
come from the pack.

### 3.16 Datasheets, Legends and the FAQs

The packs' largest sections are datasheets, and they are the reason the app
could not apply a third of the errata: a correction to a `Transport` or
`Leader` section has nowhere to land when the datasheet itself was never read.
**293 datasheets and 1,542 weapon profiles** now are.

**The stat tables are what make it tractable.** Each column of the table is a
column on the page and each is *labelled* — `RANGE`, `A`, `BS`, `S`, `AP`,
`D` — on the same baseline as the `RANGED WEAPONS` header, so the columns are
read off their own headers rather than measured, and a weapon is whatever
sits on one baseline across them. A name that wraps has no stats beside it,
which is how the wrap is told from a new weapon. On a narrow table the gutters
between the stat columns are too small to detect and the header arrives as
`RANGE A WS` in one cell; the header still names the columns in order, so the
values are matched to it by position instead.

**Three sections share the layout** — `Datasheets`, `Imperial Armour
Datasheets` and `Legends Datasheets` — and all three are read. Which one a
datasheet came from is kept: Legends arrives with `is_legend` so the builder
keeps hiding it behind the existing setting, and Imperial Armour is marked as
Forge World's so a reader can see which book it came from.

**A Legends flag is only ever set on a datasheet the patch adds.** A pack's
Legends section carries names that collide with current ones — Captain,
Warboss, Librarian, Chaos Lord, Apothecary — and matching by name would have
marked **23 core datasheets as Legends** and hidden them from the builder. The
verification test caught it; the rule now is that an existing record is never
flagged from a name match, because on a collision the collision is the more
likely explanation.

**What is written back is bounded.** A statline only when it parsed cleanly
and the app's disagrees — `12` and `12"` are the same move, and a field the
app leaves empty counts as a disagreement. A weapon only where the app already
has one by that name and it has a single profile: minting ids for 1,542
profiles is a bigger change than a patch should make, and a unit whose weapons
are half-linked is worse than one the app already draws. **200 of 269
statlines the app already had agreed exactly**, which is what says the parse
can be trusted.

**FAQs are quoted, never applied.** 96 questions across 17 packs. A FAQ says
how two rules interact — *can I use this ability while embarked?* — and the
app has no record that answers for it; deriving one would be the app
adjudicating rather than reporting (§7.6). So they ship as their own `faqs`
file in the faction bundle, added by the patch like everything else, and the
Rules page grows a `FAQ (n)` button that opens them. The count is on the
button because a player wants to know whether opening it is worth it; a
faction whose pack carries none gets **no button at all**, since one that
opens an empty page is worse than none. The foot of the sheet says once that
these answer rules and do not change anything the app shows.

**A skill's plus is notation, and writing it back would have shown `5++`.**
The packs print `5+` where the app stores `5` and adds the plus when it draws.
Comparing the printed strings reported 481 weapon differences where 469 were
that, or an integer against the same integer as text. They are compared as
numbers now — except that `D3+3` attacks and `D6+1` damage are values and keep
their plus, so only `BS` and `WS` are stripped. The last one through came from
the errata handler rather than the datasheet one, so the guard runs over
everything generated instead of inside one phase: a guard that lives in a
single phase only guards that phase.

**The mission deck's own questions belong to the card, not to a list.** The
Warhammer Event Companion carries eight, and its `ERRATA` section — the
amendments to Chapter Approved cards — reads **`None.`** in this version.
That is the finding: there is nothing to apply, and recording it is what
stops the section looking unparsed next time.

Five of the eight name one card — Plunder, Beacon, Death Trap, Surveil the
Foe, Vital Link — so a FAQ carries the id of the card it is about, matched by
name against the deck (longest name wins, or `Vital Link` loses to a card
called `Link`). The card then shows a small `FAQ` beside its name on the score
board, and **nothing at all** when it has none: a control that opens nothing
on most cards is worse than no control. The three general questions carry no
id and appear in the faction list instead. An empty id matches nothing on
either side — matching empty against empty put the general questions on every
unnamed card, which a test now pins.

They are carried in the **core** bundle rather than copied into thirty faction
ones, and every faction reads them alongside its own.

An answer ends at a shouted line. Without that the last answer on a page ran
on into the datasheet printed after it — `No. ORCA DROPSHIP M T SV W 20"…` —
which is the same class of fault as the errata segmentation, and was found
the same way: by looking at the longest output.

### 3.17 The layouts are pictures, and the base sizes are data

**The geometry is not extractable, and that is a finding rather than a
failure.** A layout page's battlefield art is raster — 76 embedded images —
and the only vectors are the deployment zones and the callout rules. The
letter codes and the dimensions *are* text, so a layout's feature inventory
and its measurements can be read; a feature's **rotation appears nowhere**,
and a map drawn without rotations is a plausible wrong map. §3.15's rule about
the packs applies here too: better the app says whose layout it is drawing
than that it invents one.

So the page itself is the reference. Each of the 45 layouts is rendered at
120 dpi, cropped to the diagram and quantised to 256 colours — 11.6 MB for the
set, against a 6.5 MB data bundle for the whole app. They are therefore
**published beside the bundles and not inside the app**, listed in a new
`assets` array in the manifest and fetched on demand, cached and hashed by the
same path as everything else. Until a base URL is configured (§3.4) there is
nothing to fetch, and the sheet says so rather than showing an empty frame.

`assets` is its own array for the same reason `patches` is: an older build
reads an unknown `kind` inside `bundles` as a faction. The schema stays at 1.

**The Base Size Guide is the other half of the Companion, and it is data.**
Forty pages at the back list every datasheet's base. **820 of the 932 the app
already had agree exactly** — which is what says the extraction can be trusted
— and the 112 that do not are the reason to carry it: 95 datasheets had no
base size at all and 17 were wrong. `SourceUnit` now reads the field, which
had been in the bundle since the first build and parsed by nothing.

Two details in that are the app's convention rather than the guide's, and both
would have been silent. **The first number of an oval is its width**: 820
records already read that way, and writing `120 x 92mm` as length-then-width
would have turned every oval base ninety degrees. And a whole number is stored
as an integer, so `40.0` is not written over `40`. Reading the generated
operations is what caught both — 165 "corrections" that were the same value in
a different shape.

### 3.13 The action section — the reverse of the card

Secure Asset's front reads *"4 VP: A friendly unit **secured the asset** this
turn (see reverse)"*, and the reverse was nowhere in the app. Thirteen of the
25 primaries and two secondaries have an action, and every one of them had the
same hole: the card names an action, awards VP for completing it, and never
says what it is.

**No source publishes the printed wording.** 40kdc carries the action as
structure only; gdmissions' card object stops at "(see reverse)", and its page
payload does not contain the text either — checked directly rather than
assumed, by fetching the Secure Asset page and searching the flight stream for
`ACTION`, `Objective Action` and `action`. All absent.

So the section is **composed from 40kdc's structure** at merge time, in the
labelled style the rest of the card already uses:

```
ACTION · Secure Asset: Objective Action
When: your Shooting phase, once per turn.
Completes: on one or more **objectives**, excluding your **home objective**, this turn.
```

**"Objective Action" is applied only where it is confirmed.** The user reported
the gap in exactly those words, and the label is attached when the action's
target is an objective. Booby Trap targets terrain and Condemn targets an enemy
unit; both are left as plain `ACTION · Name` rather than given a label by
analogy, since no source says what a terrain action is called.

**It is deliberately thinner than the printed card, and here is what is
missing.** 40kdc's own prose paraphrase — which §3.11 replaced wholesale, and
which is where this gap came from — knows two things its structure does not:
that most of these complete only *if the unit still controls the objective*,
and that Booby Trap *completes immediately* rather than at end of turn. Neither
is derivable from the structured data, so neither is stated. The composer says
what the data says.

Two readings are borrowed from that prose rather than invented: the
`operation-markers` restriction renders as "cannot be started while only one of
your operation markers remains", which is how 40kdc describes the same shape on
the same two cards, and `clears_on: turn-rollover` renders as "until the start
of your next turn", which is its wording for Punishment's mark.

**The vocabulary is closed and a test pins it.** `starts`, `timing`,
`target_kind`, `effect.type` and `restrictions.type` each have a known set of
values, and `mission_pack_test` asserts those sets exactly. Rendering nothing
for an unrecognised value is what produced this bug in the first place; if
upstream adds one, the test fails rather than the app quietly dropping it.

### 3.12 Stratagem text — Wahapedia and the card-generator repo

A stratagem was a name, a cost and a phase. That is enough to *find* one and
not enough to *use* one: the entire content of the decision — when it can be
used, what it targets, what it does — was the part not shipped. 2,246 of them,
none with text.

**Two sources, and the fuller one wins per stratagem.**

| Source | What it has | Licence posture |
| --- | --- | --- |
| Wahapedia `Stratagems.csv` | all 2,246 rows, faction and core | published bulk export; asks for "Powered by Wahapedia" |
| [warhammer-40k-stratagem-card-generator](https://github.com/pguetschow/warhammer-40k-stratagem-card-generator) | the core stratagems, transcribed | MIT |

Neither is a paraphrase; both are the printed card. Where both have a
stratagem the longer text is kept, which in practice means Wahapedia except
where its row is a truncated stub. **2,055 of 2,246 (91%) carry text**; the
191 without are stratagems absent from both exports, and they still render as
name, cost and phase rather than disappearing.

The earlier note that Wahapedia's terms forbid scraping was **wrong, and was
mine** — I had not checked. `robots.txt` disallows `/wh40k10ed/admin` and
`/login` and nothing else, and the CSV export exists precisely to be consumed.
The attribution it asks for is on the About screen and tested, alongside
40kdc's, and the repo is credited there too.

#### Coverage, and what it cost to get there

**2,130 of 2,246 (95%)**, up from 2,055. Two faults kept the last 191 out, and
neither was a missing source:

- **The name key kept its punctuation.** `_stratagemKey` folded curly
  apostrophes and collapsed other punctuation to spaces, which is not enough
  when the two sources disagree about *where* the apostrophe goes: our
  `FOOL’S FLIGHT` against Wahapedia's `FOOLS’ FLIGHT`, `CUT’ EM DOWN` against
  `CUT’EM DOWN`, `ARMED TO DA TEEF` against their `ARMED TO DATEEF`, and a
  non-breaking hyphen in `THREAT‑COGITATION`. The key is now letters and
  digits only. Checked before loosening it: across the whole export exactly
  one pair of distinct keys collapses together, `COUNTER-OFFENSIVE` and
  `COUNTEROFFENSIVE`, which is one stratagem spelled two ways.
- **The pass never visited half the factions.** The faction list is built from
  `data/bsdata`, and a chapter with no catalogue of its own is written by
  `_copyRemaining` instead. Crimson Fists' **66** stratagems — the largest
  single block — were never looked at. It now iterates the output tree.

The remaining 116 are absent upstream, not unmatched: 112 have no Wahapedia
row at all and 4 have a row Wahapedia left blank. The floor in
`stratagem_book_test` moved from 85% to 92% so the gain cannot quietly rot.

#### Lists are structure, and stripping tags loses the sentence

Wahapedia marks up its text as HTML. The first merge turned `<b>` into `**`,
`<br>` into a newline, and deleted every other tag — which quietly destroyed
the one thing a bulleted rule is made of. COMMAND RE-ROLL came out as:

> `**WHEN:** …one of the following rolls…:` \
> `**Advance roll****Charge roll****Damage roll****Hazard roll**…`

Every word present, the shape gone, in a card read mid-turn under time
pressure. `<ul><li>` now becomes a bullet on its own line, and the `▪` the
repo's transcription uses becomes the same bullet, so the two sources produce
one format. 47 stratagems carry lists; both the merged data and the rendered
widget are tested for it, because "no `<b>` survived" was true of the broken
version too.

#### Reading a stratagem is not playing it

The turn page drew **two STRATAGEMS headings**, one from the collapsible group
and one from the list inside it — able to disagree about the count, since each
computed its own. The list's own heading is gone and the CP it carried moved
into the group's trailing, where it sits beside the count.

**A button plays it; the row reads it.** The whole row used to be the play
action, so opening a card you were only considering spent the CP. Reading one
mid-turn is the common act and playing it the rare one, and the rare one is
the one that changes state and cannot be undone by tapping again. An
unplayable stratagem keeps a disabled `Use` and stays readable — the reason it
is blocked is printed under it, and a reason you cannot check against the card
is not much of a reason.

The text is folded because these are whole cards now rather than one-liners:
COMMAND RE-ROLL alone runs to eight bulleted rolls, and five of those open at
once buries the phase they sit in.

**The text is the display, the structure is not gone.** Same split as §3.10:
`SourceStratagem.text` is what the player reads, and every control — phase
filter, CP cost, once-per-turn, the target picker — still runs on the
structured fields. Nothing that *does* anything reads the sentence.

---

## 7.7 Nothing changes unless the player changed it

**The rule.** The app never alters something the player set, or moves them
somewhere they did not ask to go. Concretely:

- **Every tab stays where it was scrolled.** Switching away and back is not a
  reason to return to the top. The four play tabs are an `IndexedStack` for
  this reason: it keeps each one in the tree rather than rebuilding it.
- **No control changes its own state.** A fold the player opened stays open, a
  fold they closed stays closed, and neither is decided again by anything
  except them.
- **No field is cleared or rewritten** unless an action asks for it. Saving,
  cancelling and deleting are actions; scrolling, switching tabs, a rebuild
  and an incoming event are not.

**The failure that produced it.** A `ListView` builds what is near the screen
and disposes the rest, taking any `State` with it — so a block opened at the
top of the turn page had folded itself shut by the time the player scrolled
back. The app undoing a choice nobody undid, silently, in the middle of a game.

`RemembersToggle` puts the flag in the route's `PageStorageBucket`, which
outlives the element, under an explicit identifier so it survives reordering
too. `state_persistence_test` pins it — including the two directions that
matter equally: an opened block stays open, and a closed one stays closed,
because "remembers" must not quietly mean "opens".

**The one exception, and it proves the rule.** Choosing a play density resets
every unit row, because that is precisely what choosing a density means. It is
an explicit action with that effect.


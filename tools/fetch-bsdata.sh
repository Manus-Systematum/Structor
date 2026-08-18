#!/usr/bin/env bash
# Fetch a pinned snapshot of BSData/wh40k-11e into data/bsdata/.
#
# BattleScribe catalogues, published as JSON rather than .cat XML. Community
# maintained, in no way endorsed by Games Workshop, and carrying **no licence
# file of any kind** — see DESIGN.md §3.10 for the decision to vendor anyway
# and who made it.
#
# https://github.com/BSData/wh40k-11e
#
# Usage:  tools/fetch-bsdata.sh [faction-id ...]
#         tools/fetch-bsdata.sh                  # every faction we map
#
# Files are stored under the faction id this project uses, not the name
# BSData files them under, so the loader never has to know about the mapping.

set -euo pipefail

REF="${BSDATA_REF:-main}"
BASE="https://raw.githubusercontent.com/BSData/wh40k-11e/${REF}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/data/bsdata"

# faction-id<TAB>BSData file name.
#
# A faction may name more than one file: the entries a catalogue links to
# often live in a separate library, and Craftworlds is 106 entry links with no
# entries of its own. Files are listed in load order, library first.
MAP=$(cat <<'EOF'
adepta-sororitas	Imperium - Adepta Sororitas.json
adeptus-astartes	Imperium - Space Marines.json
adeptus-custodes	Imperium - Adeptus Custodes.json
adeptus-mechanicus	Imperium - Adeptus Mechanicus.json
aeldari	Aeldari - Aeldari Library.json
aeldari	Aeldari - Craftworlds.json
agents-of-the-imperium	Imperium - Agents of the Imperium.json
astra-militarum	Imperium - Astra Militarum - Library.json
astra-militarum	Imperium - Astra Militarum.json
black-templars	Imperium - Black Templars.json
blood-angels	Imperium - Blood Angels.json
chaos-daemons	Chaos - Chaos Daemons Library.json
chaos-daemons	Chaos - Chaos Daemons.json
chaos-knights	Chaos - Chaos Knights Library.json
chaos-knights	Chaos - Chaos Knights.json
chaos-space-marines	Chaos - Chaos Space Marines.json
dark-angels	Imperium - Dark Angels.json
death-guard	Chaos - Death Guard.json
deathwatch	Imperium - Deathwatch.json
drukhari	Aeldari - Drukhari.json
emperors-children	Chaos - Emperor's Children.json
genestealer-cults	Genestealer Cults.json
grey-knights	Imperium - Grey Knights.json
imperial-fists	Imperium - Imperial Fists.json
imperial-knights	Imperium - Imperial Knights - Library.json
imperial-knights	Imperium - Imperial Knights.json
iron-hands	Imperium - Iron Hands.json
leagues-of-votann	Leagues of Votann.json
necrons	Necrons.json
orks	Orks.json
raven-guard	Imperium - Raven Guard.json
salamanders	Imperium - Salamanders.json
space-wolves	Imperium - Space Wolves.json
tau-empire	T'au Empire.json
thousand-sons	Chaos - Thousand Sons.json
tyranids	Library - Tyranids.json
tyranids	Tyranids.json
ultramarines	Imperium - Ultramarines.json
white-scars	Imperium - White Scars.json
world-eaters	Chaos - World Eaters.json
EOF
)

# Linked by many catalogues rather than owned by one faction.
SHARED=(
  "Warhammer 40,000.json"
  "Unaligned Forces.json"
)

WANTED=("$@")

fetch() { # remote-name dest
  local url dest
  url="${BASE}/$(printf '%s' "$1" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read()))')"
  dest="$2"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL "$url" -o "$dest"; then
    printf '  ok   %-52s %8s bytes\n' "${dest#"$ROOT/"}" "$(wc -c <"$dest" | tr -d ' ')"
  else
    printf '  MISS %s\n' "$1"
    rm -f "$dest"
    return 1
  fi
}

printf 'Fetching BSData/wh40k-11e @ %s\n\nshared:\n' "$REF"
for f in "${SHARED[@]}"; do
  fetch "$f" "${OUT}/shared/$(printf '%s' "$f" | tr ' ' '_')"
done

current=""
while IFS=$'\t' read -r faction file; do
  [ -n "$faction" ] || continue
  if [ ${#WANTED[@]} -gt 0 ]; then
    match=0
    for w in "${WANTED[@]}"; do [ "$w" = "$faction" ] && match=1; done
    [ $match -eq 1 ] || continue
  fi
  if [ "$faction" != "$current" ]; then printf '\n%s:\n' "$faction"; current="$faction"; fi
  fetch "$file" "${OUT}/${faction}/$(printf '%s' "$file" | tr ' ' '_')"
done <<<"$MAP"

# Records which revision the snapshot came from. Without it a vendored
# snapshot is a pile of JSON nobody can date or reproduce.
rev=$(curl -fsSL "https://api.github.com/repos/BSData/wh40k-11e/commits/${REF}" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["sha"], d["commit"]["committer"]["date"])')
printf '%s\n' "$rev" > "${OUT}/REVISION"
printf '\nDone. Snapshot in %s at %s\n' "${OUT#"$ROOT/"}" "$rev"

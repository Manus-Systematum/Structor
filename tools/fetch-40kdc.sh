#!/usr/bin/env bash
# Fetch a pinned snapshot of 40kdc-data into data/40kdc/.
#
# Data is CC BY 4.0 (c) Alpaca Software and the 40kdc community contributors.
# https://github.com/wn-mitch/40kdc-data
#
# Usage:  tools/fetch-40kdc.sh [faction-id ...]
#         tools/fetch-40kdc.sh                 # defaults to tau-empire

set -euo pipefail

REF="${FORTYKDC_REF:-main}"
BASE="https://raw.githubusercontent.com/wn-mitch/40kdc-data/${REF}/data"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/data/40kdc"

FACTIONS=("$@")
if [ ${#FACTIONS[@]} -eq 0 ]; then FACTIONS=("tau-empire"); fi

# Core files shared across every faction.
CORE_FILES=(
  game-versions.json
  game-modes.json
  force-dispositions.json
  missions.json
  mission-matchups.json
  secondary-cards.json
  deployment-patterns.json
  terrain-layouts.json
  terrain-templates.json
  weapon-keywords.json
  unit-keywords.json
  target-profiles.json
  stratagems.json
)

# Per-faction files under data/core/<faction>/.
FACTION_FILES=(
  factions.json
  units.json
  weapons.json
  wargear.json
  wargear-options.json
  unit-compositions.json
  detachments.json
  enhancements.json
  leader-attachments.json
  stratagems.json
)

# Per-faction files under data/enrichment/<faction>/.
ENRICHMENT_FILES=(
  abilities.json
  phase-mappings.json
)

fetch() { # url dest
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL "$url" -o "$dest"; then
    printf '  ok   %s (%s bytes)\n' "${dest#"$ROOT/"}" "$(wc -c <"$dest" | tr -d ' ')"
  else
    printf '  MISS %s\n' "${url#"$BASE/"}"
    rm -f "$dest"
  fi
}

printf 'Fetching 40kdc-data @ %s\n\ncore:\n' "$REF"
for f in "${CORE_FILES[@]}"; do
  fetch "${BASE}/core/${f}" "${OUT}/core/${f}"
done

for faction in "${FACTIONS[@]}"; do
  printf '\n%s (core):\n' "$faction"
  for f in "${FACTION_FILES[@]}"; do
    fetch "${BASE}/core/${faction}/${f}" "${OUT}/core/${faction}/${f}"
  done
  printf '\n%s (enrichment):\n' "$faction"
  for f in "${ENRICHMENT_FILES[@]}"; do
    fetch "${BASE}/enrichment/${faction}/${f}" "${OUT}/enrichment/${faction}/${f}"
  done
done

printf '\nDone. Snapshot in %s\n' "${OUT#"$ROOT/"}"

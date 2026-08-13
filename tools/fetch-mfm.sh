#!/usr/bin/env bash
# Fetch the parsed Munitorum Field Manual points into data/mfm/.
#
# BSData/wh40k-11e-mfm, MIT licensed, parsed from
# https://mfm.warhammer-community.com/ — Games Workshop's own published points.
#
# Used only as a CROSS-CHECK against the primary dataset (DESIGN.md §3.0).
# Nothing from here is shipped.
#
# Usage:  tools/fetch-mfm.sh [faction-slug ...]     (default: tau-empire)

set -euo pipefail

REF="${MFM_REF:-main}"
BASE="https://raw.githubusercontent.com/BSData/wh40k-11e-mfm/${REF}/data"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/data/mfm"

FACTIONS=("$@")
if [ ${#FACTIONS[@]} -eq 0 ]; then FACTIONS=("tau-empire"); fi

mkdir -p "$OUT"
for faction in "${FACTIONS[@]}"; do
  if curl -fsSL "${BASE}/${faction}.yaml" -o "${OUT}/${faction}.yaml"; then
    printf '  ok   %s (%s bytes)\n' "$faction" "$(wc -c <"${OUT}/${faction}.yaml" | tr -d ' ')"
  else
    printf '  MISS %s\n' "$faction"
    rm -f "${OUT}/${faction}.yaml"
  fi
done

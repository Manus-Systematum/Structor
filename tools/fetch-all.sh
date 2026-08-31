#!/usr/bin/env bash
#
# Fetch every faction from both upstream sources, so a machine with nothing
# but a clone can rebuild the dataset.
#
# The vendored trees are gitignored (§3.10): they are large, and they are
# reproducible from the pinned refs below. A fresh checkout — a cloud session
# fixing a data bug, a new laptop — runs this and then rebuild-assets.sh, and
# is looking at exactly what the app reads.
#
# The faction list is read out of fetch-bsdata.sh's own map rather than
# repeated here, so adding a faction is still one edit.
#
#   FORTYKDC_REF / BSDATA_REF pin the upstream revisions, and default to main.
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

factions=$(
  sed -n '/^MAP=\$(cat <<.EOF./,/^EOF$/p' "$root/tools/fetch-bsdata.sh" |
    grep -E $'^[a-z0-9-]+\t' | cut -f1 | sort -u
)
if [ -z "$factions" ]; then
  echo "could not read the faction map out of tools/fetch-bsdata.sh" >&2
  exit 2
fi

echo "==> 40kdc ($(wc -w <<<"$factions" | tr -d ' ') factions, ref ${FORTYKDC_REF:-main})"
# shellcheck disable=SC2086
"$root/tools/fetch-40kdc.sh" $factions

echo "==> BSData (ref ${BSDATA_REF:-main})"
"$root/tools/fetch-bsdata.sh"

echo
echo "done — now run tools/rebuild-assets.sh to merge and build the bundles"

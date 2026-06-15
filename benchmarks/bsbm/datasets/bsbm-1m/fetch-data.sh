#!/usr/bin/env bash
#
# Generate the pinned BSBM "1M" dataset (scale point pc=2785) for the test driver.
#
# Unlike the DBLP/Wikidata benchmarks (which download a fixed dump), BSBM's data
# comes from a DETERMINISTIC generator: the same (toolkit version, -pc, flags)
# yields byte-identical N-Triples on any machine — no seed, no download. So the
# reproducibility pin is (bsbmtools-v0.2 SHA in ../../setup-bsbmtools.sh) + (-pc)
# + (flags below), and we record the SHA-256 of the generated dataset to lock it.
#
# Usage:  ./fetch-data.sh [--force]
# Result: ./td/  — dataset.nt (load target), dataset_update.nt (update use case),
#                  and the test-driver parameter pools (*.dat) read via -idir.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSBM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"          # benchmarks/bsbm
TOOLS="$BSBM_DIR/bsbmtools-0.2"
TD="$SCRIPT_DIR/td"                                   # test-driver data dir (-idir)

# --- Pinned scale ------------------------------------------------------------
PC=2785                       # canonical BSBM "1M" scale point
# Expected generator output for this pin (forward-chained, N-Triples), recorded
# 2026-06-03 from bsbmtools-v0.2. A mismatch means the toolkit/flags drifted.
EXPECT_TRIPLES=724101
EXPECT_SHA256="0eca9f19829be6390700196c5de4fe6e3d0610e1cd09d7f780de6526a95a48c8"
# -----------------------------------------------------------------------------

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

# Ensure the toolkit is present (downloads + verifies the pinned zip).
"$BSBM_DIR/setup-bsbmtools.sh" $([[ "$FORCE" == true ]] && echo --force)

if [[ -f "$TD/dataset.nt" && "$FORCE" == false ]]; then
    echo "Dataset already generated: $TD/dataset.nt (use --force to regenerate)."
else
    echo "Generating BSBM pc=$PC (forward-chained, N-Triples, + update dataset) ..."
    rm -rf "$TD" && mkdir -p "$TD"
    # generate/testdriver insist on running from the toolkit root.
    # -fn sets the main dataset path; -ufn sets the UPDATE dataset path, which
    # otherwise defaults to CWD (the toolkit root), NOT -dir — so set it into $TD.
    ( cd "$TOOLS" && ./generate -fc -pc "$PC" -s nt -ud \
        -dir "$TD" -fn "$TD/dataset" -ufn "$TD/dataset_update" )
fi

triples="$(wc -l < "$TD/dataset.nt" | tr -d ' ')"
if command -v sha256sum >/dev/null 2>&1; then sha="$(sha256sum "$TD/dataset.nt" | awk '{print $1}')"
else sha="$(shasum -a 256 "$TD/dataset.nt" | awk '{print $1}')"; fi

echo "  dataset.nt: $triples triples, sha256 $sha"
[[ "$triples" == "$EXPECT_TRIPLES" ]] || echo "  WARN: triple count != pinned $EXPECT_TRIPLES (toolkit/flags drift?)"
[[ "$sha" == "$EXPECT_SHA256" ]]     || echo "  WARN: sha256 != pinned (toolkit/flags drift?)"

echo ""
echo "Ready:"
echo "  load target:    $TD/dataset.nt   (fluree create bsbm --from this; .nt imported natively)"
echo "  update dataset: $TD/dataset_update.nt"
echo "  driver -idir:   $TD"
echo "Next: load into Fluree, then ../../run-matrix.sh (see ../../README.md)."

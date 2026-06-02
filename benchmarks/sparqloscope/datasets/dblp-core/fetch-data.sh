#!/usr/bin/env bash
#
# Download the pinned DBLP-core snapshot (standard bibliography, no citations),
# verify it, and decompress it for import. Reproducibility depends on every run
# using the *same* dump, so we pin a dated, DOI-tracked monthly archive on
# Dagstuhl DROPS (dblp.org/rdf's "latest" is overwritten continuously). See
# DATASET.md.
#
# DROPS serves single-stream throttled (~250 KB/s), so this uses parallel range
# requests (aria2c if present, else curl). ~4.73 GB.
#
# Usage:
#   ./fetch-data.sh           # download + verify + decompress into ./data/
#   ./fetch-data.sh --force   # re-download / re-decompress even if present
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

# --- Pinned snapshot ---------------------------------------------------------
# DBLP RDF/N-Triples release 2026-06-01 — latest stable monthly DROPS archive
# at the time of pinning. ~525M triples. DOI 10.4230/dblp.rdf.ntriples.2026-06-01.
# Set FLUREE_DBLP_URL to point at a faster mirror of the SAME file if desired.
GZ_NAME="dblp-2026-06-01.nt.gz"
SNAPSHOT_URL="${FLUREE_DBLP_URL:-https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2026/${GZ_NAME}}"
# Exact byte size of the archive (verified live 2026-06-02) — integrity pre-check.
SNAPSHOT_BYTES="${FLUREE_DBLP_BYTES:-5083386634}"
# SHA-256 of the .nt.gz (computed 2026-06-02 from the DROPS archive).
SNAPSHOT_SHA256="${FLUREE_DBLP_SHA256:-6a1edc1b7aebcd7a581bc4313243029952af4af0fbf900e4126a72d6deb92309}"
# -----------------------------------------------------------------------------

GZ="$DATA_DIR/$GZ_NAME"
# N-Triples is a syntactic subset of Turtle; we give it a .ttl extension so
# Fluree's importer (which dispatches on extension) routes it to the Turtle
# parser. Same graph, same triple count.
TTL="$DATA_DIR/dblp.ttl"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

mkdir -p "$DATA_DIR"

# --- Download (parallel range requests; DROPS is single-stream throttled) -----
if [[ -f "$GZ" && "$FORCE" == false ]]; then
    echo "Archive already present: $GZ (use --force to re-download)."
else
    echo "Downloading pinned DBLP-core snapshot..."
    echo "  URL: $SNAPSHOT_URL"
    if command -v aria2c >/dev/null 2>&1; then
        aria2c -x16 -s16 -k1M --file-allocation=none --console-log-level=warn \
               -d "$DATA_DIR" -o "$GZ_NAME.part" "$SNAPSHOT_URL"
    else
        echo "  (aria2c not found — falling back to single-stream curl; this is slow."
        echo "   Install aria2 for a ~15min parallel download: sudo apt-get install -y aria2)"
        curl --proto '=https' --tlsv1.2 -fL --progress-bar -C - -o "$GZ.part" "$SNAPSHOT_URL"
    fi
    mv "$GZ.part" "$GZ"
fi

# --- Verify byte size --------------------------------------------------------
actual_bytes="$(wc -c < "$GZ" | tr -d ' ')"
if [[ "$actual_bytes" != "$SNAPSHOT_BYTES" ]]; then
    echo "ERROR: size mismatch — expected $SNAPSHOT_BYTES bytes, got $actual_bytes."
    echo "Download incomplete or wrong file; not the pinned snapshot."
    exit 1
fi
echo "OK — archive is $actual_bytes bytes (matches pin)."

# --- Verify / record SHA-256 -------------------------------------------------
echo "Computing SHA-256 of $GZ_NAME ..."
if command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "$GZ" | awk '{print $1}')"
else
    actual_sha="$(shasum -a 256 "$GZ" | awk '{print $1}')"
fi
if [[ "$SNAPSHOT_SHA256" == TODO_* ]]; then
    echo "NOTE: no SHA-256 pinned yet. Computed:"
    echo "  $actual_sha"
    echo "Record this in fetch-data.sh (SNAPSHOT_SHA256) and DATASET.md to lock the pin."
elif [[ "$actual_sha" != "$SNAPSHOT_SHA256" ]]; then
    echo "ERROR: SHA-256 mismatch!"
    echo "  expected: $SNAPSHOT_SHA256"
    echo "  actual:   $actual_sha"
    exit 1
else
    echo "OK — archive matches pinned SHA-256."
fi

# --- Decompress for import ----------------------------------------------------
if [[ -f "$TTL" && "$FORCE" == false ]]; then
    echo "Decompressed file already present: $TTL"
else
    echo "Decompressing to $TTL ..."
    gunzip -c "$GZ" > "$TTL.part"
    mv "$TTL.part" "$TTL"
fi

echo ""
echo "Ready:"
echo "  archive: $GZ"
echo "  import:  $TTL  ($(wc -l < "$TTL" | tr -d ' ') N-Triples lines)"
echo "Next:  fluree create dblp --from $TTL"

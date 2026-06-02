#!/usr/bin/env bash
#
# Download the frozen DBLP snapshot used by this benchmark, verify it against
# the pinned checksum, and decompress it for import. Reproducibility depends on
# every run using the *same* dump — DBLP changes weekly, so we pin one.
#
# Keeps the compressed .nt.gz in ./data/ so it can be mirrored as a GitHub
# Release asset (the source archive can be slow / may move).
#
# Usage:
#   ./fetch-data.sh           # download + verify + decompress into ./data/
#   ./fetch-data.sh --force   # re-download/re-decompress even if present
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

# --- Pinned snapshot ---------------------------------------------------------
# DBLP RDF/N-Triples release 2024-04-01 — the dump the SPARQLoscope paper
# (ISWC 2025) evaluated on (it writes "02.04.2024"; the actual release file is
# dated 2024-04-01). ~390M triples, 68 predicates. Pinning the same dump keeps
# Fluree's numbers comparable to the paper's engine results. See DATASET.md.
#
# DBLP archives all monthly RDF releases on Dagstuhl DROPS (DOI
# 10.4230/dblp.rdf.ntriples.2024-04-01). Optionally set FLUREE_DBLP_URL to a
# GitHub Release mirror of the same file.
GZ_NAME="dblp-2024-04-01.nt.gz"
SNAPSHOT_URL="${FLUREE_DBLP_URL:-https://drops.dagstuhl.de/storage/artifacts/dblp/rdf/2024/${GZ_NAME}}"
# SHA-256 of the .nt.gz (verified 2026-05-30 from the DROPS archive).
SNAPSHOT_SHA256="${FLUREE_DBLP_SHA256:-c4d05d2af955dd58aec821e6c2a4e9b2556ec9cd3741255cf3741527c4e59028}"
# -----------------------------------------------------------------------------

GZ="$DATA_DIR/$GZ_NAME"
# N-Triples is a syntactic subset of Turtle, so we hand it to Fluree's Turtle
# importer with a .ttl extension (the importer dispatches on extension and has
# no .nt handler). Same graph, just routed to the Turtle parser.
TTL="$DATA_DIR/dblp.ttl"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

mkdir -p "$DATA_DIR"

# --- Download the compressed archive (kept for mirroring) --------------------
if [[ -f "$GZ" && "$FORCE" == false ]]; then
    echo "Archive already present: $GZ (use --force to re-download)."
else
    echo "Downloading frozen DBLP snapshot..."
    echo "  URL: $SNAPSHOT_URL"
    curl --proto '=https' --tlsv1.2 -fL --progress-bar -o "$GZ.part" "$SNAPSHOT_URL"
    mv "$GZ.part" "$GZ"
fi

# --- Verify checksum of the archive ------------------------------------------
echo "Computing SHA-256 of $GZ_NAME ..."
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$GZ" | awk '{print $1}')"
else
    actual="$(shasum -a 256 "$GZ" | awk '{print $1}')"
fi

if [[ "$SNAPSHOT_SHA256" == TODO_* ]]; then
    echo "WARNING: no pinned checksum yet. Computed:"
    echo "  $actual"
    echo "Record this in fetch-data.sh (SNAPSHOT_SHA256) and DATASET.md to lock the pin."
elif [[ "$actual" != "$SNAPSHOT_SHA256" ]]; then
    echo "ERROR: checksum mismatch!"
    echo "  expected: $SNAPSHOT_SHA256"
    echo "  actual:   $actual"
    echo "The dump does not match the pinned snapshot; numbers would not be comparable."
    exit 1
else
    echo "OK — archive matches pinned checksum."
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
echo "  archive: $GZ   (mirror this as a GitHub Release asset)"
echo "  import:  $TTL"
echo "Next:  fluree init && fluree create dblp --from data/dblp.ttl"

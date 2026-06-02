#!/usr/bin/env bash
#
# Download the pinned Wikidata Truthy snapshot and verify it. Reproducibility
# depends on every run using the *same* dump, but Wikimedia overwrites
# latest-truthy.nt.gz weekly (and the paper's 2025-04-18 snapshot is gone). So we
# pin our benchmarked snapshot as a GitHub release mirror; --mirror pulls that
# exact copy. See DATASET.md.
#
# ~70.5 GB compressed. Plain upstream is a single HTTP stream; aria2c with range
# requests is much faster when the mirror allows it.
#
# Usage:
#   ./fetch-data.sh            # download from upstream (rolling latest) + verify
#   ./fetch-data.sh --mirror   # pull the exact pinned snapshot from our release
#   ./fetch-data.sh --force    # re-download even if already present
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

# --- Pinned snapshot ---------------------------------------------------------
# Wikidata Truthy dump, snapshot 2026-05-29 11:17:24 GMT (the "latest" at pin
# time). Set FLUREE_WD_URL to a faster mirror of the SAME file if desired.
GZ_NAME="latest-truthy.nt.gz"
SNAPSHOT_URL="${FLUREE_WD_URL:-https://dumps.wikimedia.org/wikidatawiki/entities/latest-truthy.nt.gz}"
# Exact byte size of the archive (verified live 2026-06-02) — integrity pre-check.
SNAPSHOT_BYTES="${FLUREE_WD_BYTES:-70497233745}"
# SHA-256 of the .nt.gz (computed 2026-06-02 from the downloaded snapshot).
SNAPSHOT_SHA256="${FLUREE_WD_SHA256:-9fb5a16502ac05d9b9aad9f161bfe4e3e9ac514e142d7cf5ae4efd030b9f739a}"
# Our pinned mirror (GitHub release; split into <2 GiB parts).
RELEASE_TAG="wikidata-truthy-source-20260529"
RELEASE_REPO="fluree/benchmark-db"
# -----------------------------------------------------------------------------

GZ="$DATA_DIR/$GZ_NAME"

MIRROR=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --mirror) MIRROR=true ;;
        --force)  FORCE=true ;;
    esac
done

mkdir -p "$DATA_DIR"

# --- Download ----------------------------------------------------------------
if [[ -f "$GZ" && "$FORCE" == false ]]; then
    echo "Archive already present: $GZ (use --force to re-download)."
elif [[ "$MIRROR" == true ]]; then
    echo "Fetching pinned snapshot from $RELEASE_REPO release $RELEASE_TAG (~70 GB, split parts)..."
    cd "$DATA_DIR"
    gh release download "$RELEASE_TAG" -R "$RELEASE_REPO" -p "${GZ_NAME}.part-*" --clobber
    echo "Reassembling parts -> $GZ_NAME ..."
    cat "${GZ_NAME}".part-* > "$GZ"
    rm -f "${GZ_NAME}".part-*
else
    echo "Downloading Wikidata Truthy snapshot from upstream (rolling 'latest')..."
    echo "  URL: $SNAPSHOT_URL"
    echo "  (if the size/SHA check below fails, upstream has rolled over — use --mirror)"
    if command -v aria2c >/dev/null 2>&1; then
        aria2c -x16 -s16 -k1M --file-allocation=none --console-log-level=warn \
               -d "$DATA_DIR" -o "$GZ_NAME.part" "$SNAPSHOT_URL"
    else
        echo "  (aria2c not found — single-stream curl; install aria2 for a faster"
        echo "   parallel download: sudo apt-get install -y aria2)"
        curl --proto '=https' --tlsv1.2 -fLR --progress-bar -C - -o "$GZ.part" "$SNAPSHOT_URL"
    fi
    mv "$GZ.part" "$GZ"
fi

# --- Verify byte size --------------------------------------------------------
actual_bytes="$(wc -c < "$GZ" | tr -d ' ')"
if [[ "$actual_bytes" != "$SNAPSHOT_BYTES" ]]; then
    echo "ERROR: size mismatch — expected $SNAPSHOT_BYTES bytes, got $actual_bytes."
    echo "Download incomplete or upstream rolled over; not the pinned snapshot (try --mirror)."
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

echo ""
echo "Ready:"
echo "  archive: $GZ ($actual_bytes bytes)"
echo "Next:  load into Fluree (see DATASET.md) / build the QLever index (see Qleverfile)."

#!/usr/bin/env bash
#
# Build a QLever index for one BSBM scale (loads dataset.nt into the DEFAULT
# graph → no -dg needed when querying; each scale is a separate index).
#
# Usage: ./load-qlever.sh <1m|100m|200m>
# Then serve: qlever-server -i ~/qlever-data/<scale>/index -p 7001 -j 64 -m 40G -s 300s
# Query at:   http://localhost:7001/   (server root, not /sparql)
#
# NOTE: -s is the per-query timeout (default 30s). BSBM BI's heavy root-type
# queries exceed 30s at 100M+; on its internal timeout QLever returns HTTP 429,
# which makes the BSBM driver ABORT the whole mix. Set -s above the driver's -t
# (we use -t 120000) so the driver's timeout governs and the mix completes with
# recorded timeouts instead of aborting. Explore is fast and unaffected.
#
set -euo pipefail
SCALE="${1:?usage: load-qlever.sh <scale>}"
QB="${QLEVER_BUILD:-$HOME/qlever-src/build}"
TD="${BSBM_TOOLS:-$HOME/bsbm/bsbmtools-0.2}/td_${SCALE}"
DEST="$HOME/qlever-data/${SCALE}"
mkdir -p "$DEST" && cd "$DEST"
echo "[$(date -u +%H:%M:%S)] building $SCALE index from $TD/dataset.nt ..."
"$QB/qlever-index" -i index -f "$TD/dataset.nt" -F nt -p true
echo "[$(date -u +%H:%M:%S)] DONE $SCALE — index in $DEST"

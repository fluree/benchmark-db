#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCALE="${1:?usage: load-qlever.sh 1m|100m|200m}"
QLEVER_HOME="${QLEVER_HOME:-$HOME/bsbm-engines/qlever}"
DATA="${BSBM_DATA:-$SCRIPT_DIR/../datasets/bsbm-$SCALE/td}"
DATA="$(cd "$DATA" && pwd)"
DEST="$QLEVER_HOME/data/$SCALE"
[[ ! -e "$DEST" ]] || { echo "Index directory already exists: $DEST" >&2;exit 1; }
mkdir -p "$QLEVER_HOME/metadata"
EXPECTED=$(python3 "$SCRIPT_DIR/check-dataset.py" "$SCALE" "$DATA/dataset.nt" --output "$QLEVER_HOME/metadata/dataset-$SCALE.json")
mkdir -p "$DEST" "$QLEVER_HOME/metadata"
cd "$DEST"
/usr/bin/time -v -o "$QLEVER_HOME/metadata/import-$SCALE.time" "$QLEVER_HOME/bin/qlever-index" -i index -f "$DATA/dataset.nt" -F nt -p true > "$QLEVER_HOME/metadata/import-$SCALE.log" 2>&1
printf '%s\n' "$EXPECTED" > "$QLEVER_HOME/metadata/expected-$SCALE.txt"
echo "Indexed $SCALE. Start with qlever-control.sh start $SCALE."

#!/usr/bin/env bash
#
# Download + verify the DBLP-KG dataset (DBLP bibliography + OpenCitations
# citations) and unpack its Turtle shards. See DATASET.md.
#
# Usage: ./fetch-data.sh [dest-dir]   (default ./data)
set -euo pipefail

DEST="${1:-data}"
URL="https://sparql.dblp.org/download/dblp_KG_with_associated_data.tar"
SHA256="963cf2d1483a068ba8460b901c11a3bd3598e22f945aff181f65740754329cba"
TAR="dblp_KG_with_associated_data.tar"

mkdir -p "$DEST" && cd "$DEST"

if [[ ! -f "$TAR" ]]; then
  echo "Downloading $URL (~6 GB)..."
  curl -LRC - -o "$TAR" "$URL"
fi

echo "Verifying SHA-256..."
if command -v sha256sum >/dev/null; then
  echo "$SHA256  $TAR" | sha256sum -c -
else
  echo "$SHA256  $TAR" | shasum -a 256 -c -
fi

echo "Unpacking shards..."
mkdir -p shards && tar -xf "$TAR" -C shards
echo "Done. $(ls shards/*.gz | wc -l | tr -d ' ') shards in $DEST/shards/"
echo "Load into Fluree:  fluree create dblp --from $DEST/shards/"

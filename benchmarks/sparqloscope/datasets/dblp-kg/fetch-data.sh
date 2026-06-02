#!/usr/bin/env bash
#
# Download + verify the DBLP-KG dataset (DBLP bibliography + OpenCitations
# citations) and unpack its Turtle shards. See DATASET.md.
#
# Usage: ./fetch-data.sh [dest-dir]            (default ./data)
#        ./fetch-data.sh --mirror [dest-dir]   pull the exact pinned snapshot
#
# The upstream URL is a rolling "latest" that can change without notice. The
# --mirror path fetches the exact SHA-pinned snapshot we benchmarked from this
# repo's GitHub release (split into <2 GiB parts, reassembled here). Requires
# the `gh` CLI authenticated with access to fluree/benchmark-db.
set -euo pipefail

MIRROR=0
if [[ "${1:-}" == "--mirror" ]]; then MIRROR=1; shift; fi

DEST="${1:-data}"
URL="https://sparql.dblp.org/download/dblp_KG_with_associated_data.tar"
SHA256="963cf2d1483a068ba8460b901c11a3bd3598e22f945aff181f65740754329cba"
TAR="dblp_KG_with_associated_data.tar"
RELEASE_TAG="dblp-kg-source-20260530"
RELEASE_REPO="fluree/benchmark-db"

mkdir -p "$DEST" && cd "$DEST"

if [[ ! -f "$TAR" ]]; then
  if [[ "$MIRROR" == 1 ]]; then
    echo "Fetching pinned snapshot from $RELEASE_REPO release $RELEASE_TAG (~6 GB, 4 parts)..."
    gh release download "$RELEASE_TAG" -R "$RELEASE_REPO" -p 'dblp-kg.tar.part-*' --clobber
    echo "Reassembling parts -> $TAR..."
    cat dblp-kg.tar.part-* > "$TAR"
    rm -f dblp-kg.tar.part-*
  else
    echo "Downloading $URL (~6 GB)..."
    echo "(upstream is rolling 'latest'; if the SHA check below fails, use --mirror for the pinned snapshot)"
    curl -LRC - -o "$TAR" "$URL"
  fi
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

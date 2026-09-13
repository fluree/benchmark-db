#!/usr/bin/env bash
# Pinned native Virtuoso 7.2.17, Ubuntu 24.04 amd64, 64-GiB database host.
# Usage: setup-virtuoso.sh [data-directory]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIRTUOSO_HOME="${VIRTUOSO_HOME:-$HOME/bsbm-engines/virtuoso}"
DATA_DIR="${1:-$SCRIPT_DIR/../datasets}"
DATA_DIR="$(cd "$DATA_DIR" && pwd)"
export VIRTUOSO_HOME
[[ ! -e "$VIRTUOSO_HOME/data/virtuoso.db" ]] || { echo 'Existing database: use a new VIRTUOSO_HOME for setup.' >&2; exit 1; }
mkdir -p "$VIRTUOSO_HOME"/{bin,dist,data,metadata}
sudo apt-get update -qq
# This is the administration client only; the server comes from the pinned release.
sudo apt-get install -y -qq virtuoso-opensource-7-bin=7.2.5.1+dfsg1-0.8build1
curl -fLsS --retry 3 https://github.com/openlink/virtuoso-opensource/releases/download/v7.2.17/virtuoso-opensource.x86_64-generic_glibc25-linux-gnu.tar.gz -o "$VIRTUOSO_HOME/release.tar.gz"
echo "45385ea8c1940e41d88d628f9318bbc992081c4cd5c4e18b57277b6df516b15b  $VIRTUOSO_HOME/release.tar.gz" | sha256sum -c -
tar -xzf "$VIRTUOSO_HOME/release.tar.gz" -C "$VIRTUOSO_HOME/dist" --strip-components=1
cp "$VIRTUOSO_HOME/dist/bin/virtuoso-t" "$VIRTUOSO_HOME/bin/"
cp /usr/bin/isql-vt "$VIRTUOSO_HOME/bin/isql"
python3 "$SCRIPT_DIR/virtuoso-config.py" "$VIRTUOSO_HOME" "$DATA_DIR" "${HTTP_PORT:-8182}" "${SQL_PORT:-1111}"
"$VIRTUOSO_HOME/bin/virtuoso-t" -? > "$VIRTUOSO_HOME/metadata/server-version.txt" 2>&1 || true
sha256sum "$VIRTUOSO_HOME/bin/"* > "$VIRTUOSO_HOME/metadata/binaries.sha256"
dpkg-query -W virtuoso-opensource-7-bin > "$VIRTUOSO_HOME/metadata/admin-client-version.txt"
bash "$SCRIPT_DIR/virtuoso-control.sh" start

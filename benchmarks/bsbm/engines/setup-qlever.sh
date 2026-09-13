#!/usr/bin/env bash
# Pinned official native package, Ubuntu 24.04 amd64. No moving source checkout.
set -euo pipefail
QLEVER_HOME="${QLEVER_HOME:-$HOME/bsbm-engines/qlever}"
mkdir -p "$QLEVER_HOME"/{bin,metadata}
curl -fLsS --retry 3 https://packages.qlever.dev/pool/main/q/qlever-bin/qlever-bin_0.6.0-1~noble~24.04_amd64.deb -o "$QLEVER_HOME/qlever.deb"
echo "83583d7a81c12123dc2d388abc62ff1c6a2d0d25efb458488066d20dc1cd9f41  $QLEVER_HOME/qlever.deb" | sha256sum -c -
sudo apt-get update -qq
sudo apt-get install -y -qq "$QLEVER_HOME/qlever.deb"
for binary in qlever-server qlever-index;do
 p=$(dpkg -L qlever-bin | grep "/$binary$" | head -1)
 cp "$p" "$QLEVER_HOME/bin/$binary"
done
dpkg-query -W qlever-bin > "$QLEVER_HOME/metadata/package-version.txt"
sha256sum "$QLEVER_HOME/bin/"* > "$QLEVER_HOME/metadata/binaries.sha256"
"$QLEVER_HOME/bin/qlever-server" --help > "$QLEVER_HOME/metadata/server-help.txt" 2>&1
echo "Installed QLever 0.6.0 in $QLEVER_HOME"

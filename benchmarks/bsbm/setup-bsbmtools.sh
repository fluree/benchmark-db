#!/usr/bin/env bash
#
# Fetch + verify the canonical BSBM toolkit (generator + test driver), shared by
# every bsbm dataset scale. BSBM brings its OWN measurement tooling — the Java
# `testdriver` (randomized query mix → QMpH/QpS), not this repo's run_benchmark.sh.
# We pin the original Freie Universität Berlin v0.2 distribution from SourceForge.
#
# The distribution ships a prebuilt `lib/bsbm.jar` (Java 6 bytecode) that runs
# fine on a modern JRE — so NO build step is needed. (Its `build.xml` targets
# `-source 6`, which JDK 9+ rejects; we deliberately don't rebuild.) Java only.
#
# Usage:  ./setup-bsbmtools.sh [--force]
# Result: ./bsbmtools-0.2/ with working ./generate and ./testdriver.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/bsbmtools-0.2"

# --- Pinned toolkit ----------------------------------------------------------
# BSBM Tools v0.2 (2011-02-17), the canonical reference release everyone cites.
ZIP_URL="https://sourceforge.net/projects/bsbmtools/files/bsbmtools/bsbmtools-0.2/bsbmtools-v0.2.zip/download"
ZIP_BYTES=2492911
ZIP_SHA256="40f5e59baadec3af0014b7647989d3e0fc0476af25e84a4bc9d7f8cd81520aaa"
# -----------------------------------------------------------------------------

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

command -v java >/dev/null 2>&1 || { echo "ERROR: java not found (install a JDK/JRE)."; exit 1; }

ZIP="$SCRIPT_DIR/bsbmtools-v0.2.zip"

if [[ -x "$TOOLS_DIR/generate" && "$FORCE" == false ]]; then
    echo "bsbmtools already present: $TOOLS_DIR (use --force to re-fetch)."
    exit 0
fi

echo "Downloading bsbmtools-v0.2.zip ..."
curl -sSL -o "$ZIP.part" "$ZIP_URL"
mv "$ZIP.part" "$ZIP"

actual_bytes="$(wc -c < "$ZIP" | tr -d ' ')"
[[ "$actual_bytes" == "$ZIP_BYTES" ]] || { echo "ERROR: size mismatch (expected $ZIP_BYTES, got $actual_bytes)."; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then actual_sha="$(sha256sum "$ZIP" | awk '{print $1}')"
else actual_sha="$(shasum -a 256 "$ZIP" | awk '{print $1}')"; fi
[[ "$actual_sha" == "$ZIP_SHA256" ]] || { echo "ERROR: SHA-256 mismatch!"; echo "  expected: $ZIP_SHA256"; echo "  actual:   $actual_sha"; exit 1; }
echo "OK — archive matches pin ($actual_bytes bytes, sha256 $actual_sha)."

( cd "$SCRIPT_DIR" && unzip -oq "$ZIP" )
chmod +x "$TOOLS_DIR/generate" "$TOOLS_DIR/testdriver"

echo ""
echo "Ready: $TOOLS_DIR"
echo "  generator: $TOOLS_DIR/generate     (java benchmark.generator.Generator)"
echo "  driver:    $TOOLS_DIR/testdriver   (java benchmark.testdriver.TestDriver)"
echo "  use cases: $TOOLS_DIR/usecases/{explore,exploreAndUpdate,businessIntelligence}/sparql.txt"
echo "Next: generate a dataset — see datasets/<scale>/fetch-data.sh"

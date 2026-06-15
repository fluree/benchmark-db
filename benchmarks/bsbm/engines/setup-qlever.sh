#!/usr/bin/env bash
#
# Reproducible QLever setup for the BSBM comparison (Ubuntu 24.04).
#
# NOTE: the official apt repo (packages.qlever.dev) returned HTTP 403 from our
# AWS box (IP-blocked), and we want a NATIVE build (not Docker) for a fair
# comparison vs native Fluree/Virtuoso — so we build from source using the
# official Dockerfile's dependency list + cmake flags.
#
# Produces ~/qlever-src/build/{qlever-index,qlever-server}.
#
set -euo pipefail
say(){ echo "[$(date -u +%H:%M:%S)] $*"; }

say "install build deps (from official Dockerfile builder stage)..."
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential cmake libicu-dev tzdata pkg-config uuid-runtime uuid-dev git \
  libjemalloc-dev ninja-build libzstd-dev libssl-dev libboost1.83-dev libboost-program-options1.83-dev \
  libboost-iostreams1.83-dev libboost-url1.83-dev libboost-container1.83-dev

say "clone qlever..."
rm -rf ~/qlever-src
git clone --recursive --depth 1 https://github.com/ad-freiburg/qlever.git ~/qlever-src
cd ~/qlever-src && mkdir -p build && cd build

say "cmake configure (Release; native march left to compiler auto-detect for best perf on this box)..."
cmake -DCMAKE_BUILD_TYPE=Release -DLOGLEVEL=INFO -DUSE_PARALLEL=true -D_NO_TIMING_TESTS=ON -GNinja ..

say "build qlever-index + qlever-server..."
cmake --build . --target qlever-index qlever-server

say "binaries:"; ls -la ~/qlever-src/build/qlever-index ~/qlever-src/build/qlever-server
say "DONE — next: ./load-qlever.sh <1m|100m|200m>"

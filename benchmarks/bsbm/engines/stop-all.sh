#!/usr/bin/env bash
# Stop the competitor instances managed by the current setup scripts.
# Fluree and legacy system services are managed separately; no global pkill.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/virtuoso-control.sh" stop
bash "$SCRIPT_DIR/qlever-control.sh" stop

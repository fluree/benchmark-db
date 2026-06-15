#!/usr/bin/env bash
#
# Reproducible Virtuoso 7 setup for the BSBM comparison (Ubuntu 24.04).
# Installs virtuoso-opensource-7 and tunes virtuoso.ini for a 64 GB box so the
# comparison is fair (the stock config uses NumberOfBuffers=10000 ≈ tiny, which
# would cripple Virtuoso). Run with sudo privileges available.
#
# After this: load data with load-virtuoso.sh, then drive with the BSBM
# testdriver pointed at http://localhost:8890/sparql using `-dg <graph>`.
#
set -euo pipefail
INI=/etc/virtuoso-opensource-7/virtuoso.ini
DATA_DIR="${1:-$HOME/bsbm/bsbmtools-0.2}"   # dir holding the td_* datasets (DirsAllowed)

echo "== install =="
export DEBIAN_FRONTEND=noninteractive
echo "virtuoso-opensource-7 virtuoso-opensource-7/dba-password password dba" | sudo debconf-set-selections
echo "virtuoso-opensource-7 virtuoso-opensource-7/dba-password-again password dba" | sudo debconf-set-selections
sudo apt-get update -qq
sudo -E apt-get install -y -qq virtuoso-opensource-7
virtuoso-t --version | head -2

echo "== tune $INI for 64 GB =="
sudo python3 - "$INI" "$DATA_DIR" <<'PY'
import re, sys
p, data = sys.argv[1], sys.argv[2]
s = open(p).read()
# 64 GB memory preset (OpenLink guidance ~85k buffers/GB; ~44 GB buffer pool)
s = re.sub(r"(?m)^NumberOfBuffers\s*=\s*\d+.*$", "NumberOfBuffers          = 5450000", s)
s = re.sub(r"(?m)^MaxDirtyBuffers\s*=\s*\d+.*$", "MaxDirtyBuffers          = 4000000", s)
s = re.sub(r"(?m)^MaxCheckpointRemap\s*=\s*\d+.*$", "MaxCheckpointRemap = 1360000", s)  # ~buffers/4
# allow the data dir for ld_dir bulk load
s = re.sub(r"(?m)^DirsAllowed\s*=.*$",
           f"DirsAllowed              = ., /usr/share/virtuoso-opensource-7/vad, {data}", s)
# server threads for the concurrency ramp (both [Parameters] and [HTTPServer])
s = re.sub(r"(?m)^ServerThreads\s*=.*$", "ServerThreads               = 100", s)
# SPARQL endpoint: don't refuse heavy BI on a pessimistic cost ESTIMATE (default 400),
# don't truncate results, set the BSBM graph as default. Per-query timeout governed by
# the driver's -t; MaxQueryExecutionTime kept generous so queries complete.
s = re.sub(r"(?m)^MaxQueryCostEstimationTime\s*=\s*\d+.*$", "MaxQueryCostEstimationTime = 0", s)
s = re.sub(r"(?m)^MaxQueryExecutionTime\s*=\s*\d+.*$", "MaxQueryExecutionTime      = 600", s)
s = re.sub(r"(?m)^ResultSetMaxRows\s*=\s*\d+.*$", "ResultSetMaxRows           = 10000000", s)
s = re.sub(r"(?m)^;?\s*DefaultGraph\s*=.*dataspace.*$", "DefaultGraph               = http://bsbm.org/", s)
open(p, "w").write(s)
print("tuned:", p)
PY
grep -nE "^NumberOfBuffers|^MaxDirtyBuffers|^MaxCheckpointRemap|^DirsAllowed|^ServerThreads|^MaxQueryCostEstimationTime|^MaxQueryExecutionTime|^ResultSetMaxRows|^DefaultGraph" "$INI"

echo "== restart (handle stale lock) =="
sudo systemctl stop virtuoso-opensource-7 || true
sudo pkill -9 virtuoso-t 2>/dev/null || true
sleep 3
sudo systemctl start virtuoso-opensource-7
for i in $(seq 1 30); do ss -ltn | grep -q ":8890" && break; sleep 2; done
echo "listening: $(ss -ltn | grep -oE ':8890|:1111' | tr '\n' ' ')"

# To enable the BSBM Explore-and-Update use case (Virtuoso is read-write; the
# anonymous SPARQL endpoint is read-only by default), grant update rights:
#   echo "GRANT SPARQL_UPDATE TO \"SPARQL\";" | isql-vt 1111 dba dba
echo "done. Next: ./load-virtuoso.sh <1m|100m|200m> <expected_count>"

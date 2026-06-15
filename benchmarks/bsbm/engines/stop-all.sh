#!/usr/bin/env bash
#
# Cleanly stop all BSBM engines on the bench box.
#
# IMPORTANT for Virtuoso: always `checkpoint` before stopping. A `pkill -9` (or an
# unclean stop) on a Virtuoso instance that has loaded/updated data leaves a large
# uncommitted transaction log, which Virtuoso then ROLLS FORWARD on the next start
# — we saw a ~13.5 GB / ~50-minute replay after a -9. Checkpoint truncates the log
# so the next start is instant.
#
set -uo pipefail
say(){ echo "[$(date -u +%H:%M:%S)] $*"; }

# Fluree (graceful: SIGTERM to the binary; bracket pattern avoids self-match in pgrep)
fpid=$(pgrep -f "[b]in/fluree" | head -1)
[ -n "${fpid:-}" ] && { say "stopping Fluree (pid $fpid)"; kill "$fpid" 2>/dev/null; }

# QLever (no persistent state to flush; plain term/kill)
pkill qlever-server 2>/dev/null && say "stopping QLever" || true

# Virtuoso: checkpoint FIRST, then graceful stop, then verify exit (no -9).
if pgrep -x virtuoso-t >/dev/null; then
  say "checkpointing Virtuoso before stop..."
  echo "checkpoint;" | isql-vt 1111 dba dba >/dev/null 2>&1 || true
  sudo systemctl stop virtuoso-opensource-7 2>/dev/null || true
  # systemd may have lost track if a prior start timed out; SIGTERM the process directly.
  vpid=$(pgrep -x virtuoso-t | head -1)
  [ -n "${vpid:-}" ] && kill "$vpid" 2>/dev/null || true
  for i in $(seq 1 60); do pgrep -x virtuoso-t >/dev/null || break; sleep 3; done
  say "virtuoso procs: $(pgrep -cx virtuoso-t || echo 0) (checkpoint done → next start is fast even if forced)"
fi

sleep 2
say "remaining: fluree=$(pgrep -fc '[b]in/fluree' || echo 0) qlever=$(pgrep -c qlever-server || echo 0) virtuoso=$(pgrep -cx virtuoso-t || echo 0)"
say "listening: $(ss -ltn | grep -oE ':8090|:8890|:7001' | tr '\n' ' ')(none = all stopped)"

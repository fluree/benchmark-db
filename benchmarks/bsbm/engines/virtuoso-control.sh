#!/usr/bin/env bash
# Start/stop only the instance managed by VIRTUOSO_HOME; no global pkill.
set -euo pipefail
VIRTUOSO_HOME="${VIRTUOSO_HOME:-$HOME/bsbm-engines/virtuoso}"
SQL_PORT="${SQL_PORT:-1111}"
mkdir -p "$VIRTUOSO_HOME/metadata"
alive() { kill -0 "$1" 2>/dev/null && [[ $(ps -o stat= -p "$1") != Z* ]] && [[ $(readlink -f "/proc/$1/exe") == $(readlink -f "$VIRTUOSO_HOME/bin/virtuoso-t") ]]; }
isql() { "$VIRTUOSO_HOME/bin/isql" "$SQL_PORT" dba dba VERBOSE=OFF; }
case "${1:?usage: virtuoso-control.sh start|stop}" in
start)
 if [[ -f "$VIRTUOSO_HOME/server.pid" ]] && alive "$(cat "$VIRTUOSO_HOME/server.pid")";then echo 'Already running';exit 0;fi
 cd "$VIRTUOSO_HOME/data"
 stamp=$(date -u +%Y%m%dT%H%M%SZ)
 nohup "$VIRTUOSO_HOME/bin/virtuoso-t" +foreground +configfile virtuoso.ini > "$VIRTUOSO_HOME/metadata/server-$stamp.log" 2>&1 < /dev/null &
 pid=$!;echo "$pid" > "$VIRTUOSO_HOME/server.pid"
 ready=false
 for _ in $(seq 1 180);do
  alive "$pid" || { tail -30 "$VIRTUOSO_HOME/metadata/server-$stamp.log";exit 1; }
  printf 'SELECT 1;\n' | isql > "$VIRTUOSO_HOME/metadata/ready.txt" 2>&1 || true
  if grep -Eq '^1[[:space:]]*$' "$VIRTUOSO_HOME/metadata/ready.txt";then ready=true;break;fi
  sleep 1
 done
 "$ready" || { echo 'Server readiness timeout' >&2;exit 1; }
 # Transaction-log fsync is separate from CheckpointSyncMode. Set it on every start.
 printf "SELECT __dbf_set ('dbf_log_fsync', 1);\nSELECT sys_stat ('dbf_log_fsync');\n" | isql > "$VIRTUOSO_HOME/metadata/fsync-$stamp.txt" 2>&1
 if grep -q '\*\*\* Error' "$VIRTUOSO_HOME/metadata/fsync-$stamp.txt";then cat "$VIRTUOSO_HOME/metadata/fsync-$stamp.txt";exit 1;fi
 grep -Eq '^1[[:space:]]*$' "$VIRTUOSO_HOME/metadata/fsync-$stamp.txt"
 ;;
stop)
 [[ -f "$VIRTUOSO_HOME/server.pid" ]] || exit 0
 pid=$(cat "$VIRTUOSO_HOME/server.pid")
 if alive "$pid";then
  printf 'checkpoint;\n' | isql > "$VIRTUOSO_HOME/metadata/stop-checkpoint.txt" 2>&1
  if grep -q '\*\*\* Error' "$VIRTUOSO_HOME/metadata/stop-checkpoint.txt";then cat "$VIRTUOSO_HOME/metadata/stop-checkpoint.txt";exit 1;fi
  kill "$pid"
  for _ in $(seq 1 120);do alive "$pid" || break;sleep 1;done
  if alive "$pid";then echo 'Server did not stop' >&2;exit 1;fi
 fi
 rm -f "$VIRTUOSO_HOME/server.pid"
 ;;
*) echo 'Expected start or stop' >&2;exit 1;;
esac

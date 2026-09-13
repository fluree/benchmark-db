#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QLEVER_HOME="${QLEVER_HOME:-$HOME/bsbm-engines/qlever}"
alive() { kill -0 "$1" 2>/dev/null && [[ $(ps -o stat= -p "$1") != Z* ]] && [[ $(readlink -f "/proc/$1/exe") == $(readlink -f "$QLEVER_HOME/bin/qlever-server") ]]; }
case "${1:?usage: qlever-control.sh start SCALE | stop}" in
start)
 SCALE="${2:?supply scale}"
 if [[ -f "$QLEVER_HOME/server.pid" ]] && alive "$(cat "$QLEVER_HOME/server.pid")";then echo 'Already running' >&2;exit 1;fi
 cd "$QLEVER_HOME/data/$SCALE"
 stamp=$(date -u +%Y%m%dT%H%M%SZ)
 nohup "$QLEVER_HOME/bin/qlever-server" -i index -p "${HTTP_PORT:-8182}" -j 64 -m 40G -s 600s --log-level WARN > "$QLEVER_HOME/metadata/server-$stamp.log" 2>&1 < /dev/null &
 pid=$!;echo "$pid" > "$QLEVER_HOME/server.pid"
 for _ in $(seq 1 180);do
  alive "$pid" || { tail -30 "$QLEVER_HOME/metadata/server-$stamp.log";exit 1; }
  if curl -s --max-time 2 "http://127.0.0.1:${HTTP_PORT:-8182}/" > /dev/null;then break;fi
  sleep 1
 done
 python3 "$SCRIPT_DIR/check-count.py" "http://127.0.0.1:${HTTP_PORT:-8182}/" "$(cat "$QLEVER_HOME/metadata/expected-$SCALE.txt")" --output "$QLEVER_HOME/metadata/count-$SCALE.xml"
 ;;
stop)
 [[ -f "$QLEVER_HOME/server.pid" ]] || exit 0
 pid=$(cat "$QLEVER_HOME/server.pid")
 if alive "$pid";then
  kill "$pid"
  for _ in $(seq 1 120);do alive "$pid" || break;sleep 1;done
  if alive "$pid";then echo 'Server did not stop' >&2;exit 1;fi
 fi
 rm -f "$QLEVER_HOME/server.pid";;
*) echo 'Expected start or stop' >&2;exit 1;;
esac

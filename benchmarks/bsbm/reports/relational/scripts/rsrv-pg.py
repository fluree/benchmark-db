#!/usr/bin/env python3
"""PostgreSQL server control for the BSBM relational baseline. rsrv-pg.py restart <label> | stop
restart: record postgres peak RSS (sum over backends is not meaningful; postmaster + max backend), restart, wait,
run the row-count check (product/offer/review) against the MySQL-derived expectations."""
import json, subprocess, sys, time, datetime
from pathlib import Path
r = Path.home() / 'results-pg'
EXPECT = {l.split('\t')[0]: int(l.split('\t')[1]) for l in (r / 'rowcounts.tsv').read_text().splitlines()}
def sh(c): return subprocess.run(c, shell=True, text=True, capture_output=True)
def hwm():
    best = None
    for p in sh('pgrep -x postgres').stdout.split():
        try:
            for l in Path(f'/proc/{p}/status').read_text().splitlines():
                if l.startswith('VmHWM'): best = max(best or 0, int(l.split()[1]))
        except FileNotFoundError: pass
    return best
a, label = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else '')
if a == 'restart':
    prev = hwm(); assert sh('sudo systemctl restart postgresql').returncode == 0
    for _ in range(600):
        if sh("sudo -u postgres psql -At -c 'SELECT 1'").returncode == 0: break
        time.sleep(1)
    got = {t: int(sh(f"sudo -u postgres psql -At benchmark -c 'SELECT COUNT(*) FROM {t}'").stdout) for t in ('product', 'offer', 'review')}
    assert all(got[t] == EXPECT[t] for t in got), (got, EXPECT)
    out = dict(label=label, previous_max_backend_vmhwm_kb=prev, counts=got, at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (r / (label + '-server.json')).write_text(json.dumps(out) + '\n'); print(json.dumps(out))
elif a == 'stop': sh('sudo systemctl stop postgresql')
else: raise ValueError(a)

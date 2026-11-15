#!/usr/bin/env python3
"""MySQL server control for the BSBM relational baseline. rsrv.py restart <label> | stop
restart: record mysqld peak RSS, restart mysqld, wait, run the row-count check (product/offer/review)."""
import json, subprocess, sys, time, datetime
from pathlib import Path
r = Path.home() / 'results'
EXPECT = {l.split('\t')[0]: int(l.split('\t')[1]) for l in (r / 'rowcounts.tsv').read_text().splitlines()}
def sh(c): return subprocess.run(c, shell=True, text=True, capture_output=True)
def hwm():
    p = sh('pgrep -x mysqld').stdout.split()
    if not p: return None
    for l in Path(f'/proc/{p[0]}/status').read_text().splitlines():
        if l.startswith('VmHWM'): return int(l.split()[1])
a, label = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else '')
if a == 'restart':
    prev = hwm(); assert sh('sudo systemctl restart mysql').returncode == 0
    for _ in range(600):
        if sh("sudo mysql -N -e 'SELECT 1'").returncode == 0: break
        time.sleep(1)
    got = {t: int(sh(f"sudo mysql benchmark -N -e 'SELECT COUNT(*) FROM `{t}`'").stdout) for t in ('product', 'offer', 'review')}
    assert all(got[t] == EXPECT[t] for t in got), (got, EXPECT)
    out = dict(label=label, previous_vmhwm_kb=prev, counts=got, at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (r / (label + '-server.json')).write_text(json.dumps(out) + '\n'); print(json.dumps(out))
elif a == 'stop': sh('sudo systemctl stop mysql')
else: raise ValueError(a)

#!/usr/bin/env python3
"""Generator-side coordinator, BSBM 100M Explore + SELECT subset on PostgreSQL. Per client count: a calibration pilot,
then three repeats sized to ~180 s; every cell restarts postgresql + row-count check, then 1,000 warmup mixes."""
import datetime, json, subprocess, time, traceback
from pathlib import Path
h = Path.home(); r = h / "results-pg"
peer = json.loads((h / 'peer.json').read_text())
URL = f"jdbc:postgresql://{peer['private_ip']}:5432/benchmark?user=bsbm&password=bsbm"
SSH = ['ssh', '-i', str(h / 'pair-key'), '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', 'ubuntu@' + peer['private_ip']]
def log(**kw): print(json.dumps(dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(), **kw)), flush=True)
def srv(*a):
    for _ in range(5):
        p = subprocess.run(SSH + ['python3', '/home/ubuntu/rsrv-pg.py', *a], text=True, capture_output=True, timeout=3600)
        if p.returncode == 0: return p.stdout
        if p.returncode != 255: raise RuntimeError((a, p.stdout[-800:], p.stderr[-1500:]))
        time.sleep(10)
    raise RuntimeError('ssh unreachable')
def cell(label, uc, c, n):
    log(stage='running', cell=label, runs=n); srv('restart', label + '-srv')
    o = subprocess.run(['env', 'BSBM_ENGINE=postgres', 'BSBM_RESULTS=results-pg', 'python3', str(h / 'cellsql.py'), label, uc, URL, str(c), str(n), '1000'], text=True, capture_output=True, check=True)
    row = json.loads(o.stdout.splitlines()[-1])
    with (r / 'cells.jsonl').open('a') as f: f.write(json.dumps(row) + '\n')
    print('RESULT', label, round(row.get('qmph') or 0, 2), row.get('seconds'), row.get('valid'), row.get('timeouts'), flush=True)
    return row
try:
    while subprocess.run(SSH + ['test -f ~/pgsetup.done'], capture_output=True).returncode != 0:
        if subprocess.run(SSH + ['test -f ~/pgsetup.exit'], capture_output=True).returncode == 0: raise RuntimeError('server setup failed')
        time.sleep(30)
    for uc in ('explore', 'select'):
        for c in (1, 4, 8, 16, 32, 64):
            p = cell(f'{uc}__c{c}__pilot', uc, c, max(100, 20 * c))
            if not p.get('qmph'): log(stage='pilot-failed', uc=uc, clients=c); continue
            n = max(10 * c, int(p['qmph'] * 180 / 3600 / 100) * 100, 100)
            for k in (1, 2, 3):
                try: cell(f'{uc}__c{c}__r{k}', uc, c, n)
                except Exception: traceback.print_exc(); print('CELL-FAILED', uc, c, k, flush=True)
    srv('stop'); log(stage='DONE')
except Exception:
    traceback.print_exc(); log(stage='FAILED', error=traceback.format_exc()[-1500:])

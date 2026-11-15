#!/usr/bin/env python3
"""fcoord.py BIN TAG : Fluree on the standard 100M pair (m7a.4xlarge server / m7a.2xlarge generator), same
protocol as the MySQL/PostgreSQL baselines (rcoord.py): per client count a calibration pilot, then three
repeats sized to ~180 s; every cell restarts the server (psrv.sh: published env, COUNT check), 1,000 warmups.
Uses the published cell.py (SPARQL XML results, keep-alive driver)."""
import datetime, json, subprocess, sys, time, traceback
from pathlib import Path
h = Path.home(); BIN, TAG = sys.argv[1:3]
peer = json.loads((h / 'peer.json').read_text())
EP = 'http://' + peer['private_ip'] + ':8182/v1/fluree/query/bsbm:main'
SSH = ['ssh', '-i', str(h / 'pair-key'), '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', 'ubuntu@' + peer['private_ip']]
def log(**kw): print(json.dumps(dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(), **kw)), flush=True)
def cell(label, uc, c, n):
    log(stage='running', cell=label, runs=n)
    for _ in range(3):
        p = subprocess.run(SSH + ['bash', 'psrv.sh', BIN, 'all', label], text=True, capture_output=True, timeout=1800)
        if p.returncode == 0: break
        time.sleep(10)
    else: raise RuntimeError(('server', p.stdout[-800:], p.stderr[-800:]))
    o = subprocess.run(['python3', str(h / 'cell.py'), label, uc, EP, str(c), str(n), '1000'], text=True, capture_output=True, check=True)
    row = json.loads(o.stdout.splitlines()[-1])
    with (h / 'results' / f'{TAG}-cells.jsonl').open('a') as f: f.write(json.dumps(row) + '\n')
    print('RESULT', label, round(row.get('qmph') or 0, 2), row.get('seconds'), row.get('valid'), row.get('timeouts'), flush=True)
    return row
try:
    for uc in ('explore', 'select'):
        for c in (1, 4, 8, 16, 32, 64):
            p = cell(f'{TAG}__{uc}__c{c}__pilot', uc, c, max(100, 20 * c))
            if not p.get('qmph'): log(stage='pilot-failed', uc=uc, clients=c); continue
            n = max(10 * c, int(p['qmph'] * 180 / 3600 / 100) * 100, 100)
            for k in (1, 2, 3):
                try: cell(f'{TAG}__{uc}__c{c}__r{k}', uc, c, n)
                except Exception: traceback.print_exc(); print('CELL-FAILED', uc, c, k, flush=True)
    subprocess.run(SSH + ['pkill -f "[f]luree.* server run"']); log(stage='DONE')
except Exception:
    traceback.print_exc(); log(stage='FAILED', error=traceback.format_exc()[-1500:])

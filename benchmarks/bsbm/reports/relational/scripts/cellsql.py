#!/usr/bin/env python3
"""cellsql.py LABEL USECASE JDBC_URL CLIENTS RUNS WARMUPS -- one BSBM cell in JDBC mode (same driver jar, seed,
timeout and accounting as cell.py for SPARQL). USECASE: explore | select."""
import sys, json, time, datetime, subprocess, re, xml.etree.ElementTree as E
from pathlib import Path
import os
h = Path.home(); label, uc, url, c, n, w = sys.argv[1:]; c, n, w = map(int, [c, n, w])
ENGINE = os.environ.get('BSBM_ENGINE', 'mysql'); DRIVER = {'mysql': 'com.mysql.cj.jdbc.Driver', 'postgres': 'org.postgresql.Driver'}[ENGINE]
out = h / os.environ.get('BSBM_RESULTS', 'results') / 'cells' / label; bench = h / 'harness/benchmarks/bsbm/bsbmtools-0.2'
usecase = {'explore': 'usecases/explore/sql.txt', 'select': 'usecases/explore-select/sql.txt'}[uc]
mix = {'explore': 25, 'select': 20}[uc]
args = ['java', '-cp', 'diagnostic-classes:.:lib/*', '-Xmx24G', '-Dlog4j.configuration=file:/home/ubuntu/log4j-warn.xml',
        f'-Xlog:gc:file={out}.gc.log', 'benchmark.testdriver.TestDriver', '-idir', str(h / 'data'), '-ucf', usecase,
        '-runs', str(n), '-w', str(w), '-seed', '808080', '-t', '300000', '-o', str(out) + '.xml', '-mt', str(c),
        '-sql', '-dbdriver', DRIVER, url]
meta = dict(label=label, workload=uc, clients=c, runs=n, warmups=w, engine=ENGINE, scale='100m',
            command=args, started_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
t0 = time.monotonic()
with Path(str(out) + '.log').open('w') as log:
    p = subprocess.run(['/usr/bin/time', '-v', '-o', str(out) + '.time', 'timeout', '--kill-after=30', '10800'] + args,
                       cwd=bench, stdout=log, stderr=subprocess.STDOUT)
meta.update(process_exit=p.returncode, wall_seconds=time.monotonic() - t0, ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
txt = Path(str(out) + '.log').read_text(errors='replace')
meta['driver_errors'] = bool(re.search(r'SQLException|PSQLException|Query execution error|Could not connect|Communications link failure|Connection refused|OutOfMemoryError|Exception in thread', txt))
meta['valid'] = False
try:
    root = E.parse(str(out) + '.xml').getroot(); m = root.find('querymix')
    qs = [q for q in root.findall('queries/query') if int(q.findtext('executecount') or 0) > 0]
    meta.update(qmph=float(m.findtext('qmph')), seconds=float(m.findtext('actualtotalruntime')), completed_mixes=int(m.findtext('querymixruns')),
                executions=sum(int(q.findtext('executecount')) for q in qs), timeouts=sum(int(q.findtext('timeoutcount')) for q in qs),
                result_counts={q.attrib['nr']: {k: q.findtext(k) for k in ['executecount', 'avgresults', 'minresults', 'maxresults']} for q in qs})
    meta['qps'] = meta['qmph'] * mix / 3600
    meta['valid'] = p.returncode == 0 and not meta['driver_errors'] and meta['completed_mixes'] == n and meta['executions'] == n * mix and meta['timeouts'] == 0
except Exception as e: meta['parse_error'] = str(e)
Path(str(out) + '.json').write_text(json.dumps(meta, indent=2) + '\n'); print(json.dumps(meta), flush=True)

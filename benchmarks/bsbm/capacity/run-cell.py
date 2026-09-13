#!/usr/bin/env python3
"""A reproducible single cell of the September 2026 capacity protocol (Linux)."""
import argparse
import datetime
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as E
from pathlib import Path
HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument('--tools', type=Path, default=HERE.parent / 'bsbmtools-0.2')
p.add_argument('--data', required=True, type=Path)
p.add_argument('--engine', required=True, choices=['fluree', 'virtuoso', 'qlever'])
p.add_argument('--endpoint', required=True)
p.add_argument('--graph')
p.add_argument('--update-endpoint')
p.add_argument('--workload', choices=['explore', 'select', 'bi', 'update'], required=True)
p.add_argument('--clients', required=True, type=int)
p.add_argument('--runs', required=True, type=int)
p.add_argument('--warmups', required=True, type=int)
p.add_argument('--output', required=True, type=Path, help='Unique output prefix; no extension')
p.add_argument('--minimum-seconds', type=float, default=120,
               help='Use 0 for calibration/qualification and bounded Update cells')
a = p.parse_args()
if a.clients < 1 or a.runs < 1 or a.warmups < 0:
    p.error('clients/runs must be positive; warmups cannot be negative')
tools = a.tools.resolve();data = a.data.resolve();out = a.output.resolve()
out.parent.mkdir(parents=True, exist_ok=True)
if Path(str(out) + '.json').exists() or Path(str(out) + '.xml').exists():
    p.error('Output already exists; use a new prefix for each repetition')
if not (tools / 'capacity-classes/benchmark/testdriver/NetQuery.class').exists():
    p.error('Run prepare-driver.py first')
uc = dict(explore='explore', select='explore-select', bi='businessIntelligence', update='exploreAndUpdate')[a.workload]
length = dict(explore=25, select=20, bi=15, update=30)[a.workload]
if a.workload == 'update':
    if not a.update_endpoint:
        p.error('Update requires --update-endpoint')
    blocks = sum(line.strip() == '#__SEP__' for line in (data / 'dataset_update.nt').open())
    if 2 * (a.runs + a.warmups) > blocks:
        p.error(f'Update input would be exhausted: need {2 * (a.runs + a.warmups)} payloads; have {blocks}')
args = ['java', '-cp', 'capacity-classes:.:lib/*', '-Xmx24G', '-Dbsbm.keepAlive=true',
        '-Dhttp.maxConnections=256', '-Dlog4j.configuration=file:' + str(HERE / 'log4j-warn.xml'),
        '-Xlog:gc:file=' + str(out) + '.gc.log', 'benchmark.testdriver.TestDriver',
        '-idir', str(data), '-ucf', f'usecases/{uc}/sparql.txt', '-runs', str(a.runs),
        '-w', str(a.warmups), '-seed', '808080', '-t', '300000', '-o', str(out) + '.xml',
        '-mt', str(a.clients)]
if a.graph:
    args += ['-dg', a.graph]
if a.workload == 'update':
    args += ['-u', a.update_endpoint, '-uqp', 'update', '-udataset', str(data / 'dataset_update.nt')]
args += [a.endpoint]
record = dict(engine=a.engine, workload=a.workload, clients=a.clients, runs=a.runs,
              warmups=a.warmups, operations_per_mix=length, command=args,
              minimum_seconds=a.minimum_seconds,
              driver=json.loads((tools / 'capacity-driver.json').read_text()),
              started_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
meta = Path(str(out) + '.json');meta.write_text(json.dumps(record, indent=2) + '\n')
with Path(str(out) + '.log').open('w') as log:
    process = subprocess.run(['/usr/bin/time', '-v', '-o', str(out) + '.time', 'timeout',
                              '--kill-after=30', '10800'] + args, cwd=tools,
                             stdout=log, stderr=subprocess.STDOUT)
record.update(process_exit=process.returncode, valid=False,
              ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
log = Path(str(out) + '.log').read_text(errors='replace')
record['driver_errors'] = bool(re.search(
    r'SAX Error|Query execution error|Could not read result|Could not connect|Received error code|OutOfMemoryError|Exception in thread', log))
try:
    root = E.parse(str(out) + '.xml').getroot();mix = root.find('querymix')
    queries = [q for q in root.findall('queries/query') if int(q.findtext('executecount') or 0) > 0]
    record.update(qmph=float(mix.findtext('qmph')), seconds=float(mix.findtext('actualtotalruntime')),
                  completed_mixes=int(mix.findtext('querymixruns')),
                  executions=sum(int(q.findtext('executecount')) for q in queries),
                  timeouts=sum(int(q.findtext('timeoutcount')) for q in queries),
                  result_counts={q.attrib['nr']: {k: q.findtext(k) for k in
                      ['executecount', 'avgresults', 'minresults', 'maxresults']} for q in queries})
    record['qps'] = record['qmph'] * length / 3600
    record['valid'] = (process.returncode == 0 and not record['driver_errors'] and
                       record['completed_mixes'] == a.runs and record['executions'] == length * a.runs and
                       record['timeouts'] == 0 and all(float(q.findtext('minresults')) >= 0 for q in queries))
    record['duration_passed'] = record['seconds'] >= a.minimum_seconds
except Exception as e:
    record['parse_error'] = str(e)
meta.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
sys.exit(0 if record['valid'] and record.get('duration_passed') else 2)

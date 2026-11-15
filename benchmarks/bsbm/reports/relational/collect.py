#!/usr/bin/env python3
"""Build summary.tsv and per_query.tsv for the relational baseline from the committed driver XMLs.

    runs/<engine>/<workload>__c<clients>__r<k>.xml   (pilots are not committed and not counted)
    ../v4.2.7/runs/100m/*.xml                        (the published Fluree v4.2.7 release runs, same hardware)

summary.tsv   one row per (engine, workload, clients): median/min/max QMpH of the three repeats
per_query.tsv one row per (engine, workload, clients, query): median/min/max average query execution time
"""
import re, statistics, xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ENGINES = ['fluree-dev', 'postgres', 'mysql', 'fluree-v4.2.7']
MIX = {'explore': 25, 'select': 20}
cells, queries = defaultdict(list), defaultdict(list)
for engine in ENGINES:
    # the published v4.2.7 100M runs are read in place from the release report, not copied
    src = HERE.parent / 'v4.2.7/runs/100m' if engine == 'fluree-v4.2.7' else HERE / 'runs' / engine
    for x in sorted(src.glob('*.xml')):
        m = re.fullmatch(r'(explore|select)__c(\d+)__r(\d)', x.stem)
        if not m: continue
        wl, c = m.group(1), int(m.group(2))
        root = ET.parse(x).getroot(); qm = root.find('querymix')
        qs = [q for q in root.findall('queries/query') if int(q.findtext('executecount') or 0) > 0]
        cells[(engine, wl, c)].append(dict(qmph=float(qm.findtext('qmph')), mixes=int(qm.findtext('querymixruns')),
                                           seconds=float(qm.findtext('actualtotalruntime') or qm.findtext('totalruntime')),
                                           timeouts=sum(int(q.findtext('timeoutcount') or 0) for q in qs)))
        for q in qs:
            queries[(engine, wl, c, int(q.attrib['nr']))].append(dict(
                n=int(q.findtext('executecount')), aqet=float(q.findtext('aqet')) * 1000,
                avgresults=q.findtext('avgresults'), timeouts=int(q.findtext('timeoutcount') or 0)))

order = lambda k: (ENGINES.index(k[0]), k[1], k[2]) + tuple(k[3:])
with (HERE / 'summary.tsv').open('w') as f:
    f.write('engine\tworkload\tclients\trepeats\tqmph_median\tqmph_min\tqmph_max\tqps_median\tmixes_per_repeat\tseconds_per_repeat\ttimeouts\n')
    for k in sorted(cells, key=order):
        v = cells[k]; q = [r['qmph'] for r in v]; med = statistics.median(q)
        f.write(f"{k[0]}\t{k[1]}\t{k[2]}\t{len(v)}\t{med:.2f}\t{min(q):.2f}\t{max(q):.2f}\t{med * MIX[k[1]] / 3600:.1f}\t"
                f"{v[0]['mixes']}\t{','.join('%.1f' % r['seconds'] for r in v)}\t{sum(r['timeouts'] for r in v)}\n")
with (HERE / 'per_query.tsv').open('w') as f:
    f.write('engine\tworkload\tclients\tquery\texecutions_per_repeat\taqet_ms_median\taqet_ms_min\taqet_ms_max\tavgresults_r1\ttimeouts\n')
    for k in sorted(queries, key=order):
        v = queries[k]; a = [r['aqet'] for r in v]
        f.write(f"{k[0]}\t{k[1]}\t{k[2]}\t{k[3]}\t{v[0]['n']}\t{statistics.median(a):.3f}\t{min(a):.3f}\t{max(a):.3f}\t"
                f"{v[0]['avgresults']}\t{sum(r['timeouts'] for r in v)}\n")
print('cells', len(cells), 'query rows', len(queries))

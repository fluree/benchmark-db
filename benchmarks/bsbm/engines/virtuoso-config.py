#!/usr/bin/env python3
"""Generate the 64-GiB profile used by the September 2026 refresh."""
import configparser
import sys
from pathlib import Path
home, data, http, sql = sys.argv[1:]
h = Path(home).resolve()
p = configparser.ConfigParser(strict=False, interpolation=None)
p.optionxform = str
p.read(h / 'dist/database/virtuoso.ini.sample')
settings = {
    'Database': dict(DatabaseFile='virtuoso.db', ErrorLogFile='virtuoso.log',
                     LockFile='virtuoso.lck', TransactionFile='virtuoso.trx',
                     xa_persistent_file='virtuoso.pxa', ErrorLogLevel='3',
                     MaxCheckpointRemap='1360000'),
    'TempDatabase': dict(DatabaseFile='virtuoso-temp.db', TransactionFile='virtuoso-temp.trx'),
    'Parameters': dict(ServerPort='127.0.0.1:' + sql,
                       DirsAllowed=f'., {data}, {h}/dist/vad', VADInstallDir=f'{h}/dist/vad',
                       NumberOfBuffers='5450000', MaxDirtyBuffers='4000000',
                       MaxClientConnections='256', ServerThreads='256',
                       CheckpointSyncMode='2', MaxQueryMem='2G'),
    'HTTPServer': dict(ServerPort=http, ServerRoot=f'{h}/dist/vsp',
                       MaxClientConnections='256', ServerThreads='256',
                       MaxKeepAlives='1000000', KeepAliveTimeout='60'),
    'SPARQL': dict(MaxQueryCostEstimationTime='0', MaxQueryExecutionTime='600',
                   ResultSetMaxRows='10000000', DefaultGraph='http://bsbm.org/'),
}
for section, values in settings.items():
    if not p.has_section(section):
        p.add_section(section)
    for key, value in values.items():
        p.set(section, key, value)
with (h / 'data/virtuoso.ini').open('w') as f:
    p.write(f)
(h / 'metadata/virtuoso.ini').write_text((h / 'data/virtuoso.ini').read_text())

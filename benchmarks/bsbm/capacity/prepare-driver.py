#!/usr/bin/env python3
"""Build the transport-only keepalive variant; leave the distributed JAR intact."""
import argparse
import difflib
import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('--tools', type=Path, default=Path(__file__).resolve().parents[1] / 'bsbmtools-0.2')
a = p.parse_args();tools = a.tools.resolve();archive = tools.parent / 'bsbmtools-v0.2.zip'
expected = '40f5e59baadec3af0014b7647989d3e0fc0476af25e84a4bc9d7f8cd81520aaa'
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise SystemExit('Toolkit ZIP does not match the pinned distribution')
version = subprocess.check_output(['javac', '-version'], text=True, stderr=subprocess.STDOUT).strip()
if not version.startswith('javac 21.'):
    raise SystemExit(f'Use JDK 21 for this protocol; found {version}')
with zipfile.ZipFile(archive) as z:
    # Verify every distributed JAR and canonical query/use-case file used by the driver.
    prefix = 'bsbmtools-0.2/'
    for name in z.namelist():
        relative = name[len(prefix):] if name.startswith(prefix) else ''
        if not name.endswith('/') and (relative.startswith('lib/') or relative.startswith('queries/') or relative.startswith('usecases/')):
            file = tools / relative
            if not file.exists() or hashlib.sha256(file.read_bytes()).digest() != hashlib.sha256(z.read(name)).digest():
                raise SystemExit(f'Toolkit file differs from the pinned distribution: {file}')
    before = z.read('bsbmtools-0.2/src/benchmark/testdriver/NetQuery.java').decode().replace('\r\n', '\n')
assert before.count('return conn.getInputStream();') == 1 and before.count('conn.disconnect();') == 1
after = before.replace('HttpURLConnection conn;', 'HttpURLConnection conn;\n\tInputStream response;')
after = after.replace('return conn.getInputStream();', 'response = conn.getInputStream();\n\t\t\treturn response;')
after = after.replace('conn.disconnect();', '''if (Boolean.getBoolean("bsbm.keepAlive") && response != null) {
            try { response.close(); }
            catch (IOException e) { conn.disconnect(); }
        } else {
            conn.disconnect();
        }''')
source = tools / 'capacity-src/benchmark/testdriver/NetQuery.java'
source.parent.mkdir(parents=True, exist_ok=True);source.write_text(after)
classes = tools / 'capacity-classes';classes.mkdir(exist_ok=True)
subprocess.run(['javac', '-cp', str(tools / 'lib/*'), '-d', str(classes), str(source)], check=True)
patch = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='original/NetQuery.java', tofile='keepalive/NetQuery.java'))
(tools / 'capacity-keepalive.patch').write_text(patch)
shutil.copytree(tools / 'queries/explore', tools / 'queries/explore-select', dirs_exist_ok=True)
mix = tools / 'queries/explore-select/querymix.txt'
mix.write_text(' '.join(x for x in mix.read_text().split() if x not in {'9', '12'}) + '\n')
(tools / 'usecases/explore-select').mkdir(exist_ok=True)
(tools / 'usecases/explore-select/sparql.txt').write_text('querymix=queries/explore-select\n')
record = dict(toolkit_sha256=expected, javac=version, class_sha256=hashlib.sha256(
    (classes / 'benchmark/testdriver/NetQuery.class').read_bytes()).hexdigest())
(tools / 'capacity-driver.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))

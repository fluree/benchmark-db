#!/usr/bin/env python3
from pathlib import Path
import difflib
p=Path('src/benchmark/testdriver/NetQuery.java')
before=p.read_text()
assert before.count('return conn.getInputStream();')==1
assert before.count('conn.disconnect();')==1
after=before.replace('HttpURLConnection conn;','HttpURLConnection conn;\n\tInputStream response;')
after=after.replace('return conn.getInputStream();','response = conn.getInputStream();\n\t\t\treturn response;')
after=after.replace('conn.disconnect();','''if (Boolean.getBoolean("bsbm.keepAlive") && response != null) {
            try { response.close(); }
            catch (IOException e) { conn.disconnect(); }
        } else {
            conn.disconnect();
        }''')
p.write_text(after)
(Path.home()/'results/keepalive.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='original/NetQuery.java',tofile='keepalive/NetQuery.java')))

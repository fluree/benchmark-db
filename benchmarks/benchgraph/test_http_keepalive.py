"""Verify the benchmark transport against a real local HTTP/1.1 server.

Run: python3 -m unittest discover -s benchmarks/benchgraph -p 'test_*.py'
No database or third-party Python packages required.
"""
import json
import threading
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import bench_runner


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self):
        super().__init__(("127.0.0.1", 0), Handler)
        self.connections = 0
        self.requests = []

    def get_request(self):
        client = super().get_request()
        self.connections += 1
        return client


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.server.requests.append((self.path, data))
        if data["cypher"] == "drop response":
            # Simulate a committed write whose response never reaches the client.
            self.close_connection = True
            return
        code = 400 if data["cypher"] == "query error" else 200
        body = json.dumps({"tx-id": "commit"} if "/update/" in self.path else
                          {"results": [{"data": [[1], [2]]}]}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class KeepAliveTest(unittest.TestCase):
    def setUp(self):
        self.server = Server()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}/v1/fluree"

    def tearDown(self):
        for conn in bench_runner._HTTP_CONNS.values():
            conn.close()
        bench_runner._HTTP_CONNS.clear()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def call(self, query="RETURN 1", write=False):
        path = "update" if write else "query"
        return bench_runner.http_call(f"{self.base}/{path}/pokec:main", query,
                                      {"id": 42}, 2, write)

    def test_reads_and_writes_share_one_connection(self):
        for write in (False, False, True, False):
            duration, size, error = self.call(write=write)
            self.assertIsNone(error)
            self.assertEqual(size, 1 if write else 2)
            self.assertGreater(duration, 0)
        self.assertEqual(self.server.connections, 1)
        self.assertEqual(len(self.server.requests), 4)
        self.assertEqual(self.server.requests[0][1]["params"], {"id": 42})

    def test_error_response_is_drained_before_next_request(self):
        self.assertIsNotNone(self.call("query error")[2])
        self.assertIsNone(self.call()[2])
        self.assertEqual(self.server.connections, 1)

    def test_lost_write_response_is_not_replayed(self):
        _, size, error = self.call("drop response", write=True)
        self.assertIsNone(size)
        self.assertIsNotNone(error)
        self.assertEqual(len(self.server.requests), 1)
        self.assertEqual(self.server.connections, 1)
        self.assertIsNone(self.call()[2])
        self.assertEqual(self.server.connections, 2)
        self.assertEqual(len(self.server.requests), 2)

    def test_runner_cli_reuses_connection_through_warmup_and_measurements(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "timings.tsv"
            result = subprocess.run(
                [sys.executable, str(bench_runner.HERE / "bench_runner.py"),
                 "--engine", "fluree", "--http-port", str(self.server.server_port),
                 "--query-glob", "aggregation__count", "--warmup", "1", "--runs", "3",
                 "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(output.read_text().splitlines()), 4)
        self.assertEqual(len(self.server.requests), 4)
        self.assertEqual(self.server.connections, 1)


if __name__ == "__main__":
    unittest.main()

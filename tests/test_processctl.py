import json
import subprocess
import os
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "processctl"
STATE_DIRECTORY = tempfile.TemporaryDirectory()


def run(*arguments, check=True):
    return subprocess.run(
        [str(HELPER), *map(str, arguments)],
        check=check,
        capture_output=True,
        text=True,
        env={**os.environ, "OMARCHY_PROCESS_MANAGER_STATE_DIR": STATE_DIRECTORY.name},
    )


def start_time(pid):
    return Path(f"/proc/{pid}/stat").read_text().split()[21]


class ProcessControlTests(unittest.TestCase):
    def setUp(self):
        self.process = subprocess.Popen(["sleep", "30"])
        self.identity = start_time(self.process.pid)

    def tearDown(self):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=2)

    def test_snapshot_has_live_fields(self):
        payload = json.loads(run("list").stdout)
        row = next(item for item in payload["processes"] if item["pid"] == self.process.pid)
        for field in ("startTime", "cpu", "memory", "rssMiB", "nice", "stopped"):
            self.assertIn(field, row)

    def test_pause_resume_renice_and_terminate(self):
        self.assertTrue(json.loads(run("pause", self.process.pid, self.identity).stdout)["ok"])
        time.sleep(0.05)
        self.assertIn(Path(f"/proc/{self.process.pid}/stat").read_text().split()[2], ("T", "t"))
        self.assertTrue(json.loads(run("resume", self.process.pid, self.identity).stdout)["ok"])
        self.assertTrue(json.loads(run("renice", self.process.pid, self.identity, 5).stdout)["ok"])
        self.assertTrue(json.loads(run("terminate", self.process.pid, self.identity).stdout)["ok"])
        self.process.wait(timeout=2)

    def test_rejects_stale_process_identity(self):
        result = run("terminate", self.process.pid, "0", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("identity changed", result.stderr)


if __name__ == "__main__":
    unittest.main()

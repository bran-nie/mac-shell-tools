"""Digest compatibility and generated-loader contracts on small fixtures."""
import hashlib
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests"))
from fixture import create


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.fixture = create(ROOT, self.directory / "fixture")

    def tearDown(self):
        self.temporary.cleanup()

    def build(self, *args, **kwargs):
        return subprocess.run(["sh", str(self.fixture / "scripts/build-installer.sh"), *args], text=True, capture_output=True, **kwargs)

    def test_batched_hashes_preserve_historical_tool_digest_format(self):
        paths = ["LICENSE", "tools/sample/VERSION", "tools/sample/sample.zsh", "lib/i18n.sh", "tools/sample/locales/en.sh", "tools/sample/locales/zh-CN.sh"]
        digest_input = "".join(hashlib.sha256((self.fixture / path).read_bytes()).hexdigest() + "  " + path + "\n" for path in paths)
        expected = hashlib.sha256(digest_input.encode()).hexdigest()
        self.assertEqual((self.fixture / "tools/sample/package.meta").read_text().splitlines()[3], expected)

    def test_each_unique_file_is_hashed_once_per_build(self):
        binary = self.directory / "bin"
        binary.mkdir()
        log = self.directory / "hashes.log"
        original = shutil.which("sha256sum")
        command = shlex.quote(original) if original else shlex.quote(shutil.which("shasum")) + " -a 256"
        wrapper = binary / "sha256sum"
        wrapper.write_text('#!/bin/sh\nfor input do printf "%s\\n" "$input" >> "$HASH_LOG"; done\nexec ' + command + ' "$@"\n')
        wrapper.chmod(0o755)
        completed = self.build(env=dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"], HASH_LOG=str(log)))
        self.assertEqual(completed.returncode, 0, completed.stderr)
        inputs = log.read_text().splitlines()
        self.assertEqual(len(inputs), len(set(inputs)))
        self.assertIn("LICENSE", inputs)
        self.assertIn("lib/i18n.sh", inputs)
        self.assertIn("tools/sample/sample.zsh", inputs)

    def test_catalog_generates_registrations_and_tampering_fails_check(self):
        catalog = self.fixture / "scripts/tools.list"
        catalog.write_text("sample.zsh\n")
        self.assertEqual(self.build().returncode, 0)
        loader = self.fixture / "tools/init.zsh"
        self.assertIn("tools/sample/sample.zsh", loader.read_text())
        self.assertNotIn("tools/second/second.zsh", loader.read_text())
        self.assertEqual(self.build("--check").returncode, 0)
        loader.write_text(loader.read_text() + "\n# edited generated output\n")
        check = self.build("--check")
        self.assertNotEqual(check.returncode, 0)
        self.assertIn("tools/init.zsh is stale", check.stderr)


if __name__ == "__main__":
    unittest.main()

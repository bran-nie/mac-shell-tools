"""Regression for macOS awk's locale-sensitive equality on Chinese headings."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class LanguageMarkerTests(unittest.TestCase):
    def test_marker_is_independent_of_heading_language_and_process_locale(self):
        headings = ["Supported languages (* = current):", "支持的语言（* 表示当前生效）："]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            for locale in ("C", "en_US.UTF-8", "zh_CN.UTF-8"):
                for heading in headings:
                    for language in ("en", "zh-CN"):
                        with self.subTest(locale=locale, heading=heading, language=language):
                            rows = [heading]
                            for identifier, label in (("en", "English"), ("zh-CN", "简体中文")):
                                marker = "*" if identifier == language else " "
                                rows.append(f"{marker} {identifier:<6} {label}")
                            output.write_text("\n".join(rows) + "\n")
                            actual = subprocess.check_output(["sh", "-c", '. "$1"; current_language_marker "$2"', "--", str(ROOT / "tests/common.sh"), str(output)],
                                                             env=dict(os.environ, LC_ALL=locale), text=True)
                            self.assertEqual(actual, language + "\n")


if __name__ == "__main__":
    unittest.main()

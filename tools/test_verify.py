"""Check the CI runner catches failures that Godot's exit code can miss."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import verify


class VerificationTests(unittest.TestCase):
    def test_error_output_is_rejected_with_zero_exit_status(self):
        for output in ["SCRIPT ERROR: Parse Error", "ERROR: Failed to load script",
                       "WARNING: ObjectDB instances leaked at exit", "FAIL route A"]:
            output += "\nCHECKS 1 FAILURES 0\n"
            with self.subTest(output=output), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "build/logs").mkdir(parents=True)
                with patch.object(verify, "ROOT", root), patch.object(
                    verify.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output)
                ), redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
                    verify.run("godot", "tests", [], marker=r"FAILURES 0")
                self.assertEqual((root / "build/logs/tests.log").read_text(), output)

    def test_missing_completion_marker_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "build/logs").mkdir(parents=True)
            with patch.object(verify, "ROOT", root), patch.object(
                verify.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "Godot started\n")
            ), redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
                verify.run("godot", "tests", [], marker=r"FAILURES 0")

    def test_expected_invalid_sequence_warnings_are_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "build/logs").mkdir(parents=True)
            with patch.object(verify, "ROOT", root), patch.object(
                verify.subprocess, "run", return_value=subprocess.CompletedProcess(
                    [], 0, "WARNING: Invalid cinematic sequence: bad destination\nCHECKS 1 FAILURES 0\n")
            ), redirect_stdout(io.StringIO()):
                verify.run("godot", "tests", [], marker=r"CHECKS [1-9][0-9]* FAILURES 0")


if __name__ == "__main__":
    unittest.main()

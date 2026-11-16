#!/usr/bin/env python3
"""Run bounded Godot checks and reject errors even when Godot exits zero."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ERRORS = re.compile(r"SCRIPT ERROR:|^ERROR:|^FAIL |^WARNING: ObjectDB instances leaked", re.MULTILINE)
VERSION = "4.6.3.stable"


def run(godot, name, args, timeout=300, marker=None, project_dir=None):
    command = [godot, "--headless", "--path", str(project_dir or ROOT), *args]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (ROOT / "build/logs" / f"{name}.log").write_text(output, encoding="utf-8")
        raise RuntimeError(f"{name} timed out after {timeout}s") from exc
    output = result.stdout
    (ROOT / "build/logs" / f"{name}.log").write_text(output, encoding="utf-8")
    print(output, end="", flush=True)
    if result.returncode or ERRORS.search(output) or (marker and not re.search(marker, output)):
        raise RuntimeError(f"{name} failed; see build/logs/{name}.log")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--suites", nargs="+", help="Optional suite subset")
    parser.add_argument("--export-windows", action="store_true")
    args = parser.parse_args()
    (ROOT / "build/logs").mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith(VERSION + "."):
        raise RuntimeError(f"Expected Godot {VERSION}, got {version}")
    run(args.godot, "import", ["--editor", "--import"])
    suites = ["--", *args.suites] if args.suites else []
    run(args.godot, "tests", ["res://tests/run.tscn", *suites],
        marker=r"CHECKS [1-9][0-9]* FAILURES 0")
    run(args.godot, "validate", ["res://tests/validate.tscn"], marker=r"0 problem\(s\)")
    if args.export_windows:
        destination = ROOT / "build/windows"
        destination.mkdir(parents=True, exist_ok=True)
        executable = destination / "LastCall.exe"
        run(args.godot, "export-windows", ["--export-release", "Windows Desktop", str(executable)])
        if not executable.is_file() or not executable.with_suffix(".pck").is_file():
            raise RuntimeError("Windows export did not produce both executable and resource pack")
        # Exercise the packaged menu/resources with the host Godot runtime in an
        # empty directory, so source files cannot mask missing pack dependencies.
        # This is a resource smoke test, not a Windows executable or GPU test.
        with tempfile.TemporaryDirectory(prefix="last-call-pack-") as directory:
            run(args.godot, "pack-startup", ["--main-pack", str(executable.with_suffix(".pck")),
                                           "--quit-after", "5"], timeout=30, project_dir=directory)
        with zipfile.ZipFile(ROOT / "build/LastCall-windows-greybox.zip", "w", zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(destination.iterdir()):
                if file.is_file():
                    archive.write(file, f"LastCall/{file.name}")
            archive.write(ROOT / "docs/WINDOWS_SMOKE_TEST.md", "LastCall/README.md")
        print("Built build/LastCall-windows-greybox.zip; Windows smoke test still required.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

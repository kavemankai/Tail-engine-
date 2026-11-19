#!/usr/bin/env python3
"""Run bounded Godot checks and reject errors even when Godot exits zero."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ERRORS = re.compile(r"SCRIPT ERROR:|^ERROR:|^FAIL |^WARNING: ObjectDB instances leaked", re.MULTILINE)
VERSION = "4.6.3.stable"


def run(godot, name, args, timeout=300, marker=None, project_dir=None, env=None):
    command = [godot, "--headless", "--path", str(project_dir or ROOT), *args]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout, env=env)
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
    parser.add_argument("--export-linux", action="store_true",
                        help="export the Linux build and play Episode 0 with the exported binary")
    args = parser.parse_args()
    (ROOT / "build/logs").mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith(VERSION + "."):
        raise RuntimeError(f"Expected Godot {VERSION}, got {version}")
    # A cached Dialogue Manager compiler version used to hide its startup leak.
    # Give Linux CI a fresh editor profile every time; do not alter player saves.
    with tempfile.TemporaryDirectory(prefix="last-call-import-profile-") as profile:
        env = os.environ.copy()
        if sys.platform.startswith("linux"):
            for kind in ("CONFIG", "DATA", "CACHE"):
                env[f"XDG_{kind}_HOME"] = str(Path(profile) / kind.lower())
        run(args.godot, "import", ["--verbose", "--editor", "--import"], env=env)
    suites = ["--", *args.suites] if args.suites else []
    run(args.godot, "tests", ["res://tests/run.tscn", *suites],
        marker=r"CHECKS [1-9][0-9]* FAILURES 0")
    run(args.godot, "validate", ["res://tests/validate.tscn"], marker=r"0 problem\(s\)")
    run(args.godot, "authoring", ["res://tools/authoring.tscn"], marker=r"AUTHORING [1-9][0-9]* resources, 0 errors")
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
            run(args.godot, "pack-lab-startup", ["--main-pack", str(executable.with_suffix(".pck")),
                                               "--quit-after", "5", "res://examples/last_call/qte_lab/lab.tscn"],
                timeout=30, project_dir=directory)
        with zipfile.ZipFile(ROOT / "build/LastCall-windows-greybox.zip", "w", zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(destination.iterdir()):
                if file.is_file():
                    archive.write(file, f"LastCall/{file.name}")
            archive.write(ROOT / "docs/WINDOWS_SMOKE_TEST.md", "LastCall/README.md")
        print("Built build/LastCall-windows-greybox.zip; Windows smoke test still required.")
    if args.export_linux:
        export_linux(args.godot)


def smoke(binary, extra=(), timeout=300, wrapper=(), env=None):
    """Run an exported build's unattended play-through; it must print SMOKE OK."""
    name = "smoke-" + binary.stem + ("-rendered" if wrapper else "")
    command = [*wrapper, str(binary), *extra, "--", "--te-smoke"]
    try:
        result = subprocess.run(command, cwd=binary.parent, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"{name} timed out after {timeout}s") from exc
    (ROOT / "build/logs" / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    print("\n".join(line for line in result.stdout.splitlines() if line.startswith("SMOKE")), flush=True)
    if result.returncode or "SMOKE OK" not in result.stdout or re.search(r"SCRIPT ERROR:", result.stdout):
        raise RuntimeError(f"{name} failed; see build/logs/{name}.log")


def export_linux(godot):
    destination = ROOT / "build/linux"
    destination.mkdir(parents=True, exist_ok=True)
    binary = destination / "LastCall.x86_64"
    run(godot, "export-linux", ["--export-release", "Linux", str(binary)])
    if not binary.is_file() or not binary.with_suffix(".pck").is_file():
        raise RuntimeError("Linux export did not produce both executable and resource pack")
    # Copy out of the source tree, so nothing but the export can satisfy a load.
    with tempfile.TemporaryDirectory(prefix="last-call-linux-") as directory:
        for file in destination.iterdir():
            shutil.copy2(file, directory)
        copied = Path(directory) / binary.name
        smoke(copied, ["--headless"])
        # With a virtual display the real renderer runs too (software OpenGL).
        if shutil.which("xvfb-run"):
            env = os.environ.copy()
            env["LIBGL_ALWAYS_SOFTWARE"] = "1"
            smoke(copied, ["--resolution", "1280x800"], wrapper=("xvfb-run", "-a", "-s", "-screen 0 1280x800x24"), env=env)
        else:
            print("xvfb-run not found; rendered smoke run skipped.")
    with zipfile.ZipFile(ROOT / "build/LastCall-linux-greybox.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(destination.iterdir()):
            if file.is_file():
                info = zipfile.ZipInfo(f"LastCall/{file.name}")
                info.external_attr = (0o755 if file.suffix == ".x86_64" else 0o644) << 16
                archive.writestr(info, file.read_bytes(), zipfile.ZIP_DEFLATED)
    print("Built build/LastCall-linux-greybox.zip; the exported binary played Episode 0.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

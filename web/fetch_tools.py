#!/usr/bin/env python3
"""Download verified official 4.7.1 templates locally; optional Linux CI engine."""
import argparse
import hashlib
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.1"
ROOT = Path(__file__).resolve().parent / ".tools"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"


def fetch(name):
    target = ROOT / name
    if not target.exists():
        temporary = target.with_suffix(target.suffix + ".part")
        print(f"Downloading {name}", flush=True)
        urllib.request.urlretrieve(BASE + name, temporary)
        temporary.replace(target)
    return target


def checked(name, sums):
    archive = fetch(name)
    digest = hashlib.sha512()
    with archive.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != sums[name]:
        raise RuntimeError(f"SHA512 mismatch: {archive}; remove and retry")
    return archive


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--linux-engine", action="store_true")
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    sums = {line.split()[1].lstrip("*"): line.split()[0]
            for line in fetch("SHA512-SUMS.txt").read_text().splitlines() if line.strip()}
    archive = checked(f"Godot_v{VERSION}-stable_export_templates.tpz", sums)
    with zipfile.ZipFile(archive) as source:
        for name in ("web_nothreads_debug.zip", "web_nothreads_release.zip"):
            (ROOT / name).write_bytes(source.read("templates/" + name))
    if args.linux_engine:
        name = f"Godot_v{VERSION}-stable_linux.x86_64"
        with zipfile.ZipFile(checked(name + ".zip", sums)) as source:
            engine = ROOT / "godot"
            engine.write_bytes(source.read(name))
            engine.chmod(0o755)
    print("Verified and prepared Godot " + VERSION)


if __name__ == "__main__":
    main()

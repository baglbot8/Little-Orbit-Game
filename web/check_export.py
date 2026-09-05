#!/usr/bin/env python3
"""Catch incomplete exports, wrong threading, and project-Pages path regressions."""
import json
import re
import hashlib
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "exports" / "web"
for name in ("index.html", "index.js", "index.wasm", "index.pck", "manifest.webmanifest",
             "apple-touch-icon.png", "icon-192.png", "icon-512.png"):
    assert (root / name).is_file() and (root / name).stat().st_size > 0, name
html = (root / "index.html").read_text()
assert "$GODOT_" not in html, "Unexpanded Godot shell placeholder"
config = json.loads(re.search(r"const config=(\{[^\n]+\});", html).group(1))
assert config.get("ensureCrossOriginIsolationHeaders") is False, "No header workaround"
# The exporter does not emit a threads config key. Compare the actual engine bytes
# with the verified official single-thread template instead of trusting metadata.
template = root.parent.parent / "web/.tools/web_nothreads_release.zip"
with zipfile.ZipFile(template) as archive:
    assert hashlib.sha256(archive.read("godot.wasm")).digest() == hashlib.sha256((root / "index.wasm").read_bytes()).digest(), "Wrong WASM template"
assert not config.get("serviceWorker"), "No isolation workaround/service worker"
assert not re.search(r'(?:src|href)="/(?!/)', html), "Root URL breaks project Pages"
manifest = json.loads((root / "manifest.webmanifest").read_text())
assert manifest["scope"] == manifest["start_url"] == "./"
assert not list(root.glob("*.worker.js")), "Unexpected worker in single-thread build"
print("Web artifact checks passed:", root)

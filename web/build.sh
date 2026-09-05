#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
version="$("$GODOT_BIN" --version)"
if [[ "$version" != 4.7.1.stable.* ]]; then
  echo "Expected Godot 4.7.1.stable; found $version. Set GODOT_BIN to the matching executable." >&2
  exit 1
fi
if [[ ! -f web/.tools/web_nothreads_release.zip ]]; then
  echo 'Run python3 web/fetch_tools.py first.' >&2
  exit 1
fi
mkdir -p exports/web
touch exports/.gdignore
"$GODOT_BIN" --headless --log-file "$PWD/web/.tools/import.log" --path . --editor --import
python3 -c 'from pathlib import Path; s=Path("web/.tools/import.log").read_text(); assert "SCRIPT ERROR" not in s and "Parse Error" not in s, "Godot import contains script errors"'
"$GODOT_BIN" --headless --log-file "$PWD/web/.tools/export.log" --path . --export-release Web exports/web/index.html
python3 -c 'from pathlib import Path; s=Path("web/.tools/export.log").read_text(); assert "SCRIPT ERROR" not in s and "Parse Error" not in s, "Godot export contains script errors"'
cp web/manifest.webmanifest web/apple-touch-icon.png web/icon-192.png web/icon-512.png exports/web/
touch exports/web/.nojekyll
python3 web/check_export.py

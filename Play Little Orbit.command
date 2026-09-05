#!/bin/zsh
GAME_DIR="${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$GAME_DIR"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$GAME_DIR"
else
  print 'Open project.godot in Godot 4 to play Little Orbit.'
  read -k 1
fi

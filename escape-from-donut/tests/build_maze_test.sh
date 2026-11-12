#!/usr/bin/env bash
# Rebuilds tests/maze_test.luau so it tests the current MazeGenerator, then runs it.
# Needs the Luau CLI (https://github.com/luau-lang/luau/releases) on your PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
awk '/^local MazeGenerator = \(function\(\)$/{print; while ((getline line < "src/server/Services/MazeGenerator.luau") > 0) print line; skip=1; next} skip && /^end\)\(\)$/{skip=0} !skip' tests/maze_test.luau > tests/.maze_test.tmp
mv tests/.maze_test.tmp tests/maze_test.luau
luau tests/maze_test.luau

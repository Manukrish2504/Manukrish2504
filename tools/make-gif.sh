#!/bin/bash
# Rebuilds assets/manu.gif.
#
#   ./tools/make-gif.sh
#
# Needs the Swift toolchain from Command Line Tools (xcode-select --install)
# and ffmpeg (brew install ffmpeg).
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMES="${TMPDIR:-/tmp}/manu-banner-frames"
rm -rf "$FRAMES"

echo "-> rendering frames"
swiftc -O tools/make.swift -o "${TMPDIR:-/tmp}/manu-make"
"${TMPDIR:-/tmp}/manu-make" "$FRAMES"

echo "-> encoding gif"
# Keyed transparent so it sits on either GitHub theme. GIF alpha is 1 bit, and
# every pixel here is fully opaque, so nothing is lost to the threshold.
ffmpeg -y -loglevel error -framerate 24 -i "$FRAMES/%03d.png" \
  -vf "fps=24,scale=860:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=32:reserve_transparent=1[p];[b][p]paletteuse=dither=none:alpha_threshold=128" \
  assets/manu.gif

echo "wrote assets/manu.gif ($(du -h assets/manu.gif | cut -f1))"

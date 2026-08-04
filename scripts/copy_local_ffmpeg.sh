#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_TOOLS="$ROOT_DIR/Vendor/Tools"
FFMPEG_PATH="$(command -v ffmpeg || true)"

if [ -z "$FFMPEG_PATH" ]; then
  echo "ffmpeg bulunamadı. Önce bu Mac'e ffmpeg kurulmalı." >&2
  exit 1
fi

mkdir -p "$VENDOR_TOOLS"
cp "$FFMPEG_PATH" "$VENDOR_TOOLS/ffmpeg"
chmod 755 "$VENDOR_TOOLS/ffmpeg"

echo "$VENDOR_TOOLS/ffmpeg"

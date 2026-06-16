#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build-tools"
WHISPER_DIR="$WORK_DIR/whisper.cpp"
VENDOR_TOOLS="$ROOT_DIR/Vendor/Tools"
CMAKE_VERSION="4.3.3"
CMAKE_DIR="$WORK_DIR/cmake-$CMAKE_VERSION-macos-universal"
CMAKE_BIN="$CMAKE_DIR/CMake.app/Contents/bin/cmake"

mkdir -p "$WORK_DIR" "$VENDOR_TOOLS"

ensure_cmake() {
  if command -v cmake >/dev/null 2>&1; then
    command -v cmake
    return
  fi

  if [ ! -x "$CMAKE_BIN" ]; then
    local archive="$WORK_DIR/cmake-$CMAKE_VERSION-macos-universal.tar.gz"
    curl -L --fail \
      "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-macos-universal.tar.gz" \
      -o "$archive"
    tar -xzf "$archive" -C "$WORK_DIR"
  fi

  echo "$CMAKE_BIN"
}

CMAKE="$(ensure_cmake)"

if [ ! -d "$WHISPER_DIR/.git" ]; then
  git clone --depth 1 --branch v1.8.7 https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
else
  git -C "$WHISPER_DIR" fetch --depth 1 origin tag v1.8.7
  git -C "$WHISPER_DIR" checkout v1.8.7
fi

"$CMAKE" -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DCMAKE_BUILD_TYPE=Release
"$CMAKE" --build "$WHISPER_DIR/build" --config Release -j

cp "$WHISPER_DIR/build/bin/whisper-cli" "$VENDOR_TOOLS/whisper-cli"
chmod 755 "$VENDOR_TOOLS/whisper-cli"

find "$WHISPER_DIR/build" -name 'libwhisper*.dylib' -o -name 'libggml*.dylib' | while read -r dylib; do
  cp -P "$dylib" "$VENDOR_TOOLS/"
done

install_name_tool -add_rpath "@executable_path" "$VENDOR_TOOLS/whisper-cli" 2>/dev/null || true

echo "$VENDOR_TOOLS/whisper-cli"

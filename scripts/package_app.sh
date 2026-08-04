#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ODT Altyazıcı"
PRODUCT_NAME="ODTAltyazici"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

mkdir -p "$ROOT_DIR/.build-cache/clang" "$ROOT_DIR/.build-cache/swiftpm"

cd "$ROOT_DIR"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build-cache/clang" \
SWIFTPM_HOME="$ROOT_DIR/.build-cache/swiftpm" \
swift build --configuration release --disable-sandbox

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$PRODUCT_NAME" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

if [ -d "$BUILD_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" ]; then
  cp -R "$BUILD_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle" "$APP_DIR/Contents/Resources/"
fi

if [ -f "$ROOT_DIR/Vendor/Tools/ffmpeg" ]; then
  mkdir -p "$APP_DIR/Contents/Resources/Tools"
  cp "$ROOT_DIR/Vendor/Tools/ffmpeg" "$APP_DIR/Contents/Resources/Tools/ffmpeg"
  chmod 755 "$APP_DIR/Contents/Resources/Tools/ffmpeg"
fi

if [ -f "$ROOT_DIR/Vendor/Tools/whisper-cli" ]; then
  mkdir -p "$APP_DIR/Contents/Resources/Tools"
  cp "$ROOT_DIR/Vendor/Tools/whisper-cli" "$APP_DIR/Contents/Resources/Tools/whisper-cli"
  chmod 755 "$APP_DIR/Contents/Resources/Tools/whisper-cli"
fi

if compgen -G "$ROOT_DIR/Vendor/Tools/*.dylib" > /dev/null; then
  mkdir -p "$APP_DIR/Contents/Resources/Tools"
  cp -P "$ROOT_DIR"/Vendor/Tools/*.dylib "$APP_DIR/Contents/Resources/Tools/"
fi

if [ -f "$ROOT_DIR/Vendor/Models/ggml-large-v3-turbo.bin" ]; then
  mkdir -p "$APP_DIR/Contents/Resources/Models"
  cp "$ROOT_DIR/Vendor/Models/ggml-large-v3-turbo.bin" "$APP_DIR/Contents/Resources/Models/ggml-large-v3-turbo.bin"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.odt.altyazici</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"

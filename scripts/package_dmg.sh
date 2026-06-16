#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ODT Altyazıcı.app"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"
DMG_PATH="$ROOT_DIR/dist/ODT Altyazıcı.dmg"

if [ ! -d "$APP_PATH" ]; then
  echo "Uygulama bulunamadı: $APP_PATH" >&2
  echo "Önce ./scripts/package_app.sh çalıştırın." >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "ODT Altyazıcı" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

echo "$DMG_PATH"

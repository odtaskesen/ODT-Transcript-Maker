#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_BINARY="$(mktemp "${TMPDIR:-/tmp}/odt-srt-check.XXXXXX")"
trap 'rm -f "$CHECK_BINARY"' EXIT

swiftc \
  -parse-as-library \
  -swift-version 6 \
  -enable-bare-slash-regex \
  "$ROOT_DIR/Sources/ODTAltyazici/SubtitleDocument.swift" \
  "$ROOT_DIR/Tests/SRTDocumentChecks/main.swift" \
  -o "$CHECK_BINARY"

"$CHECK_BINARY"

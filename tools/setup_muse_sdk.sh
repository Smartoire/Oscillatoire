#!/bin/sh
# Builds Vendor/Muse.xcframework (iOS + macOS) from the Interaxon Muse SDK archives.
# The SDK licence forbids redistributing it, so it is git-ignored. Run once per checkout:
#
#   tools/setup_muse_sdk.sh "/path/to/Muse SDK 8.0.9"
#
set -eu
SDK_DIR=${1:?usage: $0 <folder containing libmuse_ios_*.tar.gz and libmuse_macos_*.tar.gz>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d /tmp/musesdk.XXXXXX)   # Interaxon's script rejects paths containing spaces
trap 'rm -rf "$WORK"' EXIT

cp "$SDK_DIR"/libmuse_ios_*.tar.gz "$SDK_DIR"/libmuse_macos_*.tar.gz "$WORK"/
tar -xzf "$WORK"/libmuse_ios_*.tar.gz -C "$WORK" --include '*/scripts/make_xcframework.sh'
# -a: include every platform archive present (iOS + macOS; Catalyst is not copied).
sh "$WORK"/libmuse_ios_*/scripts/make_xcframework.sh -a -p "$WORK"

rm -rf "$ROOT/Vendor/Muse.xcframework"
mkdir -p "$ROOT/Vendor"
mv "$WORK/Muse.xcframework" "$ROOT/Vendor/"
echo "Vendor/Muse.xcframework ready"

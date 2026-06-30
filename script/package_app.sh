#!/usr/bin/env bash
set -euo pipefail

BUILD_CONFIGURATION="${1:-debug}"

case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

APP_NAME="PKwindowsManagement"
PRODUCT_NAME="PKwindowsManagement"
BUNDLE_ID="com.mondary.PKwindowsManagement"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/$APP_NAME"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICON_SOURCE="$ROOT_DIR/icon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
APP_ICON="$RESOURCES_DIR/AppIcon.icns"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIGURATION/$PRODUCT_NAME" "$EXECUTABLE"
chmod +x "$EXECUTABLE"

# SwiftPM keeps localized resources in a generated bundle. Copy the language
# folders into the app resources as well so SwiftUI and AppKit both resolve them.
RESOURCE_BUNDLE="$ROOT_DIR/.build/$BUILD_CONFIGURATION/PKwindowsManagement_PKwindowsManagement.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
  find "$RESOURCE_BUNDLE" -maxdepth 1 -type d -name '*.lproj' -exec cp -R {} "$RESOURCES_DIR/" \;
fi

if [[ -f "$ICON_SOURCE" ]]; then
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  SQUARE_ICON="$DIST_DIR/AppIcon-1024.png"
  sips -z 1024 1024 "$ICON_SOURCE" --out "$SQUARE_ICON" >/dev/null

  for size in 16 32 128 256 512; do
    double_size=$((size * 2))
    sips -z "$size" "$size" "$SQUARE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    sips -z "$double_size" "$double_size" "$SQUARE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$ICONSET_DIR" -o "$APP_ICON"
  rm -rf "$ICONSET_DIR" "$SQUARE_ICON"
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>PKwindowsManagement needs Finder automation to empty the Trash from the Launchpad button.</string>
</dict>
</plist>
EOF

# Signature stable : préférez une identité développeur (TCC/accessibilité
# persiste entre les rebuilds), sinon repli ad-hoc avec identifiant stable.
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development: cleeement@gmail.com (8CZKU67BTY)}"
BUNDLE_ID="com.mondary.PKwindowsManagement"
if ! codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR" 2>/dev/null; then
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR" 2>/dev/null || true
fi

echo "$APP_DIR"

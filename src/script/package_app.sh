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
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/build"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/$APP_NAME"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICON_SOURCE="$ROOT_DIR/icon.png"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
APP_ICON="$RESOURCES_DIR/AppIcon.icns"
# CHANGELOG.md is the single source of truth for the version (no VERSION file).
VERSION="$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' "$ROOT_DIR/CHANGELOG.md" | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "Unable to read the version from CHANGELOG.md" >&2
  exit 1
fi

# Dev builds (PK_DEV_BUILD=1, CI pushes on main): CFBundleVersion is the epoch
# — always growing, always above any stable CalVer, so any installed app gets
# offered the dev build. Stable keeps the CalVer everywhere.
if [[ "${PK_DEV_BUILD:-0}" == "1" ]]; then
  EPOCH="$(date +%s)"
  BUNDLE_VERSION="$EPOCH"
  SHORT_VERSION="$VERSION-dev.$(echo "$EPOCH" | tail -c 5)"
else
  BUNDLE_VERSION="$VERSION"
  SHORT_VERSION="$VERSION"
fi

cd "$ROOT_DIR"
# Package.swift declares macOS 13 as the minimum supported system. Without an
# explicit deployment target, Swift uses the host macOS version instead.
# SwiftPM's standard scratch (.build/) is shared between debug and release.
MACOSX_DEPLOYMENT_TARGET=13.0 swift build -c "$BUILD_CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIGURATION/$PRODUCT_NAME" "$EXECUTABLE"
chmod +x "$EXECUTABLE"

# Sparkle (SPM binary target) links as @rpath/Sparkle.framework: embed the
# framework in the bundle and point the executable's rpath at it, or dyld
# fails with "Library not loaded" at launch.
SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts" -type d -name "Sparkle.framework" -path "*macos*" | head -1)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  mkdir -p "$APP_DIR/Contents/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"
  if ! otool -l "$EXECUTABLE" | grep -A2 LC_RPATH | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE"
  fi
else
  echo "Sparkle.framework not found in .build/artifacts — the app will not launch." >&2
  exit 1
fi

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
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUNDLE_VERSION</string>
  <key>SUFeedURL</key>
  <string>https://raw.githubusercontent.com/mondary/PKwindowsManagement/main/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>t9Zzlc7LZD17hLCepinDvSRHk51hAWGbkFc2yVjbAYs=</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>PKwindowsManagement needs Finder automation to empty the Trash from the Launchpad button.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>PKwindowsManagement affiche vos événements journée entière dans Big Year.</string>
</dict>
</plist>
EOF

# Signature stable : la CI importe le même certificat Apple Development que le
# build local. TCC (Accessibilité) identifie l'app via cette identité ; le repli
# ad-hoc n'est réservé qu'aux environnements sans certificat configuré.
# Le framework embarqué est signé d'abord, puis l'app.
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development: cleeement@gmail.com (8CZKU67BTY)}"
BUNDLE_ID="com.mondary.PKwindowsManagement"
if [[ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]]; then
  if ! codesign --force --sign "$SIGN_IDENTITY" --identifier "org.sparkle-project.Sparkle" "$APP_DIR/Contents/Frameworks/Sparkle.framework" 2>/dev/null; then
    codesign --force --sign - --identifier "org.sparkle-project.Sparkle" "$APP_DIR/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
  fi
fi
if ! codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR" 2>/dev/null; then
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR" 2>/dev/null || true
fi

echo "$APP_DIR"

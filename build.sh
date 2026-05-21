#!/bin/bash
set -e

echo "========================================="
echo "Building BarCycle macOS Application Agent"
echo "========================================="

APP_NAME="BarCycle"
APP_BUNDLE="$APP_NAME.app"
VERSION="1.0"
DIST_DIR="dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_NAME="$APP_NAME-$VERSION-$(uname -m).dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
ICON_SOURCE="Resources/icon.png"
ICONSET_DIR="$DIST_DIR/$APP_NAME.iconset"
APP_ICON_NAME="$APP_NAME.icns"
APP_ICON_PATH="$APP_BUNDLE/Contents/Resources/$APP_ICON_NAME"

# 1. Clean previous build and stop running instances
echo "🧹 Cleaning previous build, stopping running instances, and resetting authorizations..."
killall "$APP_NAME" 2>/dev/null || true
tccutil reset Accessibility com.antigravity.BarCycle 2>/dev/null || true
rm -rf "$APP_BUNDLE" BarCycle "$DIST_DIR"

# 1b. Prepare app icon resources from the provided PNG
echo "🎨 Preparing app icon from $ICON_SOURCE..."
mkdir -p "$DIST_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$DIST_DIR/$APP_ICON_NAME"

# 2. Compile all Swift source files into a single binary
echo "🔨 Compiling Swift sources..."
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macosx14.0"
else
  TARGET="x86_64-apple-macosx14.0"
fi
echo "🎯 Target architecture: $ARCH, Target deployment version: macOS 14"

swiftc \
  Sources/BarCycle/*.swift \
  -o BarCycle \
  -O \
  -target "$TARGET" \
  -sdk "$(xcrun --show-sdk-path)"

# 3. Create the standard macOS app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Move executable into app bundle
mv BarCycle "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 5. Copy Info.plist into app bundle
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 5b. Copy the generated app icon into the app bundle resources
cp "$DIST_DIR/$APP_ICON_NAME" "$APP_ICON_PATH"

# 6. Apply ad-hoc code signing (required for Apple Silicon and local execution)
echo "🔐 Signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 7. Package the signed app into a distributable DMG
echo "📦 Creating DMG package..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
cp "$DIST_DIR/$APP_ICON_NAME" "$STAGING_DIR/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "$STAGING_DIR" 2>/dev/null || true
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$DIST_DIR"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"
rm -rf "$STAGING_DIR"

echo "========================================="
echo "🎉 Build Completed Successfully!"
echo "📍 Application path: ./BarCycle.app"
echo "📦 DMG path: ./$DMG_PATH"
echo "========================================="
